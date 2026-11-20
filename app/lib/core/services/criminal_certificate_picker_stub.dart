import 'dart:typed_data';

const bool isAndroidNativePickerSupported = false;

Future<({Uint8List bytes, String fileName})?> pickDocumentInDownloadsNative() async {
  return null;
}

Future<Uint8List?> renderPdfFirstPagePngNative(
  Uint8List pdfBytes, {
  int targetWidth = 1600,
}) async {
  return null;
}

Future<({String text, String? qrPayload})> recognizeTextAndQrFromImageBytesNative(
  Uint8List imageBytes, {
  String extension = 'jpg',
}) async {
  return (text: '', qrPayload: null);
}
