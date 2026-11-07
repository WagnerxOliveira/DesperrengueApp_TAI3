import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/smart_triage_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/smart_triage_service.dart';
import 'package:desperrengue_app/core/services/text_refine_service.dart';
import 'package:desperrengue_app/core/state/smart_triage_controller.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/client/presentation/order_tracking_screen.dart';
import 'package:desperrengue_app/features/client/presentation/request_wizard.dart';
import 'package:desperrengue_app/features/shared/presentation/smart_triage_widgets.dart';

class _NoRefine implements TextRefiner {
  const _NoRefine();
  @override
  Future<String> refine(String text) async => text;
}

void main() {
  setUp(() {
    JobTriageStore.instance.clearForTest();
  });

  group('ETAPA 1 — Modelos de Domínio e Serialização', () {
    test('UrgencyLevel: labels, SLA, ícones e cores Light/Dark', () {
      final lightScheme = ColorScheme.fromSeed(seedColor: Colors.orange);
      final darkScheme = ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      );

      for (final level in UrgencyLevel.values) {
        expect(level.label, isNotEmpty);
        expect(level.slaTargetText, isNotEmpty);
        expect(level.icon, isNotNull);
        expect(level.resolveColor(lightScheme), isNotNull);
        expect(level.resolveContainerColor(lightScheme), isNotNull);
        expect(level.resolveColor(darkScheme), isNotNull);
        expect(level.resolveContainerColor(darkScheme), isNotNull);
        expect(UrgencyLevel.parse(level.wire), level);
        expect(UrgencyLevel.parse(level.name), level);
      }
      expect(UrgencyLevel.criticalEmergency.label, 'Emergência Crítica');
    });

    test('ProbableMaterialItem, ContainmentStep, EmergencyContainmentGuide e SmartTriageResult: JSON roundtrip e igualdade', () {
      final original = SmartTriageService.instance.analyze(
        rawText: 'Sinto cheiro forte de gás perto do botijão na cozinha',
        mediaAttachments: const ['botijao.jpg'],
        now: DateTime.utc(2026, 11, 6, 12, 0),
      );

      expect(original.hasEmergencyContainment, isTrue);
      expect(original.containmentGuide!.completedStepsCount, 0);
      expect(original.containmentGuide!.completionProgress, 0.0);
      expect(original.containmentGuide!.isFullyContained, isFalse);
      expect(
        original.materialsProviderMustBring.length,
        original.probableMaterials.length,
      );
      expect(original.materialsClientProvides, isEmpty);

      // Alterna peça e todos os passos de contenção
      var modified = original.toggleMaterial(original.probableMaterials.first.id);
      for (final s in modified.containmentGuide!.steps) {
        modified = modified.toggleContainmentStep(s.stepNumber);
      }

      expect(modified.materialsClientProvides, hasLength(1));
      expect(
        modified.materialsProviderMustBring.length,
        original.probableMaterials.length - 1,
      );
      expect(modified.containmentGuide!.isFullyContained, isTrue);
      expect(modified.containmentGuide!.completionProgress, 1.0);

      // Serialização JSON completa
      final jsonStr = modified.toJson();
      final restored = SmartTriageResult.fromJson(jsonStr);
      expect(restored, equals(modified));
      expect(restored.hashCode, equals(modified.hashCode));
    });
  });

  group('ETAPA 2 — Motor de Triagem Multimodal (7 Matrizes Técnicas + 33 Categorias)', () {
    const svc = SmartTriageService.instance;

    test('1. Hidráulica / Encanamento: cano estourado e vazamento', () {
      final res = svc.analyze(
        rawText: 'Estourou o cano debaixo da pia e está vazando muito no chão',
      );
      expect(res.suggestedCategoryName, 'Encanador');
      expect(res.urgencyLevel, UrgencyLevel.criticalEmergency);
      expect(res.probableMaterials, isNotEmpty);
      expect(res.recommendedProviderTools, contains('Chave grifo 12"'));
      expect(res.hasEmergencyContainment, isTrue);
      expect(
        res.containmentGuide!.steps.first.title,
        contains('Feche o registro geral'),
      );
    });

    test('2. Elétrica Residencial: curto-circuito, faísca e disjuntor desarmando', () {
      final res = svc.analyze(
        rawText: 'O chuveiro pipocou, saiu faísca e o disjuntor está desarmando com cheiro de queimado',
      );
      expect(res.suggestedCategoryName, 'Elétrica');
      expect(res.urgencyLevel, UrgencyLevel.criticalEmergency);
      expect(res.containmentGuide!.emergencyPublicPhone, '193');
      expect(
        res.containmentGuide!.steps.any((s) => s.isCriticalSafetyWarning),
        isTrue,
      );
    });

    test('3. Gás / Aquecedores: vazamento de gás classifica como Emergência Crítica', () {
      final res = svc.analyze(
        rawText: 'Cheiro forte de gás na área de serviço perto do aquecedor',
      );
      expect(res.suggestedCategoryName, 'Gás e Aquecedores');
      expect(res.urgencyLevel, UrgencyLevel.criticalEmergency);
      expect(res.containmentGuide!.criticalProhibitions, isNotEmpty);
      expect(res.containmentGuide!.emergencyPublicPhone, '193');
    });

    test('4. Chaveiro / Fechaduras: chave quebrada no cilindro', () {
      final res = svc.analyze(
        rawText: 'A chave quebrou dentro da fechadura e a porta ficou trancada',
      );
      expect(res.suggestedCategoryName, 'Chaveiro');
      expect(res.urgencyLevel, UrgencyLevel.high);
      expect(
        res.containmentGuide!.criticalProhibitions.first,
        contains('Não introduza facas'),
      );
    });

    test('5. Telhado / Calhas: goteira ativa no forro', () {
      final res = svc.analyze(
        rawText: 'Telha quebrada com goteira forte no forro de gesso da sala',
      );
      expect(res.suggestedCategoryName, 'Telhados e Calhas');
      expect(res.urgencyLevel, UrgencyLevel.criticalEmergency);
      expect(res.containmentGuide!.emergencyPublicPhone, '199');
    });

    test('6. Climatização / Ar-Condicionado: split pingando água', () {
      final res = svc.analyze(
        rawText: 'Meu ar-condicionado split está pingando água pela evaporadora',
      );
      expect(res.suggestedCategoryName, 'Ar-condicionado');
      expect(res.urgencyLevel, UrgencyLevel.high);
      expect(res.probableMaterials.first.name, contains('dreno'));
    });

    test('7. Marcenaria / Montagem / Reparos: porta de guarda-roupa caindo', () {
      final res = svc.analyze(
        rawText: 'A porta do guarda-roupa está caindo porque quebrou a dobradiça',
      );
      expect(res.suggestedCategoryName, 'Marcenaria');
      expect(res.urgencyLevel, UrgencyLevel.high);
      expect(res.probableMaterials.first.name, contains('Dobradiça caneco 35mm'));
    });

    test('8. Pintura: respeita categoria Pintura, lista insumos de pintura e NUNCA exibe Primeiros Socorros do Imóvel', () {
      final res = svc.analyze(
        rawText: 'Preciso pintar a sala de estar e o corredor do apartamento',
        currentCategory: 'Pintura',
      );
      expect(res.suggestedCategoryName, 'Pintura');
      expect(res.hasEmergencyContainment, isFalse);
      expect(res.containmentGuide, isNull);
      expect(
        res.probableMaterials.map((m) => m.name).join(' '),
        allOf(
          contains('Tinta Acrílica'),
          contains('Massa Corrida'),
          contains('Rolo de Lã Antigota'),
        ),
      );
      expect(
        res.probableMaterials.map((m) => m.name).join(' '),
        isNot(contains('Dobradiça')),
      );
    });

    test('9. Todas as 33 categorias de kCategories retornam diagnóstico coerente com a categoria escolhida pelo cliente', () {
      for (final cat in kCategories) {
        final res = svc.analyze(
          rawText: 'Preciso contratar serviço profissional na minha residência.',
          currentCategory: cat.name,
        );
        expect(
          res.suggestedCategoryName,
          cat.name,
          reason: 'Categoria selecionada ${cat.name} deve ser respeitada',
        );
        expect(
          res.probableMaterials,
          isNotEmpty,
          reason: 'Categoria ${cat.name} deve listar materiais/insumos',
        );
      }
    });
  });

  group('ETAPAS 3, 4 e 5 — UI/UX SmartTriageCard, EmergencyContainmentBanner e Visão do Prestador', () {
    testWidgets('SmartTriageCard + EmergencyContainmentBanner: interatividade e zero overflow em 360px Dark Mode', (t) async {
      t.view.physicalSize = const Size(360 * 2.0, 3600 * 2.0);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      var triage = SmartTriageService.instance.analyze(
        rawText: 'Cheiro forte de gás no fogão e mangueira vencida',
      );
      String? appliedCategory;

      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.resolve(UserMode.client, Brightness.dark),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      EmergencyContainmentBanner(
                        guide: triage.containmentGuide!,
                        onToggleStep: (stepNo) {
                          setState(() => triage = triage.toggleContainmentStep(stepNo));
                        },
                      ),
                      const SizedBox(height: 12),
                      SmartTriageCard(
                        result: triage,
                        selectedCategory: 'Elétrica',
                        onApplyCategory: (cat) => setState(() => appliedCategory = cat),
                        onToggleMaterial: (id) {
                          setState(() => triage = triage.toggleMaterial(id));
                        },
                      ),
                      const SizedBox(height: 12),
                      ProviderTriageBriefCard(result: triage),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();

      expect(find.byKey(const ValueKey('emergency-containment-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-triage-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-triage-brief-card')), findsOneWidget);
      expect(find.textContaining('Primeiros Socorros do Imóvel'), findsOneWidget);
      expect(find.byKey(const ValueKey('emergency-public-call')), findsOneWidget);

      // Aplica categoria sugerida
      await t.tap(find.byKey(const ValueKey('triage-apply-category')));
      await t.pump();
      expect(appliedCategory, 'Gás e Aquecedores');

      // Marca que o cliente já possui a primeira peça
      final firstMatId = triage.probableMaterials.first.id;
      await t.tap(find.byKey(ValueKey('triage-material-$firstMatId')));
      await t.pump();
      expect(find.textContaining('Cliente fornece'), findsOneWidget);
      expect(find.textContaining('Peças que o cliente já tem no local (1):'), findsOneWidget);

      // Conclui todos os passos de contenção
      for (final step in triage.containmentGuide!.steps) {
        await t.tap(find.byKey(ValueKey('containment-step-${step.stepNumber}')));
        await t.pump();
      }
      expect(
        find.text('Contenção inicial concluída! Imóvel estabilizado aguardando o profissional.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('RequestWizardScreen e OrderTrackingScreen exibem a Triagem IA e a Contenção de 60s', (t) async {
      t.view.physicalSize = const Size(480 * 2.0, 2600 * 2.0);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      const profile = UserProfile(
        id: 'cli-1',
        fullName: 'Wagner Oliveira',
        isClient: true,
        isProvider: false,
        verificationStatus: VerificationStatus.active,
        addressLine: 'Rua Padre José, 100 - Centro',
        addressCity: 'Santa Rita do Sapucaí',
      );

      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.resolve(UserMode.client, Brightness.light),
            home: const RequestWizardScreen(
              profile: profile,
              category: 'Elétrica',
              textRefiner: _NoRefine(),
            ),
          ),
        ),
      );
      await t.pump();

      await t.enterText(
        find.byKey(const ValueKey('description-field')),
        'O disjuntor do chuveiro pipocou e saiu faísca no quadro de luz.',
      );
      await t.pump();

      await t.tap(find.byKey(const ValueKey('btn-smart-triage')));
      await t.pump();

      expect(find.byKey(const ValueKey('smart-triage-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('emergency-containment-banner')), findsOneWidget);

      // Verifica OrderTrackingScreen com o chamado ativo
      final job = Job(
        id: 'job-triage-12345',
        clientId: 'cli-1',
        title: 'Disjuntor pipocou',
        description: 'O disjuntor do chuveiro pipocou e saiu faísca no quadro de luz.',
        category: 'Elétrica',
        status: JobStatus.inProgress,
        paymentStatus: 'escrow',
        urgency: 'emergency',
        visibility: 'direct',
        createdAt: DateTime(2026, 11, 6),
        agreedPrice: 120,
      );

      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.resolve(UserMode.client, Brightness.light),
            home: OrderTrackingScreen(job: job),
          ),
        ),
      );
      await t.pump();

      expect(find.text('Acompanhe seu Pedido'), findsOneWidget);
      expect(find.byKey(const ValueKey('emergency-containment-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-triage-card')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
