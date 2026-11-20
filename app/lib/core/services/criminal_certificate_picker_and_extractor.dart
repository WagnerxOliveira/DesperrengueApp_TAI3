import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'criminal_background_service.dart';
import 'criminal_certificate_picker_stub.dart'
    if (dart.library.io) 'criminal_certificate_picker_mobile.dart' as platform;

/// Resultado completo da extração híbrida (PDF textual, PDF escaneado via PdfRenderer + ML Kit,
/// foto via ML Kit Text + QR Code e fallback opcional `kyc-argon-vision-gate`).
class CriminalCertificateExtractionResult {
  const CriminalCertificateExtractionResult({
    required this.extractedText,
    required this.fields,
    this.qrPayload,
    this.source = 'local',
    this.cloudVerdictPassed,
    this.cloudFeedbackMessage,
  });

  final String extractedText;
  final ExtractedCriminalCertificateFields fields;
  final String? qrPayload;
  final String source;
  final bool? cloudVerdictPassed;
  final String? cloudFeedbackMessage;
}

/// Seletor unificado + extrator híbrido de Certidões de Antecedentes Criminais
/// da Polícia Federal (Android SAF Pasta Downloads, FilePicker, Galeria, Câmera,
/// PDF nativo/escaneado, ML Kit OCR/QR e fallback `kyc-argon-vision-gate`).
class CriminalCertificatePickerAndExtractor {
  const CriminalCertificatePickerAndExtractor._();

  static const String documentPickerChannelName =
      'br.com.desperrengue.app/document_picker';

  static const List<String> allowedExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  /// Seleciona PDF ou imagem da Certidão PF abrindo a pasta `Downloads` no Android
  /// via SAF nativo (`br.com.desperrengue.app/document_picker`) com fallback automático
  /// para `FilePicker` em iOS/Web/Desktop ou se o channel nativo não estiver registrado.
  static Future<({Uint8List bytes, String fileName})?> pickFromDownloadsOrFiles() async {
    if (platform.isAndroidNativePickerSupported) {
      try {
        // Retorna null quando o usuário cancelou explicitamente no SAF nativo
        return await platform.pickDocumentInDownloadsNative();
      } on PlatformException catch (e) {
        if (e.code == 'ERR_FILE_TOO_LARGE' ||
            e.code == 'ERR_PICKER_ALREADY_ACTIVE') {
          rethrow;
        }
        // Fallback automático para FilePicker se o seletor nativo não estiver disponível
      } on MissingPluginException {
        // Fallback automático para FilePicker
      }
    }

    final picked = await FilePicker.pickFile(
      dialogTitle: 'Selecionar Certidão da Polícia Federal',
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;
    final cleanName = picked.name.trim();
    return (
      bytes: bytes,
      fileName: cleanName.isNotEmpty ? cleanName : 'certidao_pf.pdf',
    );
  }

  /// Seleciona uma foto da certidão a partir da galeria do aparelho.
  static Future<({Uint8List bytes, String fileName})?> pickFromGallery() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    if (bytes.isEmpty) return null;
    return (
      bytes: bytes,
      fileName: xfile.name.trim().isNotEmpty ? xfile.name.trim() : 'certidao_pf.jpg',
    );
  }

  /// Fotografa a certidão impressa utilizando a câmera do aparelho.
  static Future<({Uint8List bytes, String fileName})?> captureWithCamera() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    if (bytes.isEmpty) return null;
    return (
      bytes: bytes,
      fileName: xfile.name.trim().isNotEmpty
          ? xfile.name.trim()
          : 'certidao_pf_foto.jpg',
    );
  }

  /// Extrai texto estruturado, QR Code oficial da PF e campos (Protocolo, Data de Emissão
  /// e Código de Validação Eletrônica) a partir dos bytes de PDF ou imagem.
  static Future<CriminalCertificateExtractionResult> extractTextAndQrFromCertificateBytes({
    required Uint8List bytes,
    required String fileName,
    String? expectedFullName,
    String? expectedCpfRaw,
    bool allowCloudFallback = true,
  }) async {
    if (bytes.isEmpty) {
      return const CriminalCertificateExtractionResult(
        extractedText: '',
        fields: ExtractedCriminalCertificateFields(),
      );
    }

    final ext = CriminalBackgroundService.detectCanonicalExtension(bytes, fileName);
    String combinedText = '';
    String? qrPayload;
    String source = 'local';

    if (ext == 'pdf') {
      final pdfText = CriminalBackgroundService.extractReadableTextFromPdfOrBytes(
        bytes,
      );
      combinedText = pdfText;
      source = 'pdf_text';

      final initialFields = CriminalBackgroundService.extractCertificateFieldsFromText(
        pdfText,
      );

      // Se o PDF for escaneado (texto vazio ou muito curto < 40 chars), renderiza
      // a página 0 em PNG via PdfRenderer nativo Android e roda ML Kit OCR + QR Code.
      if (pdfText.trim().length < 40 || !initialFields.hasAnyField) {
        final pngBytes = await platform.renderPdfFirstPagePngNative(bytes);
        if (pngBytes != null && pngBytes.isNotEmpty) {
          final ocrRes = await platform.recognizeTextAndQrFromImageBytesNative(
            pngBytes,
            extension: 'png',
          );
          if (ocrRes.text.isNotEmpty) {
            combinedText = combinedText.isEmpty
                ? ocrRes.text
                : '$combinedText\n${ocrRes.text}';
            source = 'pdf_ocr';
          }
          if (ocrRes.qrPayload != null && ocrRes.qrPayload!.isNotEmpty) {
            qrPayload = ocrRes.qrPayload;
            source = 'pdf_ocr';
          }
        }
      }
    } else {
      final ocrRes = await platform.recognizeTextAndQrFromImageBytesNative(
        bytes,
        extension: ext,
      );
      combinedText = ocrRes.text;
      qrPayload = ocrRes.qrPayload;
      if (combinedText.isNotEmpty || (qrPayload != null && qrPayload.isNotEmpty)) {
        source = 'image_ocr';
      }
    }

    var fields = CriminalBackgroundService.extractCertificateFieldsFromText(
      combinedText,
      qrPayload: qrPayload,
    );
    bool? cloudPassed;
    String? cloudFeedback;

    // Fallback inteligente via Edge Function `kyc-argon-vision-gate` quando ainda faltar
    // texto estrutural (ex.: foto na Web ou foto difícil) e o Supabase estiver autenticado.
    final needsCloudEnrichment = allowCloudFallback &&
        (combinedText.trim().length < 40 ||
            fields.protocolNumber == null ||
            fields.issuedDate == null ||
            fields.validationCode == null);

    if (needsCloudEnrichment) {
      final cloud = await _tryCloudVisionFallback(
        bytes: bytes,
        extension: ext,
        extractedText: combinedText,
        expectedFullName: expectedFullName,
        expectedCpfRaw: expectedCpfRaw,
      );
      if (cloud != null) {
        fields = fields.mergeWith(cloud.fields);
        if (cloud.syntheticText.isNotEmpty && combinedText.trim().length < 40) {
          combinedText = cloud.syntheticText;
          source = 'cloud_vision';
        }
        cloudPassed = cloud.passed;
        cloudFeedback = cloud.feedback;
      }
    }

    return CriminalCertificateExtractionResult(
      extractedText: combinedText,
      fields: fields,
      qrPayload: qrPayload ?? fields.qrUrl,
      source: source,
      cloudVerdictPassed: cloudPassed,
      cloudFeedbackMessage: cloudFeedback,
    );
  }

  static Future<
    ({
      ExtractedCriminalCertificateFields fields,
      String syntheticText,
      bool? passed,
      String? feedback,
    })?
  > _tryCloudVisionFallback({
    required Uint8List bytes,
    required String extension,
    required String extractedText,
    String? expectedFullName,
    String? expectedCpfRaw,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return null;
      final name = (expectedFullName ?? '').trim();
      final cpf = (expectedCpfRaw ?? '').trim();
      if (name.isEmpty || cpf.isEmpty) return null;
      // Evita payload excessivo na Edge Function
      if (bytes.length > 8 * 1024 * 1024) return null;

      final mimeType = switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      final response = await client.functions.invoke(
        'kyc-argon-vision-gate',
        body: <String, dynamic>{
          'mode': 'criminal_record',
          'certificateBase64': base64Encode(bytes),
          'mimeType': mimeType,
          'typedFullName': name,
          'typedCpf': cpf,
          if (extractedText.trim().isNotEmpty) 'extractedText': extractedText.trim(),
        },
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic>? data = rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : null);
      if (data == null) return null;

      final rawProtocol =
          (data['certificate_protocol'] ?? data['certificate_protocol_masked'])
              ?.toString()
              .trim();
      final protocol = (rawProtocol != null &&
              rawProtocol.isNotEmpty &&
              !rawProtocol.contains('*'))
          ? rawProtocol
          : null;

      final rawCode = data['validation_code']?.toString().trim();
      final valCode = (rawCode != null && rawCode.isNotEmpty) ? rawCode : protocol;

      final rawDateIso = data['certificate_issued_date_iso']?.toString().trim();
      DateTime? issuedDate;
      if (rawDateIso != null && rawDateIso.isNotEmpty) {
        final parsed = DateTime.tryParse(rawDateIso);
        if (parsed != null) {
          issuedDate = DateTime.utc(parsed.year, parsed.month, parsed.day);
        }
      }

      final passed = data['passed'] is bool ? data['passed'] as bool : null;
      final feedback = data['user_friendly_feedback']?.toString().trim();

      final cloudFields = ExtractedCriminalCertificateFields(
        protocolNumber: protocol,
        issuedDate: issuedDate,
        validationCode: valCode,
      );

      return (
        fields: cloudFields,
        syntheticText: '',
        passed: passed,
        feedback: (feedback != null && feedback.isNotEmpty) ? feedback : null,
      );
    } catch (_) {
      return null;
    }
  }
}
