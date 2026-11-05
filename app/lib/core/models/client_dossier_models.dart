/// Dossiê do serviço para o CLIENTE (RPC `client_job_dossier`). Dart puro:
/// `fromMap` tolerante a nulos/tipos soltos, porque o jsonb do banco pode evoluir.
library;

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
double _money(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);
List<String> _strings(dynamic v) => v is List ? [for (final e in v) if (e != null) e.toString()] : const [];
Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

/// Ordem das fotos obrigatórias na galeria.
const List<String> kEvidenceSlots = ['overview', 'detail', 'angle', 'clean'];

const Map<String, String> kEvidenceLabels = {
  'overview': 'Visão geral',
  'detail': 'Detalhe',
  'angle': 'Outro ângulo',
  'clean': 'Local limpo',
  'video': 'Vídeo',
};

class DossierEvidence {
  const DossierEvidence({required this.slot, required this.path});

  final String slot;
  final String path;

  String get label => kEvidenceLabels[slot] ?? slot;
}

class DossierProvider {
  const DossierProvider({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.title,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final String? avatarUrl;

  /// Especialidade/título do profissional.
  final String? title;
  final double? ratingAvg;
  final int ratingCount;

  static DossierProvider? fromMap(Map<String, dynamic>? m) {
    final id = m?['id'];
    if (m == null || id is! String || id.isEmpty) return null;
    return DossierProvider(
      id: id,
      name: (m['name'] as String?) ?? '',
      avatarUrl: m['avatar_url'] as String?,
      title: m['title'] as String?,
      ratingAvg: m['rating_avg'] is num ? (m['rating_avg'] as num).toDouble() : null,
      ratingCount: (m['rating_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Avaliação que o próprio cliente deu.
class DossierReview {
  const DossierReview({required this.rating, this.tags = const [], this.comment, this.createdAt});

  final int rating;
  final List<String> tags;
  final String? comment;
  final DateTime? createdAt;

  static DossierReview? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final c = (m['comment'] as String?)?.trim();
    return DossierReview(
      rating: (m['rating'] as num?)?.toInt() ?? 0,
      tags: _strings(m['tags']),
      comment: (c == null || c.isEmpty) ? null : c,
      createdAt: _date(m['created_at']),
    );
  }
}

class ClientDossier {
  const ClientDossier({
    required this.jobId,
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.amount,
    required this.paymentStatus,
    this.scheduledFor,
    this.startedAt,
    this.finishedAt,
    this.addressSummary,
    this.photoPaths = const [],
    this.provider,
    this.evidence = const [],
    this.report,
    this.myReview,
  });

  final String jobId;
  final String code;
  final String title;
  final String description;
  final String category;

  /// Valor cru da coluna `jobs.status` (ex.: `completed`, `canceled`).
  final String status;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? addressSummary;

  /// Fotos que o cliente anexou ao pedir o serviço.
  final List<String> photoPaths;

  /// Valor pago bruto (R$).
  final double amount;
  final String paymentStatus;
  final DossierProvider? provider;
  final List<DossierEvidence> evidence;
  final String? report;
  final DossierReview? myReview;

  bool get isCanceled => status == 'canceled';
  bool get isCompleted => status == 'completed';

  /// Fotos obrigatórias (overview/detail/angle/clean) na ordem fixa da galeria.
  List<DossierEvidence> get requiredPhotos => [
        for (final slot in kEvidenceSlots) ...evidence.where((e) => e.slot == slot),
      ];

  /// Caminho do vídeo do serviço, quando o profissional gravou um.
  String? get videoPath {
    for (final e in evidence) {
      if (e.slot == 'video') return e.path;
    }
    return null;
  }

  factory ClientDossier.fromMap(Map<String, dynamic> m) {
    final id = (m['job_id'] as String?) ?? '';
    final clean = id.replaceAll('-', '');
    final fallbackCode = clean.length >= 5 ? '#DESP-${clean.substring(0, 5).toUpperCase()}' : '#DESP';
    final report = (m['report'] as String?)?.trim();
    final ev = m['evidence'];
    return ClientDossier(
      jobId: id,
      code: (m['code'] as String?) ?? fallbackCode,
      title: (m['title'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      status: (m['status'] as String?) ?? '',
      scheduledFor: _date(m['scheduled_for']),
      startedAt: _date(m['started_at']),
      finishedAt: _date(m['finished_at']),
      addressSummary: m['address_summary'] as String?,
      photoPaths: _strings(m['photo_paths']),
      amount: _money(m['amount']),
      paymentStatus: (m['payment_status'] as String?) ?? '',
      provider: DossierProvider.fromMap(_map(m['provider'])),
      evidence: [
        if (ev is List)
          for (final e in ev)
            if (e is Map && e['slot'] is String && e['path'] is String)
              DossierEvidence(slot: e['slot'] as String, path: e['path'] as String),
      ],
      report: (report == null || report.isEmpty) ? null : report,
      myReview: DossierReview.fromMap(_map(m['my_review'])),
    );
  }
}
