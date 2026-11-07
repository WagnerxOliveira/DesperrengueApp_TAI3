import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace_models.dart';
import '../models/smart_triage_models.dart';
import '../services/smart_triage_service.dart';
import '../storage/local_prefs.dart';

const String _kTriageStorageKey = 'triagens_inteligentes_por_pedido_v1';

/// Retorna o [ProviderContainer] se houver um [ProviderScope] ancestral na árvore,
/// ou `null` em testes isolados que montam `MaterialApp` direto sem `ProviderScope`.
ProviderContainer? maybeProviderContainer(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false);
  } catch (_) {
    return null;
  }
}

/// Cache reativo compartilhado (sincronizado com Riverpod e `SharedPreferences`).
class JobTriageStore extends ValueNotifier<Map<String, SmartTriageResult>> {
  JobTriageStore._() : super(const {});

  static final JobTriageStore instance = JobTriageStore._();

  bool _hydrated = false;

  Future<void> ensureHydrated() async {
    if (_hydrated) return;
    _hydrated = true;
    final raw = await LocalPrefs.read(_kTriageStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <String, SmartTriageResult>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          loaded[entry.key] = SmartTriageResult.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      if (loaded.isNotEmpty) {
        value = {...loaded, ...value};
      }
    } catch (_) {}
  }

  Future<void> _persist(Map<String, SmartTriageResult> current) async {
    try {
      final map = {
        for (final entry in current.entries) entry.key: entry.value.toMap(),
      };
      await LocalPrefs.write(_kTriageStorageKey, jsonEncode(map));
    } catch (_) {}
  }

  void saveForJob(String jobId, SmartTriageResult result) {
    final next = {...value, jobId: result};
    value = next;
    unawaited(_persist(next));
  }

  SmartTriageResult resolveForJob(Job job) {
    final existing = value[job.id];
    if (existing != null) return existing;
    final text = [job.title.trim(), job.description.trim()]
        .where((s) => s.isNotEmpty)
        .join('. ');
    var generated = SmartTriageService.instance.analyze(
      rawText: text.isEmpty ? job.category : text,
      mediaAttachments: job.photoPaths,
      currentCategory: job.category,
      now: job.createdAt,
    );
    if (job.isEmergency &&
        generated.urgencyLevel != UrgencyLevel.criticalEmergency) {
      generated = generated.copyWith(
        urgencyLevel: UrgencyLevel.criticalEmergency,
      );
    }
    return generated;
  }

  SmartTriageResult toggleMaterialForJob(Job job, String materialId) {
    final base = resolveForJob(job);
    final updated = base.toggleMaterial(materialId);
    saveForJob(job.id, updated);
    return updated;
  }

  SmartTriageResult toggleContainmentStepForJob(Job job, int stepNumber) {
    final base = resolveForJob(job);
    final updated = base.toggleContainmentStep(stepNumber);
    saveForJob(job.id, updated);
    return updated;
  }

  @visibleForTesting
  void clearForTest() {
    value = const {};
  }
}

/// Controlador Riverpod do rascunho de Triagem Inteligente durante a abertura do chamado.
class SmartTriageController extends Notifier<SmartTriageResult?> {
  @override
  SmartTriageResult? build() => null;

  /// Executa a triagem multimodal preservando escolhas prévias compatíveis de peças/passos.
  SmartTriageResult analyzeDraft({
    required String rawText,
    List<String> mediaAttachments = const [],
    String? currentCategory,
  }) {
    final previous = state;
    var fresh = SmartTriageService.instance.analyze(
      rawText: rawText,
      mediaAttachments: mediaAttachments,
      currentCategory: currentCategory,
    );

    if (previous != null) {
      final ownedIds = {
        for (final m in previous.probableMaterials)
          if (m.clientAlreadyHasIt) m.id,
      };
      final completedSteps = {
        if (previous.containmentGuide != null)
          for (final s in previous.containmentGuide!.steps)
            if (s.isCompleted) '${previous.containmentGuide!.id}:${s.stepNumber}',
      };

      fresh = fresh.copyWith(
        probableMaterials: [
          for (final m in fresh.probableMaterials)
            m.copyWith(clientAlreadyHasIt: ownedIds.contains(m.id)),
        ],
        containmentGuide: fresh.containmentGuide?.copyWith(
          steps: [
            for (final s in fresh.containmentGuide!.steps)
              s.copyWith(
                isCompleted: completedSteps.contains(
                  '${fresh.containmentGuide!.id}:${s.stepNumber}',
                ),
              ),
          ],
        ),
      );
    }

    state = fresh;
    return fresh;
  }

  void setResult(SmartTriageResult? result) {
    state = result;
  }

  void toggleClientHasMaterial(String materialId) {
    final current = state;
    if (current == null) return;
    state = current.toggleMaterial(materialId);
  }

  void toggleContainmentStep(int stepNumber) {
    final current = state;
    if (current == null) return;
    state = current.toggleContainmentStep(stepNumber);
  }

  void clear() {
    state = null;
  }
}

final smartTriageControllerProvider =
    NotifierProvider<SmartTriageController, SmartTriageResult?>(
      SmartTriageController.new,
    );

/// Repositório reativo Riverpod que vincula `SmartTriageResult` ao `jobId`.
class JobTriageRegistry extends Notifier<Map<String, SmartTriageResult>> {
  @override
  Map<String, SmartTriageResult> build() {
    unawaited(JobTriageStore.instance.ensureHydrated());
    void listener() {
      state = JobTriageStore.instance.value;
    }

    JobTriageStore.instance.addListener(listener);
    ref.onDispose(() => JobTriageStore.instance.removeListener(listener));
    return JobTriageStore.instance.value;
  }

  void saveForJob(String jobId, SmartTriageResult result) {
    JobTriageStore.instance.saveForJob(jobId, result);
    state = JobTriageStore.instance.value;
  }

  SmartTriageResult resolveForJob(Job job) =>
      JobTriageStore.instance.resolveForJob(job);

  void toggleMaterialForJob(Job job, String materialId) {
    JobTriageStore.instance.toggleMaterialForJob(job, materialId);
    state = JobTriageStore.instance.value;
  }

  void toggleContainmentStepForJob(Job job, int stepNumber) {
    JobTriageStore.instance.toggleContainmentStepForJob(job, stepNumber);
    state = JobTriageStore.instance.value;
  }
}

final jobTriageRegistryProvider =
    NotifierProvider<JobTriageRegistry, Map<String, SmartTriageResult>>(
      JobTriageRegistry.new,
    );
