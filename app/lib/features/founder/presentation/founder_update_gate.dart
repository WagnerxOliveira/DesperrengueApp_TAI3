import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/env.dart';
import '../../../core/services/update_service.dart';
import 'founder_animations_and_shaders.dart';

/// Informações de nova versão do binário exclusivo `desperrengue-founder-ceo.apk`.
@immutable
class FounderUpdateInfo {
  const FounderUpdateInfo({
    required this.version,
    required this.build,
    required this.currentBuild,
    required this.apkUrl,
    this.notes,
  });

  final String version;
  final int build;
  final int currentBuild;
  final String apkUrl;
  final String? notes;
}

/// Serviço OTA dedicado exclusivamente ao `Desperrengue CEO` (`desperrengue-founder-ceo.apk`).
///
/// Jamais baixa `desperrengue.apk` (público): seleciona estritamente o asset
/// `desperrengue-founder-ceo.apk` no release rolante `beta-latest` do GitHub,
/// validando domínio HTTPS confiável via [UpdateService.isTrustedDownloadUrl].
class FounderUpdateService {
  FounderUpdateService({
    http.Client? client,
    Future<int> Function()? buildNumber,
    bool? enabled,
    String? repo,
  })  : _client = client ?? http.Client(),
        _buildNumber = buildNumber ?? _installedBuild,
        _enabled = enabled ?? (!kIsWeb && Env.betaUpdates),
        _repo = repo ?? Env.updateRepo;

  final http.Client _client;
  final Future<int> Function() _buildNumber;
  final bool _enabled;
  final String _repo;

  static const String founderApkAssetName = 'desperrengue-founder-ceo.apk';
  static const String _etagPrefKey = 'founder_ceo_update_etag_v1';
  static const String _cachedBodyPrefKey = 'founder_ceo_update_body_v1';

  static String get directFounderApkFallbackUrl =>
      'https://github.com/${Env.updateRepo}/releases/download/${UpdateService.releaseTag}/$founderApkAssetName';

  static Future<int> _installedBuild() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Verifica se há um APK `desperrengue-founder-ceo.apk` mais novo publicado em `beta-latest`.
  /// Se [forceManualCheck] for `true`, executa a consulta mesmo em builds locais sem `BETA_UPDATES`.
  Future<FounderUpdateInfo?> check({bool forceManualCheck = false}) async {
    if (kIsWeb) return null;
    if (!forceManualCheck && (!_enabled || _repo.isEmpty)) return null;
    if (_repo.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
      };
      final etag = prefs.getString(_etagPrefKey);
      if (!forceManualCheck && etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }

      final uri = Uri.https(
        'api.github.com',
        '/repos/$_repo/releases/tags/${UpdateService.releaseTag}',
      );
      final resp = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 7));

      String? rawBody;
      if (resp.statusCode == 200) {
        rawBody = resp.body;
        final newEtag = resp.headers['etag'];
        if (newEtag != null && newEtag.isNotEmpty) {
          await prefs.setString(_etagPrefKey, newEtag);
          await prefs.setString(_cachedBodyPrefKey, rawBody);
        }
      } else if (resp.statusCode == 304) {
        rawBody = prefs.getString(_cachedBodyPrefKey);
      }

      if (rawBody == null || rawBody.isEmpty) return null;
      final current = await _buildNumber();
      return parseFounderRelease(rawBody, currentBuild: current, repo: _repo);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static FounderUpdateInfo? parseFounderRelease(
    String rawJson, {
    required int currentBuild,
    String repo = '',
  }) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return null;
    final body = (decoded['body'] as String?) ?? '';

    int? remoteBuild;
    String remoteVersion = '';

    final lineBuildMatch =
        RegExp(r'^build:\s*(\d+)', multiLine: true).firstMatch(body);
    if (lineBuildMatch != null) {
      remoteBuild = int.tryParse(lineBuildMatch.group(1)!);
      remoteVersion = RegExp(r'^version:\s*([\w.\-+]+)', multiLine: true)
              .firstMatch(body)
              ?.group(1) ??
          '';
    } else {
      final commentMatch = RegExp(
        r'<!--\s*build:(\d+)\s+version:([^\s>]+)\s*-->',
      ).firstMatch(body);
      if (commentMatch != null) {
        remoteBuild = int.tryParse(commentMatch.group(1)!);
        remoteVersion = commentMatch.group(2)!;
      }
    }

    if (remoteBuild == null || remoteBuild <= currentBuild) return null;

    final assets = (decoded['assets'] as List<dynamic>?) ?? const <dynamic>[];
    String? founderApkUrl;
    for (final item in assets) {
      if (item is Map<String, dynamic>) {
        final assetName = (item['name'] as String?)?.trim() ?? '';
        final downloadUrl =
            (item['browser_download_url'] as String?)?.trim() ?? '';
        if (assetName == founderApkAssetName && downloadUrl.isNotEmpty) {
          founderApkUrl = downloadUrl;
          break;
        }
      }
    }

    if (founderApkUrl == null ||
        !UpdateService.isTrustedDownloadUrl(founderApkUrl)) {
      return null;
    }
    if (repo.isNotEmpty &&
        !founderApkUrl.toLowerCase().contains(repo.toLowerCase())) {
      return null;
    }

    final cleanNotes = body
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .trim();

    return FounderUpdateInfo(
      version: remoteVersion.isEmpty ? '$remoteBuild' : remoteVersion,
      build: remoteBuild,
      currentBuild: currentBuild,
      apkUrl: founderApkUrl,
      notes: cleanNotes.isEmpty ? null : cleanNotes,
    );
  }

  static Future<bool> launchTrustedFounderApkDownload(
    String apkUrl, {
    String? repo,
  }) async {
    final effectiveRepo = repo ?? Env.updateRepo;
    if (!UpdateService.isTrustedDownloadUrl(apkUrl)) {
      return false;
    }
    if (effectiveRepo.isNotEmpty &&
        !apkUrl.toLowerCase().contains(effectiveRepo.toLowerCase())) {
      return false;
    }
    return launchUrl(
      Uri.parse(apkUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Wrapper silencioso de atualização automática do `Desperrengue CEO`.
/// Não bloqueia o boot e exibe um banner discreto *Obsidian & Imperial Gold* quando
/// uma nova build de `desperrengue-founder-ceo.apk` é publicada no GitHub Releases.
class FounderUpdateGate extends StatefulWidget {
  const FounderUpdateGate({
    super.key,
    required this.child,
    this.service,
  });

  final Widget child;
  final FounderUpdateService? service;

  @override
  State<FounderUpdateGate> createState() => _FounderUpdateGateState();
}

class _FounderUpdateGateState extends State<FounderUpdateGate> {
  FounderUpdateInfo? _pendingUpdate;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkInBackground());
  }

  Future<void> _checkInBackground() async {
    final svc = widget.service ?? FounderUpdateService();
    final info = await svc.check();
    if (!mounted || info == null) return;
    setState(() => _pendingUpdate = info);
  }

  @override
  Widget build(BuildContext context) {
    final update = _pendingUpdate;
    if (update == null || _dismissed) {
      return widget.child;
    }

    return Column(
      children: <Widget>[
        Material(
          color: const Color(0xFF1A1508),
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.55),
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.system_update_rounded,
                    size: 18,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nova edição Desperrengue CEO v${update.version} disponível',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FounderSovereignTokens.primaryInk,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: FounderSovereignTokens.imperialGold,
                      foregroundColor: const Color(0xFF111827),
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    onPressed: () {
                      FounderUpdateService.launchTrustedFounderApkDownload(
                        update.apkUrl,
                      );
                    },
                    child: const Text(
                      'Baixar APK CEO',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Ocultar aviso nesta sessão',
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
