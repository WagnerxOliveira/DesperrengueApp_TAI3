/// Linha de texto reconhecida pelo OCR com sua geometria espacial 2D na imagem.
///
/// Preservar o retângulo delimitador (`boundingBox`) permite parear campos
/// tabulares lado a lado (como `CPF` e `DATA NASCIMENTO` na CNH Clássica ou
/// `3 DATA, LOCAL E UF DE NASCIMENTO` na CNH 2022 Padrão Viena) com precisão
/// geométrica, sem perder o vínculo quando o OCR lineariza o texto em string.
class OcrTextLineBox {
  const OcrTextLineBox({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.imageWidth = 1000.0,
    this.imageHeight = 1000.0,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double imageWidth;
  final double imageHeight;

  double get width => (right - left).abs();
  double get height => (bottom - top).abs();
  double get centerX => (left + right) * 0.5;
  double get centerY => (top + bottom) * 0.5;

  /// Coordenadas normalizadas no intervalo `[0.0 .. 1.0]` independentes da resolução.
  double get normLeft => imageWidth > 0 ? left / imageWidth : left;
  double get normTop => imageHeight > 0 ? top / imageHeight : top;
  double get normRight => imageWidth > 0 ? right / imageWidth : right;
  double get normBottom => imageHeight > 0 ? bottom / imageHeight : bottom;
  double get normCenterX => imageWidth > 0 ? centerX / imageWidth : centerX;
  double get normCenterY => imageHeight > 0 ? centerY / imageHeight : centerY;
  double get normHeight => imageHeight > 0 ? height / imageHeight : height;
  double get normWidth => imageWidth > 0 ? width / imageWidth : width;
}
