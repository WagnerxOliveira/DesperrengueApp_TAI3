import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/env.dart';

/// Uma versão BETA mais nova que a instalada do aplicativo público `Desperrengue`.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.version,
    required this.apkUrl,
    this.sizeBytes,
    this.sha256,
    this.notes = '',
  });

  /// `versionCode` da versão nova (sempre crescente: gerado pela CI).
  final int build;
  final String version;
  final String apkUrl;
  final int? sizeBytes;

  /// Hash criptográfico `SHA-256` de 64 caracteres hexadecimais do `desperrengue.apk`.
  final String? sha256;

  /// "Novidades" (mensagem do último commit), se houver.
  final String notes;

  String get sizeLabel => sizeBytes == null
      ? ''
      : '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB';
}

/// Verifica, no GitHub Releases (`beta-latest`), se existe um `desperrengue.apk` mais novo.
///
/// A CI (`.github/workflows/beta-release.yml`) mantém UM release "rolante"
/// (`beta-latest`) cujo texto começa com `build: <versionCode>` e publica o
/// digest `SHA-256` oficial. Usa **ETag** em memória + `SharedPreferences`:
/// respostas `304 Not Modified` não contam no limite da API do GitHub.
///
/// Só funciona em builds feitos com `--dart-define=BETA_UPDATES=true` (a CI faz isso);
/// builds da Play Store ficam 100% de fora (a loja atualiza sozinha).
class UpdateService {
  UpdateService({
    http.Client? client,
    Future<int> Function()? installedBuild,
    String? repo,
    bool? enabled,
  })  : _client = client ?? http.Client(),
        _installedBuild = installedBuild ?? _platformBuild,
        _repo = repo ?? Env.updateRepo,
        enabled = enabled ?? Env.betaUpdates;

  final http.Client _client;
  final Future<int> Function() _installedBuild;
  final String _repo;
  final bool enabled;

  static const String releaseTag = 'beta-latest';
  static const String publicApkAssetName = 'desperrengue.apk';
  static const String _etagPrefKey = 'public_beta_update_etag_v2';
  static const String _cachedBodyPrefKey = 'public_beta_update_body_v2';

  String? _etag;
  String? _cachedRawBody;
  UpdateInfo? _cached;

  static Future<int> _platformBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// Devolve a atualização disponível ou `null` (sem versão nova, sem rede ou desativado).
  /// Nunca lança: falha de rede não pode incomodar o usuário.
  Future<UpdateInfo?> check({bool forceManualCheck = false}) async {
    if (kIsWeb) return null;
    if (!forceManualCheck && !enabled) return null;
    if (_repo.isEmpty) return null;

    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}

      final installed = await _installedBuild();
      final effectiveEtag =
          forceManualCheck ? null : (_etag ?? prefs?.getString(_etagPrefKey));

      final res = await _client
          .get(
            Uri.https('api.github.com', '/repos/$_repo/releases/tags/$releaseTag'),
            headers: <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              if (effectiveEtag != null && effectiveEtag.isNotEmpty)
                'If-None-Match': effectiveEtag,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final nextEtag = res.headers['etag'];
        _etag = nextEtag;
        _cachedRawBody = res.body;
        _cached = parse(res.body);
        if (nextEtag != null && nextEtag.isNotEmpty) {
          await prefs?.setString(_etagPrefKey, nextEtag);
          await prefs?.setString(_cachedBodyPrefKey, res.body);
        }
      } else if (res.statusCode == 304) {
        if (_cached == null) {
          final persistedBody =
              _cachedRawBody ?? prefs?.getString(_cachedBodyPrefKey);
          if (persistedBody != null && persistedBody.isNotEmpty) {
            _cached = parse(persistedBody);
          }
        }
      } else {
        return null;
      }

      final info = _cached;
      return (info != null && info.build > installed) ? info : null;
    } catch (_) {
      return null;
    }
  }

  /// Só aceita APK servido por HTTPS pelo GitHub (`github.com` ou `*.githubusercontent.com`).
  static bool isTrustedDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == 'github.com' || host.endsWith('.githubusercontent.com');
  }

  /// Seleciona deterministicamente o APK público de atualização OTA (`desperrengue.apk`),
  /// isolando matematicamente artefatos com `'founder'` no nome ou na URL.
  static Map<dynamic, dynamic> _selectPublicApkAsset(
    Iterable<Map<dynamic, dynamic>> assets,
  ) {
    for (final a in assets) {
      final name = '${a['name'] ?? ''}'.trim();
      if (name.toLowerCase() == publicApkAssetName) {
        return a;
      }
    }
    for (final a in assets) {
      final lowerName = '${a['name'] ?? ''}'.trim().toLowerCase();
      if (lowerName.endsWith('.apk') && !lowerName.contains('founder')) {
        return a;
      }
    }
    return const <dynamic, dynamic>{};
  }

  /// Lê o JSON do release `beta-latest` e extrai `build`, `version`, `apkUrl`,
  /// `sizeBytes`, `sha256` (de `desperrengue.apk`) e `notes`.
  @visibleForTesting
  static UpdateInfo? parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final text = (json['body'] as String?) ?? '';
      final build = int.tryParse(
        RegExp(r'^build:\s*(\d+)', multiLine: true)
                .firstMatch(text)
                ?.group(1) ??
            '',
      );
      if (build == null) return null;

      final version = RegExp(r'^version:\s*([\w.\-+]+)', multiLine: true)
              .firstMatch(text)
              ?.group(1) ??
          '';
      final assets =
          (json['assets'] as List?)?.whereType<Map>() ?? const <Map>[];
      final apk = _selectPublicApkAsset(assets);
      final url = apk['browser_download_url'] as String?;
      if (url == null ||
          !isTrustedDownloadUrl(url) ||
          url.toLowerCase().contains('founder')) {
        return null;
      }

      String? assetDigestSha256;
      final digestRaw = '${apk['digest'] ?? ''}'.trim();
      if (digestRaw.toLowerCase().startsWith('sha256:') &&
          digestRaw.length == 71) {
        final hexCandidate = digestRaw.substring(7).toLowerCase();
        if (RegExp(r'^[0-9a-f]{64}$').hasMatch(hexCandidate)) {
          assetDigestSha256 = hexCandidate;
        }
      }

      final notesShaMatch = RegExp(
        r'SHA-256\s*\(`?desperrengue\.apk`?\)\s*:\s*`?([0-9a-fA-F]{64})`?',
        caseSensitive: false,
      ).firstMatch(text);
      final sha256Hex =
          notesShaMatch?.group(1)?.toLowerCase() ?? assetDigestSha256;

      final notes = RegExp(r'## Novidades\s*\n([\s\S]*?)(?:\n---|$)')
              .firstMatch(text)
              ?.group(1)
              ?.trim() ??
          '';

      return UpdateInfo(
        build: build,
        version: version,
        apkUrl: url,
        sizeBytes: (apk['size'] as num?)?.toInt(),
        sha256: sha256Hex,
        notes: notes,
      );
    } catch (_) {
      return null;
    }
  }
}
