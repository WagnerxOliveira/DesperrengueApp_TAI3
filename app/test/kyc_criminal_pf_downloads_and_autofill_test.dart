import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/criminal_background_service.dart';
import 'package:desperrengue_app/core/services/criminal_certificate_picker_and_extractor.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/shared/presentation/criminal_background_check_step.dart';

Widget _buildTestApp({
  required Widget home,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: AppTheme.resolve(UserMode.client, brightness),
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: home,
  );
}

/// Constrói um PDF real com `FlateDecode` + fonte `Identity-H` / `CIDFontType2`
/// usando `ToUnicode CMap` (`beginbfchar` e `beginbfrange`) e operador `TJ` com kerning,
/// idêntico à estrutura dos PDFs emitidos por `servicos.pf.gov.br/epol-sinic-publico/`.
Uint8List _buildFlateToUnicodePfPdf({
  required String plainLine1,
  required String plainLine2,
  required String plainLine3,
}) {
  // Mapeia cada caractere único para um CID de 2 bytes (>= 0x0010)
  // Usa beginbfrange para dígitos '0'..'9' (0x0100..0x0109) e beginbfchar para demais caracteres
  final charToCid = <int, int>{};
  for (int d = 0; d < 10; d++) {
    charToCid[0x30 + d] = 0x0100 + d;
  }

  final bfCharEntries = StringBuffer();
  int nextCid = 0x0010;
  final allText = '$plainLine1$plainLine2$plainLine3';
  for (final cu in allText.codeUnits) {
    if (charToCid.containsKey(cu)) continue;
    final cid = nextCid++;
    charToCid[cu] = cid;
    final cidHex = cid.toRadixString(16).toUpperCase().padLeft(4, '0');
    final uniHex = cu.toRadixString(16).toUpperCase().padLeft(4, '0');
    bfCharEntries.writeln('<$cidHex> <$uniHex>');
  }

  String encodeHex(String s) {
    final sb = StringBuffer();
    for (final cu in s.codeUnits) {
      final cid = charToCid[cu]!;
      sb.write(cid.toRadixString(16).toUpperCase().padLeft(4, '0'));
    }
    return sb.toString();
  }

  final cmapSource =
      '/CIDInit /ProcSet findresource begin\n'
      '12 dict begin\n'
      'begincmap\n'
      '1 begincodespacerange\n'
      '<0000> <FFFF>\n'
      'endcodespacerange\n'
      '1 beginbfrange\n'
      '<0100> <0109> <0030>\n'
      'endbfrange\n'
      '${charToCid.length} beginbfchar\n'
      '${bfCharEntries.toString()}'
      'endbfchar\n'
      'endcmap\n'
      'end\n'
      'end\n';

  // Divide a linha 2 em um array TJ com kerning pequeno (-20 -> mesma palavra) e grande (-240 -> espaço)
  final words2 = plainLine2.split(' ');
  final tjParts = <String>[];
  for (int i = 0; i < words2.length; i++) {
    final w = words2[i];
    if (w.length > 4) {
      tjParts.add('<${encodeHex(w.substring(0, 2))}> -15 <${encodeHex(w.substring(2))}>');
    } else {
      tjParts.add('<${encodeHex(w)}>');
    }
    if (i < words2.length - 1) {
      tjParts.add('-240');
    }
  }

  final contentStreamSource =
      'BT\n'
      '/F1 11 Tf\n'
      '<${encodeHex(plainLine1)}> Tj\n'
      '[${tjParts.join(' ')}] TJ\n'
      '<${encodeHex(plainLine3)}> Tj\n'
      'ET\n';

  final cmapCompressed = Uint8List.fromList(zlib.encode(utf8.encode(cmapSource)));
  final contentCompressed = Uint8List.fromList(
    zlib.encode(utf8.encode(contentStreamSource)),
  );

  final out = BytesBuilder();
  out.add(latin1.encode('%PDF-1.5\n'));
  out.add(
    latin1.encode(
      '1 0 obj << /Type /Font /Subtype /Type0 /Encoding /Identity-H /ToUnicode 2 0 R >> endobj\n',
    ),
  );
  out.add(
    latin1.encode(
      '2 0 obj << /Length ${cmapCompressed.length} /Filter /FlateDecode >>\nstream\n',
    ),
  );
  out.add(cmapCompressed);
  out.add(latin1.encode('\nendstream\nendobj\n'));
  out.add(
    latin1.encode(
      '3 0 obj << /Resources << /Font << /F1 1 0 R >> >> /Length ${contentCompressed.length} /Filter /FlateDecode >>\nstream\n',
    ),
  );
  out.add(contentCompressed);
  out.add(latin1.encode('\nendstream\nendobj\n%%EOF\n'));
  return out.toBytes();
}

/// Constrói um PDF com `FlateDecode` + PNG Predictor (`/Predictor 12`, filtro Up=2)
/// e Object Stream (`/Type /ObjStm`).
Uint8List _buildFlatePngPredictorAndObjStmPdf(String contentStream, String objStmText) {
  final rawBytes = utf8.encode(contentStream);
  const columns = 16;
  final rows = (rawBytes.length + columns - 1) ~/ columns;
  final padded = Uint8List(rows * columns);
  padded.setAll(0, rawBytes);

  // Aplica filtro PNG Up (tipo 2) em cada linha
  final filtered = BytesBuilder();
  var prev = Uint8List(columns);
  for (int r = 0; r < rows; r++) {
    filtered.addByte(2); // PNG Up filter
    final cur = Uint8List.sublistView(padded, r * columns, (r + 1) * columns);
    for (int i = 0; i < columns; i++) {
      filtered.addByte((cur[i] - prev[i]) & 0xFF);
    }
    prev = cur;
  }
  final predCompressed = Uint8List.fromList(zlib.encode(filtered.toBytes()));

  final objHeader = '10 0 ';
  final objStmRaw = '$objHeader$objStmText';
  final objStmCompressed = Uint8List.fromList(zlib.encode(utf8.encode(objStmRaw)));

  final out = BytesBuilder();
  out.add(latin1.encode('%PDF-1.6\n'));
  out.add(
    latin1.encode(
      '4 0 obj << /Length ${predCompressed.length} /Filter /FlateDecode '
      '/DecodeParms << /Predictor 12 /Columns $columns /Colors 1 /BitsPerComponent 8 >> >>\nstream\n',
    ),
  );
  out.add(predCompressed);
  out.add(latin1.encode('\nendstream\nendobj\n'));
  out.add(
    latin1.encode(
      '5 0 obj << /Type /ObjStm /N 1 /First ${objHeader.length} '
      '/Length ${objStmCompressed.length} /Filter /FlateDecode >>\nstream\n',
    ),
  );
  out.add(objStmCompressed);
  out.add(latin1.encode('\nendstream\nendobj\n%%EOF\n'));
  return out.toBytes();
}

Uint8List _buildCrispPhotoCertificateBytes({int width = 200, int height = 260}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(248, 248, 248));
  for (int y = 20; y < height - 20; y += 16) {
    for (int x = 18; x < width - 18; x++) {
      image.setPixelRgb(x, y, 24, 28, 36);
      image.setPixelRgb(x, y + 1, 24, 28, 36);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('1. Parser PDF Real PF (FlateDecode + ToUnicode CMap + PNG Predictor + ObjStm + QR URL)', () {
    final refNow = DateTime.utc(2026, 11, 18, 12);
    const validCpf = '119.787.236-10';
    const validName = 'Wagner Oliveira Claudiano';

    test('decodifica PDF compactado FlateDecode + ToUnicode CMap (beginbfchar + beginbfrange + TJ kerning) e aprova', () async {
      final pdfBytes = _buildFlateToUnicodePfPdf(
        plainLine1: 'MINISTÉRIO DA JUSTIÇA E SEGURANÇA PÚBLICA - POLÍCIA FEDERAL - SINIC',
        plainLine2:
            'CERTIDÃO DE ANTECEDENTES CRIMINAIS nº 195290532026 - A Polícia Federal CERTIFICA que NÃO CONSTA condenação em nome de WAGNER OLIVEIRA CLAUDIANO, CPF 119.787.236-10.',
        plainLine3:
            'Emitida às 14:32 do dia 15/11/2026. Código de validação: ABCD.1234.EF56.7890',
      );

      final decoded = CriminalBackgroundService.extractReadableTextFromPdfOrBytes(pdfBytes);
      expect(decoded, contains('POLÍCIA FEDERAL'));
      expect(decoded, contains('195290532026'));
      expect(decoded, contains('NÃO CONSTA'));
      expect(decoded, contains('ABCD.1234.EF56.7890'));

      final fields = CriminalBackgroundService.extractCertificateFieldsFromText(decoded);
      expect(fields.protocolNumber, equals('195290532026'));
      expect(fields.issuedDate, equals(DateTime.utc(2026, 11, 15)));
      expect(fields.validationCode, equals('ABCD.1234.EF56.7890'));

      final result = await CriminalBackgroundService.analyzeAndValidateCertificate(
        fileBytes: pdfBytes,
        fileName: 'certidao_pf_epol.pdf',
        expectedFullName: validName,
        expectedCpfRaw: validCpf,
        referenceNow: refNow,
      );
      expect(result.passed, isTrue, reason: result.humanFeedbackMessage);
      expect(result.protocolNumber, equals('195290532026'));
      expect(result.validationCode, equals('ABCD.1234.EF56.7890'));
      expect(result.issuedDate, equals(DateTime.utc(2026, 11, 15)));
    });

    test('decodifica stream FlateDecode com PNG Predictor (/Predictor 12) e Object Stream (/Type /ObjStm)', () {
      final pdfBytes = _buildFlatePngPredictorAndObjStmPdf(
        'BT (POLICIA FEDERAL - CERTIDAO DE ANTECEDENTES CRIMINAIS - NADA CONSTA) Tj '
        '(Certidao no 2026.0192837465 - Emitida em 12/11/2026) Tj ET',
        '<< /URI (https://servicos.pf.gov.br/epol-sinic-publico/validar-cac?numeroCertidao=2026.0192837465&codigo=PF26-8899-ABCD) >>',
      );

      final text = CriminalBackgroundService.extractReadableTextFromPdfOrBytes(pdfBytes);
      expect(text, contains('POLICIA FEDERAL'));
      expect(text, contains('2026.0192837465'));
      expect(text, contains('PF26-8899-ABCD'));

      final fields = CriminalBackgroundService.extractCertificateFieldsFromText(text);
      expect(fields.protocolNumber, equals('2026.0192837465'));
      expect(fields.issuedDate, equals(DateTime.utc(2026, 11, 12)));
      expect(fields.validationCode, equals('PF26-8899-ABCD'));
    });

    test('extrai protocolo, data e chave de autenticação via URL do QR Code PF (layout novo ePol-SINIC)', () {
      const qrUrl =
          'https://servicos.pf.gov.br/epol-sinic-publico/validar-cac?numeroCertidao=195290532026&dataEmissao=14/11/2026';

      final fields = CriminalBackgroundService.extractCertificateFieldsFromText(
        'A autenticidade desta certidão deverá ser confirmada na página da Polícia Federal.',
        qrPayload: qrUrl,
      );

      expect(fields.protocolNumber, equals('195290532026'));
      expect(fields.issuedDate, equals(DateTime.utc(2026, 11, 14)));
      // No layout novo ePol-SINIC, a chave de validação em validar-cac é o próprio número da certidão
      expect(fields.validationCode, equals('195290532026'));
      expect(fields.qrUrl, equals(qrUrl));
    });

    test('prioriza data de emissão sobre data de nascimento e suporta data por extenso', () {
      const text =
          'POLÍCIA FEDERAL - SINIC\n'
          'Certidão de Antecedentes Criminais nº 2026.4455667788\n'
          'WAGNER OLIVEIRA CLAUDIANO, nascido em 12/05/2001, CPF 119.787.236-10.\n'
          'Emitida às 09:45 do dia 10 de novembro de 2026.\n'
          'Código de controle: 99AA-88BB-77CC-66DD\n';

      final fields = CriminalBackgroundService.extractCertificateFieldsFromText(text);
      expect(fields.protocolNumber, equals('2026.4455667788'));
      expect(fields.issuedDate, equals(DateTime.utc(2026, 11, 10)));
      expect(fields.validationCode, equals('99AA-88BB-77CC-66DD'));
    });
  });

  group('2. UX Unificada CriminalBackgroundCheckStep (Sheet 3 Opções + Autopreenchimento + Remover)', () {
    final viewports = <({Size size, double scale, Brightness brightness, String label})>[
      (
        size: const Size(320, 640),
        scale: 1.5,
        brightness: Brightness.light,
        label: '320x640 @ 1.5x Light',
      ),
      (
        size: const Size(412, 915),
        scale: 1.0,
        brightness: Brightness.dark,
        label: '412x915 @ 1.0x Dark',
      ),
    ];

    for (final vp in viewports) {
      testWidgets(
        'abre AppSheet com 3 opções (Downloads/Galeria/Câmera), autopreenche, sobrescreve ao trocar e limpa ao Remover em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final refNow = DateTime.utc(2026, 11, 18, 12);
          final validatedHistory = <AuditedCriminalRecordResult?>[];

          final pdf1Bytes = _buildFlateToUnicodePfPdf(
            plainLine1: 'MINISTÉRIO DA JUSTIÇA - POLÍCIA FEDERAL - SINIC',
            plainLine2:
                'CERTIDÃO DE ANTECEDENTES CRIMINAIS nº 195290532026 - NÃO CONSTA condenação em nome de WAGNER OLIVEIRA CLAUDIANO, CPF 119.787.236-10.',
            plainLine3:
                'Emitida às 10:15 do dia 11/11/2026. Código de validação: AAA1.BBB2.CCC3.DDD4',
          );
          final photo2Bytes = _buildCrispPhotoCertificateBytes();

          await tester.pumpWidget(
            _buildTestApp(
              brightness: vp.brightness,
              textScale: vp.scale,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: CriminalBackgroundCheckStep(
                    expectedFullName: 'Wagner Oliveira Claudiano',
                    expectedCpfRaw: '119.787.236-10',
                    referenceNow: refNow,
                    customDownloadsPicker: () async => (
                      bytes: pdf1Bytes,
                      fileName: 'certidao_pf_downloads.pdf',
                    ),
                    customGalleryPicker: () async => (
                      bytes: photo2Bytes,
                      fileName: 'foto_certidao_galeria.png',
                    ),
                    customCameraPicker: () async => (
                      bytes: photo2Bytes,
                      fileName: 'foto_certidao_camera.png',
                    ),
                    customCertificateExtractor: ({required bytes, required fileName}) async {
                      if (fileName.endsWith('.pdf')) {
                        final text = CriminalBackgroundService
                            .extractReadableTextFromPdfOrBytes(bytes);
                        return CriminalCertificateExtractionResult(
                          extractedText: text,
                          fields: CriminalBackgroundService
                              .extractCertificateFieldsFromText(text),
                          source: 'pdf_text',
                        );
                      }
                      const ocrText =
                          'POLÍCIA FEDERAL - SINIC - CERTIDÃO DE ANTECEDENTES CRIMINAIS\n'
                          'NADA CONSTA em nome de WAGNER OLIVEIRA CLAUDIANO, CPF 119.787.236-10.\n'
                          'Certidão nº 2026.9988776655\n'
                          'Emitida em 16/11/2026\n'
                          'Código de validação: ZZZ9.YYY8.XXX7.WWW6';
                      return CriminalCertificateExtractionResult(
                        extractedText: ocrText,
                        fields: CriminalBackgroundService
                            .extractCertificateFieldsFromText(ocrText),
                        source: 'image_ocr',
                      );
                    },
                    onValidated: validatedHistory.add,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // 1. Garante que o botão separado antigo "Fotografar Certidão" NÃO existe mais na tela principal
          expect(
            find.byKey(const ValueKey('btn-camera-criminal-certificate')),
            findsNothing,
          );
          expect(find.text('Fotografar Certidão'), findsNothing);
          expect(
            find.byKey(const ValueKey('btn-upload-criminal-certificate')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('criminal-attached-file-card')),
            findsNothing,
          );

          // 2. Toca no botão único principal -> abre AppSheet com as 3 opções claras
          final uploadBtn = find.byKey(
            const ValueKey('btn-upload-criminal-certificate'),
          );
          await tester.ensureVisible(uploadBtn);
          await tester.tap(uploadBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.text('Como deseja enviar a Certidão PF?'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('sheet-pick-criminal-downloads')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('sheet-pick-criminal-gallery')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('sheet-pick-criminal-camera')),
            findsOneWidget,
          );
          expect(find.text('Recomendado'), findsOneWidget);

          // 3. Escolhe "Selecionar PDF ou Arquivo (Pasta Downloads)"
          final downloadsTile = find.byKey(
            const ValueKey('sheet-pick-criminal-downloads'),
          );
          await tester.ensureVisible(downloadsTile);
          await tester.pumpAndSettle();
          await tester.tap(downloadsTile);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Verifica cartão de anexo, botões >= 48x48 e autopreenchimento imediato
          expect(
            find.byKey(const ValueKey('criminal-attached-file-card')),
            findsOneWidget,
          );
          expect(find.text('certidao_pf_downloads.pdf'), findsOneWidget);
          expect(find.textContaining('PDF ·'), findsOneWidget);

          final removeBtnFinder = find.byKey(
            const ValueKey('btn-remove-criminal-certificate'),
          );
          final replaceBtnFinder = find.byKey(
            const ValueKey('btn-replace-criminal-certificate'),
          );
          expect(removeBtnFinder, findsOneWidget);
          expect(replaceBtnFinder, findsOneWidget);
          expect(tester.getSize(removeBtnFinder).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(replaceBtnFinder).height, greaterThanOrEqualTo(48));

          final protoField = tester.widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('input-criminal-protocol')),
              matching: find.byType(TextField),
            ),
          );
          final codeField = tester.widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('input-criminal-validation-code')),
              matching: find.byType(TextField),
            ),
          );
          expect(protoField.controller?.text, equals('195290532026'));
          expect(codeField.controller?.text, equals('AAA1.BBB2.CCC3.DDD4'));
          expect(find.text('11/11/2026'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('badge-autofill-protocol')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('badge-autofill-date')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('badge-autofill-validation-code')),
            findsOneWidget,
          );
          expect(validatedHistory.last, isNotNull);
          expect(validatedHistory.last!.passed, isTrue);

          // 4. Toca em "Trocar arquivo" -> escolhe Foto da Galeria -> SOBRESCREVE campos automaticamente!
          await tester.ensureVisible(replaceBtnFinder);
          await tester.tap(replaceBtnFinder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final galleryTile = find.byKey(
            const ValueKey('sheet-pick-criminal-gallery'),
          );
          await tester.ensureVisible(galleryTile);
          await tester.tap(galleryTile);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(find.text('foto_certidao_galeria.png'), findsOneWidget);
          expect(find.textContaining('PNG ·'), findsOneWidget);
          expect(protoField.controller?.text, equals('2026.9988776655'));
          expect(codeField.controller?.text, equals('ZZZ9.YYY8.XXX7.WWW6'));
          expect(find.text('16/11/2026'), findsOneWidget);
          expect(validatedHistory.last, isNotNull);
          expect(validatedHistory.last!.passed, isTrue);

          // 5. Toca em "Remover" -> limpa arquivo, zera campos, remove badges e chama onValidated(null)
          await tester.ensureVisible(removeBtnFinder);
          await tester.tap(removeBtnFinder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const ValueKey('criminal-attached-file-card')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('btn-upload-criminal-certificate')),
            findsOneWidget,
          );
          expect(protoField.controller?.text, isEmpty);
          expect(codeField.controller?.text, isEmpty);
          expect(
            find.byKey(const ValueKey('badge-autofill-protocol')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('badge-autofill-date')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('badge-autofill-validation-code')),
            findsNothing,
          );
          expect(validatedHistory.last, isNull);
          expect(find.textContaining('Certidão removida'), findsOneWidget);

          // 6. Garante zero jargão técnico proibido em toda a árvore visível
          for (final element in find.byType(Text).evaluate()) {
            final textWidget = element.widget as Text;
            final content =
                textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
            expect(
              KycHumanFeedbackTranslator.containsBannedTechnicalJargon(content),
              isFalse,
              reason: 'Jargão proibido encontrado: "$content"',
            );
          }
        },
      );
    }
  });
}
