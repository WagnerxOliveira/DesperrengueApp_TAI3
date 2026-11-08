import '../services/document_ocr_and_liveness_service.dart';

/// O que será excluído: só o perfil de cliente, só o de profissional ou a conta inteira.
enum DeletionScope {
  client('client'),
  provider('provider'),
  all('all');

  const DeletionScope(this.wire);
  final String wire;

  static DeletionScope parse(String? v) =>
      DeletionScope.values.firstWhere((s) => s.wire == v, orElse: () => DeletionScope.all);
}

/// Resposta da Edge Function `excluir-conta`.
class DeletionResult {
  const DeletionResult({required this.scope, required this.accountRemoved});

  final DeletionScope scope;

  /// true = a conta (login) foi apagada; false = só um perfil saiu e a conta segue com o outro.
  final bool accountRemoved;

  factory DeletionResult.fromMap(
    Map<String, dynamic> m, {
    DeletionScope fallback = DeletionScope.all,
  }) {
    final scope =
        m['scope'] is String ? DeletionScope.parse(m['scope'] as String) : fallback;
    return DeletionResult(
      scope: scope,
      accountRemoved: m['account_removed'] is bool
          ? m['account_removed'] as bool
          : scope == DeletionScope.all,
    );
  }
}

/// Estado financeiro/operacional que decide se a conta pode ser excluída
/// (`account_deletion_status`). O servidor repete a mesma checagem ao excluir.
class DeletionStatus {
  const DeletionStatus({
    required this.available,
    required this.held,
    required this.activeJobs,
    required this.blockers,
  });

  /// Saldo disponível para saque (R$).
  final double available;

  /// Valor em custódia (escrow) (R$).
  final double held;
  final int activeJobs;

  /// Códigos: `balance`, `escrow`, `active_jobs`.
  final List<String> blockers;

  bool get canDelete => blockers.isEmpty;

  /// Saldo > 0: o usuário precisa sacar via Pix para a própria conta antes.
  bool get hasBalance => blockers.contains('balance');

  /// Valores em custódia ou serviços em andamento: precisa aguardar a conclusão.
  bool get hasOngoing =>
      blockers.contains('escrow') || blockers.contains('active_jobs');

  factory DeletionStatus.fromMap(Map<String, dynamic> m) => DeletionStatus(
        available: (m['available'] as num?)?.toDouble() ?? 0,
        held: (m['held'] as num?)?.toDouble() ?? 0,
        activeJobs: (m['active_jobs'] as num?)?.toInt() ?? 0,
        blockers:
            ((m['blockers'] as List?) ?? const []).whereType<String>().toList(),
      );
}

/// Tipos de chave Pix aceitos (espelham o CHECK do banco).
enum PixKeyType {
  cpf('cpf', 'CPF'),
  cnpj('cnpj', 'CNPJ'),
  email('email', 'E-mail'),
  phone('phone', 'Celular'),
  random('random', 'Aleatória');

  const PixKeyType(this.wire, this.label);
  final String wire;
  final String label;
}

/// Validação local da chave Pix e Trava de Mesma Titularidade (`Same-Holder Lock` — `RN-AF-12`).
class PixKeyValidator {
  PixKeyValidator._();

  static String digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static bool isValid(PixKeyType type, String raw) {
    final v = raw.trim();
    switch (type) {
      case PixKeyType.cpf:
        return isValidCpf(v);
      case PixKeyType.cnpj:
        return isValidCnpj(v);
      case PixKeyType.email:
        return RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(v);
      case PixKeyType.phone:
        final d = digits(v);
        return d.length == 11 && d[2] == '9'; // DDD + 9XXXX-XXXX
      case PixKeyType.random:
        return RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(v);
    }
  }

  /// Trava de Mesma Titularidade (`Same-Holder Lock` — `RN-AF-12`):
  /// Garante que a chave PIX CPF informada pertença ao mesmo titular cujo documento oficial
  /// foi validado no KYC (`cpf_hash`).
  static bool matchesVerifiedHolderCpf(
    PixKeyType type,
    String rawKey, {
    required String? verifiedCpfHash,
  }) {
    if (verifiedCpfHash == null || verifiedCpfHash.trim().isEmpty) {
      return true;
    }
    if (type != PixKeyType.cpf) {
      return true;
    }
    final keyHash = DocumentOcrAndLivenessService.computeCpfHash(rawKey);
    return keyHash == verifiedCpfHash.trim();
  }

  static bool isValidCpf(String raw) {
    final d = digits(raw);
    if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
    int dv(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += int.parse(d[i]) * (len + 1 - i);
      }
      final r = (sum * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return dv(9) == int.parse(d[9]) && dv(10) == int.parse(d[10]);
  }

  static bool isValidCnpj(String raw) {
    final d = digits(raw);
    if (d.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(d)) return false;
    int dv(int len) {
      const w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      const w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      final w = len == 12 ? w1 : w2;
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += int.parse(d[i]) * w[i];
      }
      final r = sum % 11;
      return r < 2 ? 0 : 11 - r;
    }

    return dv(12) == int.parse(d[12]) && dv(13) == int.parse(d[13]);
  }
}
