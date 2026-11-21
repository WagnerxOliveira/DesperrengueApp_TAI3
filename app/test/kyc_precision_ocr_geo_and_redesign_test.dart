import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/address_lookup.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/services/document_real_ocr_engine.dart';
import 'package:desperrengue_app/core/services/native_reverse_geocoder.dart';
import 'package:desperrengue_app/core/services/precise_location_acquisition_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/client/presentation/document_ocr_review_step.dart';
import 'package:desperrengue_app/features/client/presentation/widgets/kyc_onboarding_chrome.dart';
import 'package:desperrengue_app/features/shared/presentation/criminal_background_check_step.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. OCR Bancário CNH — Geometria 2D, Ruído OCR, Escalonamento Vision e Zero 01/01/1990', () {
    test('CNH Clássica com texto linearizado embaralhado resolve Data de Nascimento exata via Âncora Espacial 2D', () {
      // Simula o ML Kit lendo coluna esquerda (CPF) e coluna direita (DATA NASCIMENTO)
      // fora de ordem na string achatada, mas preservando as caixas 2D reais!
      const scrambledFlatText = '''
REPÚBLICA FEDERATIVA DO BRASIL
CARTEIRA NACIONAL DE HABILITAÇÃO
NOME
WAGNER OLIVEIRA CLAUDIANO
CPF
DATA NASCIMENTO
119.787.236-10
VALIDADE
1ª HABILITAÇÃO
15/06/2029
12/04/2014
03/01/1995
Nº REGISTRO
07564207706
DETRAN/MG
''';

      const frontLines = <OcrTextLineBox>[
        OcrTextLineBox(text: 'CPF', left: 320, top: 410, right: 430, bottom: 438),
        OcrTextLineBox(text: '119.787.236-10', left: 320, top: 445, right: 560, bottom: 480),
        OcrTextLineBox(text: 'DATA NASCIMENTO', left: 610, top: 410, right: 860, bottom: 438),
        OcrTextLineBox(text: '03/01/1995', left: 620, top: 446, right: 810, bottom: 480),
        OcrTextLineBox(text: 'VALIDADE', left: 320, top: 530, right: 480, bottom: 558),
        OcrTextLineBox(text: '15/06/2029', left: 320, top: 565, right: 500, bottom: 598),
        OcrTextLineBox(text: '1ª HABILITAÇÃO', left: 610, top: 530, right: 850, bottom: 558),
        OcrTextLineBox(text: '12/04/2014', left: 620, top: 565, right: 810, bottom: 598),
      ];

      final parsed = BrazilianDocumentOcrParser.parse(
        frontText: scrambledFlatText,
        backText: 'RENACH MG123456789',
        expectedDocumentType: OfficialDocumentType.cnh,
        frontLines: frontLines,
      );

      expect(parsed.birthDate, equals(DateTime.utc(1995, 1, 3)));
      expect(parsed.birthDateConfidence, greaterThanOrEqualTo(0.95));
      expect(parsed.hasHighConfidenceCoreFields, isTrue);
    });

    test('CNH 2022 Padrão Viena (Campo 3) distingue Nascimento de 4a Emissão, 4b Validade e 1ª Habilitação + repara ruído OCR', () {
      const cnh2022Noisy = '''
REPÚBLICA FEDERATIVA DO BRASIL
SENATRAN CARTEIRA NACIONAL DE HABILITAÇÃO
2 e 1 NOME E SOBRENOME
WAGNER OLIVEIRA CLAUDIANO
3 DATA, LOCAL E UF DE NASCIMENTO
O3/O1/199S POÇOS DE CALDAS MG
4a DATA EMISSÃO
10/02/2024
4b VALIDADE
10/02/2034
4d CPF
119.787.236-10
5 Nº REGISTRO
07564207706
DETRAN/MG
''';

      final parsed = BrazilianDocumentOcrParser.parse(
        frontText: cnh2022Noisy,
        backText: 'RENACH MG987654321',
        expectedDocumentType: OfficialDocumentType.cnh,
      );

      expect(parsed.birthDate, equals(DateTime.utc(1995, 1, 3)));
      expect(parsed.birthDateConfidence, greaterThanOrEqualTo(0.90));
    });

    test('JAMAIS fabrica 01/01/1990 quando a Data de Nascimento está ausente/ilegível na CNH e escala automaticamente para Vision AI', () async {
      const cnhMissingBirth = '''
REPÚBLICA FEDERATIVA DO BRASIL
CARTEIRA NACIONAL DE HABILITAÇÃO
NOME
WAGNER OLIVEIRA CLAUDIANO
CPF
119.787.236-10
Nº REGISTRO
07564207706
DETRAN/MG
''';

      // 1. Sem Vision AI: NUNCA pode fabricar 01/01/1990; deve lançar ERR_OCR_BIRTHDATE_UNREADABLE!
      final frontImg = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 3,
      );
      final backImg = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 19,
      );

      Object? caught;
      try {
        await DocumentOcrAndLivenessService.runRealDocumentOcrAndForensics(
          frontImageBytes: frontImg,
          backImageBytes: backImg,
          documentType: OfficialDocumentType.cnh,
          typedFullName: 'Wagner Oliveira Claudiano',
          typedCpfRaw: '119.787.236-10',
          rawOcrFrontTextOverride: cnhMissingBirth,
          rawOcrBackTextOverride: 'RENACH MG987654321',
          allowSupabaseEdgeFallback: false,
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<StateError>());
      expect(caught.toString(), contains('ERR_OCR_BIRTHDATE_UNREADABLE'));
      final friendly = KycHumanFeedbackTranslator.translateError(caught);
      expect(friendly.toLowerCase(), contains('data de nascimento'));
      expect(KycHumanFeedbackTranslator.containsBannedTechnicalJargon(friendly), isFalse);

      // 2. Com Vision AI (Edge Function): mesmo com Nome+CPF lidos localmente,
      //    escala automaticamente porque birthDate == null e recupera a data real!
      bool edgeCalled = false;
      final escalated = await DocumentRealOcrEngine.extractAndParse(
        frontImageBytes: Uint8List.fromList([1, 2, 3]),
        backImageBytes: Uint8List.fromList([4, 5, 6]),
        expectedDocumentType: OfficialDocumentType.cnh,
        rawOcrFrontTextOverride: cnhMissingBirth,
        rawOcrBackTextOverride: 'RENACH MG987654321',
        edgeVisionGateInvoker: (payload) async {
          edgeCalled = true;
          return <String, dynamic>{
            'ready_for_serpro_and_carbon': true,
            'extracted_full_name': 'WAGNER OLIVEIRA CLAUDIANO',
            'extracted_cpf_11_digits': '11978723610',
            'extracted_birth_date_iso': '1995-01-03',
            'extracted_document_number': '07564207706',
            'extracted_issuing_authority': 'DETRAN/MG',
            'quality_gate': <String, dynamic>{
              'is_readable': true,
              'detected_document_type': 'CNH',
              'canonical_rotation_deg': 0,
            },
          };
        },
      );

      expect(edgeCalled, isTrue);
      expect(escalated.birthDate, equals(DateTime.utc(1995, 1, 3)));
      expect(escalated.birthDateConfidence, greaterThanOrEqualTo(0.95));
    });
  });

  group('2. Geolocalização Precisa & Reverse Geocoding Anti-Sobrescrita (Custo Zero)', () {
    test('Prioriza Geocoder Nativo (Google/Apple Maps) sem chamar Nominatim quando retorna rua completa', () async {
      final hostsCalled = <String>[];
      final client = MockClient((req) async {
        hostsCalled.add(req.url.host);
        if (req.url.host == 'viacep.com.br') {
          return http.Response(
            '{"cep":"37701-014","logradouro":"Rua Prefeito Chagas","bairro":"Centro","localidade":"Poços de Caldas","uf":"MG"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 500);
      });

      final lookup = AddressLookup(
        client,
        (lat, lng) async => NativeReversedPlacemark(
          street: 'R. Pref. Chagas',
          number: '120',
          neighborhood: 'Centro',
          city: 'Poços de Caldas',
          state: 'Minas Gerais',
          postalCode: '37701-014',
          latitude: lat,
          longitude: lng,
          source: 'android_geocoder',
        ),
      );

      final result = (await lookup.byCoordinates(-21.7878, -46.5612))!;
      expect(hostsCalled, isNot(contains('nominatim.openstreetmap.org')));
      expect(result.street, equals('Rua Prefeito Chagas'));
      expect(result.neighborhood, equals('Centro'));
      expect(result.city, equals('Poços de Caldas'));
      expect(result.uf, equals('MG'));
      expect(result.cep, equals('37701014'));
    });

    test('CEP ERRADO do Nominatim JAMAIS sobrescreve a rua real do GPS; descarta CEP errado e busca CEP verdadeiro por endereço', () async {
      const headers = {'content-type': 'application/json; charset=utf-8'};
      final client = MockClient((req) async {
        if (req.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            '{"lat":"-21.7878","lon":"-46.5612","address":{"road":"Rua Assis Figueiredo","suburb":"Centro","city":"Poços de Caldas","ISO3166-2-lvl4":"BR-MG","postcode":"37701-999"}}',
            200,
            headers: headers,
          );
        }
        if (req.url.host == 'photon.komoot.io') {
          return http.Response('{"features":[]}', 200, headers: headers);
        }
        if (req.url.host == 'viacep.com.br' && req.url.path.contains('37701999')) {
          // CEP errado vindo do OSM aponta para outra rua totalmente diferente!
          return http.Response(
            '{"cep":"37701-999","logradouro":"Avenida João Pinheiro","bairro":"Jardim Country Club","localidade":"Poços de Caldas","uf":"MG"}',
            200,
            headers: headers,
          );
        }
        if (req.url.host == 'viacep.com.br' && req.url.path.contains('/MG/')) {
          // Busca reversa no ViaCEP pela rua real devolve o CEP verdadeiro!
          return http.Response(
            '[{"cep":"37701-000","logradouro":"Rua Assis Figueiredo","bairro":"Centro","localidade":"Poços de Caldas","uf":"MG"}]',
            200,
            headers: headers,
          );
        }
        return http.Response('{}', 404);
      });

      final result = (await AddressLookup(client).byCoordinates(-21.7878, -46.5612))!;
      expect(result.street, equals('Rua Assis Figueiredo'));
      expect(result.neighborhood, equals('Centro'));
      expect(result.cep, equals('37701000'));
    });

    test('PreciseLocationAcquisitionService filtra fixes antigos/mockados, escolhe menor accuracy e classifica precisão', () {
      final now = DateTime.utc(2026, 11, 21, 3, 0, 0);
      Position makePos({
        required double acc,
        required Duration age,
        bool mocked = false,
      }) =>
          Position(
            longitude: -46.5612,
            latitude: -21.7878,
            timestamp: now.subtract(age),
            accuracy: acc,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
            isMocked: mocked,
          );

      final best = PreciseLocationAcquisitionService.pickBestFreshPosition(
        [
          makePos(acc: 5.0, age: const Duration(seconds: 2), mocked: true), // mockado -> descartado
          makePos(acc: 8.0, age: const Duration(seconds: 40)), // velho -> descartado
          makePos(acc: 210.0, age: const Duration(seconds: 2)), // torre celular
          makePos(acc: 11.4, age: const Duration(seconds: 1)), // GNSS preciso!
        ],
        nowUtc: now,
      );

      expect(best, isNotNull);
      expect(best!.accuracy, closeTo(11.4, 0.01));
      expect(PreciseLocationFix.classifyAccuracy(11.4), LocationFixQuality.precise);
      expect(PreciseLocationFix.classifyAccuracy(45.0), LocationFixQuality.moderate);
      expect(PreciseLocationFix.classifyAccuracy(120.0), LocationFixQuality.coarse);
    });
  });

  group('3. Redesign Obsidian Atelier & Seletor Universal (Zero Quebra, Zero Pasta Downloads no Título)', () {
    testWidgets('Bottom Sheet da Certidão PF remove "(Pasta Downloads)" e explica navegação livre em qualquer pasta', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(UserMode.client, Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CriminalBackgroundCheckStep(
                expectedFullName: 'Wagner Oliveira Claudiano',
                expectedCpfRaw: '119.787.236-10',
                onValidated: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.byKey(const ValueKey('btn-upload-criminal-certificate'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('(Pasta Downloads)'), findsNothing);
      expect(find.text('Escolher PDF ou arquivo do celular'), findsOneWidget);
      expect(find.textContaining('qualquer pasta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KycPorcelainSectionCard dá 100% da largura ao título em 360dp Dark (sem esmagar contra o chip)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(UserMode.client, Brightness.dark),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: KycPorcelainSectionCard(
                title: '2. Enviar certidão com conferência automática',
                subtitle: 'Subtítulo longo que deve ocupar toda a largura do cartão sem esmagar.',
                icon: Icons.upload_file_rounded,
                statusChipLabel: 'Aguardando',
                child: Text('Conteúdo'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleBox = tester.getRect(
        find.text('2. Enviar certidão com conferência automática'),
      );
      final chipBox = tester.getRect(find.text('Aguardando'));

      // Título fica ABAIXO da barra de ícone+chip, com largura confortável (> 250px em tela 360dp)!
      expect(titleBox.top, greaterThan(chipBox.bottom - 1));
      expect(titleBox.width, greaterThan(240));
      expect(tester.takeException(), isNull);
    });

    testWidgets('DocumentOcrReviewStep remove jargão "(OCR)" do título e mantém toggle do CPF inline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ocr = AuditedDocumentOcrResult(
        documentType: OfficialDocumentType.cnh,
        extractedFullName: 'WAGNER OLIVEIRA CLAUDIANO',
        extractedCpfDigits: '11978723610',
        extractedCpfFormatted: '119.787.236-10',
        extractedCpfMasked: '***.787.236-**',
        cpfHash: DocumentOcrAndLivenessService.computeCpfHash('11978723610'),
        extractedDocumentNumber: '07564207706',
        extractedDocumentNumberMasked: '***-7706',
        extractedBirthDate: DateTime.utc(1995, 1, 3),
        extractedBirthDateFormatted: '03/01/1995',
        extractedIssuingAuthority: 'DETRAN/MG',
        frontPerceptualHash64: 1,
        backPerceptualHash64: 2,
        frontBackHammingDistance: 20,
        laplacianSharpnessScore: 300,
        specularGlareRatioPct: 1.0,
        ocrConfidenceScore: 98.0,
        faceMatchCosineSimilarity: 0.97,
        nameCrossCheckSimilarity: 1.0,
        mrzOrQrChecksumValid: true,
        officialHeaderDetected: true,
        isAuthenticAndCrossChecked: true,
        forensicVerificationSeal: 'DSP-OCR-SHA256-02E94A7A318A88AE4E4C',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(UserMode.client, Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DocumentOcrReviewStep(
                ocrResult: ocr,
                typedName: 'Wagner Oliveira Claudiano',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dados do documento'), findsOneWidget);
      expect(find.textContaining('(OCR)'), findsNothing);
      expect(find.text('03/01/1995'), findsOneWidget);

      final cpfTextRect = tester.getRect(find.textContaining('***.787.236-**'));
      final eyeBtnRect = tester.getRect(find.byKey(const ValueKey('toggle-cpf-reveal')));
      // O botão do olho fica alinhado horizontalmente na mesma linha do CPF (sem buraco abaixo!)
      expect((cpfTextRect.center.dy - eyeBtnRect.center.dy).abs(), lessThan(24));
      expect(tester.takeException(), isNull);
    });
  });
}
