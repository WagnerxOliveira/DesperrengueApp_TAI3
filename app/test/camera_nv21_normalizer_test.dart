import 'dart:typed_data';

import 'package:desperrengue_app/core/services/camera_nv21_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAndroidPlanesToNv21 — CameraX YUV_420_888 / Semi-planar / NV21', () {
    test('converte YUV_420_888 de 3 planos sem padding para NV21 exato (Y + VU intercalado)', () {
      const int w = 4;
      const int h = 4;
      final Uint8List y = Uint8List.fromList(List<int>.generate(16, (i) => 10 + i));
      final Uint8List u = Uint8List.fromList(<int>[100, 101, 102, 103]);
      final Uint8List v = Uint8List.fromList(<int>[200, 201, 202, 203]);

      final Uint8List? nv21 = normalizeAndroidPlanesToNv21(
        width: w,
        height: h,
        planes: <RawImagePlane>[
          RawImagePlane(bytes: y, bytesPerRow: 4, bytesPerPixel: 1),
          RawImagePlane(bytes: u, bytesPerRow: 2, bytesPerPixel: 1),
          RawImagePlane(bytes: v, bytesPerRow: 2, bytesPerPixel: 1),
        ],
      );

      expect(nv21, isNotNull);
      expect(nv21!.length, 24); // 4*4 + (4*4)/2
      expect(nv21.sublist(0, 16), orderedEquals(y));
      // NV21 intercala V primeiro, depois U: [V0, U0, V1, U1, V2, U2, V3, U3]
      expect(
        nv21.sublist(16),
        orderedEquals(<int>[200, 100, 201, 101, 202, 102, 203, 103]),
      );
    });

    test('converte YUV_420_888 de 3 planos com row-padding estilo Samsung (yRowStride > width, uvPixelStride = 2)', () {
      const int w = 4;
      const int h = 4;
      const int yStride = 8; // 4 pixels + 4 bytes de padding por linha (Samsung/Exynos)
      final Uint8List yPadded = Uint8List(yStride * h);
      for (int row = 0; row < h; row++) {
        for (int col = 0; col < w; col++) {
          yPadded[row * yStride + col] = (row + 1) * 10 + col;
        }
        // Preenche padding com lixo 0xFF que NÃO pode vazar para o NV21 final
        for (int pad = w; pad < yStride; pad++) {
          yPadded[row * yStride + pad] = 0xFF;
        }
      }

      // UV semi-intercalado com pixelStride = 2 e rowStride = 8
      const int uvStride = 8;
      final Uint8List uPadded = Uint8List(uvStride * 2)..fillRange(0, uvStride * 2, 0xEE);
      final Uint8List vPadded = Uint8List(uvStride * 2)..fillRange(0, uvStride * 2, 0xDD);
      // Row 0: (u=50,v=150), (u=51,v=151)
      uPadded[0] = 50;
      uPadded[2] = 51;
      vPadded[0] = 150;
      vPadded[2] = 151;
      // Row 1: (u=60,v=160), (u=61,v=161)
      uPadded[uvStride + 0] = 60;
      uPadded[uvStride + 2] = 61;
      vPadded[uvStride + 0] = 160;
      vPadded[uvStride + 2] = 161;

      final Uint8List? nv21 = normalizeAndroidPlanesToNv21(
        width: w,
        height: h,
        planes: <RawImagePlane>[
          RawImagePlane(bytes: yPadded, bytesPerRow: yStride, bytesPerPixel: 1),
          RawImagePlane(bytes: uPadded, bytesPerRow: uvStride, bytesPerPixel: 2),
          RawImagePlane(bytes: vPadded, bytesPerRow: uvStride, bytesPerPixel: 2),
        ],
      );

      expect(nv21, isNotNull);
      expect(nv21!.length, 24);
      expect(
        nv21.sublist(0, 16),
        orderedEquals(<int>[
          10, 11, 12, 13,
          20, 21, 22, 23,
          30, 31, 32, 33,
          40, 41, 42, 43,
        ]),
      );
      expect(
        nv21.sublist(16),
        orderedEquals(<int>[150, 50, 151, 51, 160, 60, 161, 61]),
      );
    });

    test('converte layout semi-planar de 2 planos (Y + VU) com padding de linha', () {
      const int w = 4;
      const int h = 4;
      final Uint8List y = Uint8List(6 * 4);
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          y[r * 6 + c] = r * 4 + c;
        }
      }
      final Uint8List vu = Uint8List.fromList(<int>[
        210, 110, 211, 111, 0xAA, 0xAA,
        212, 112, 213, 113, 0xBB, 0xBB,
      ]);

      final Uint8List? nv21 = normalizeAndroidPlanesToNv21(
        width: w,
        height: h,
        planes: <RawImagePlane>[
          RawImagePlane(bytes: y, bytesPerRow: 6, bytesPerPixel: 1),
          RawImagePlane(bytes: vu, bytesPerRow: 6, bytesPerPixel: 2),
        ],
      );

      expect(nv21, isNotNull);
      expect(nv21!.length, 24);
      expect(nv21.sublist(0, 16), orderedEquals(List<int>.generate(16, (i) => i)));
      expect(
        nv21.sublist(16),
        orderedEquals(<int>[210, 110, 211, 111, 212, 112, 213, 113]),
      );
    });

    test('aceita 1 plano NV21 limpo sem cópia extra e recorta trailing padding do ImageProxyUtils', () {
      const int w = 4;
      const int h = 4;
      final Uint8List exact = Uint8List.fromList(List<int>.generate(24, (i) => i + 1));

      final Uint8List? direct = normalizeAndroidPlanesToNv21(
        width: w,
        height: h,
        planes: <RawImagePlane>[
          RawImagePlane(bytes: exact, bytesPerRow: 4),
        ],
      );
      expect(direct, same(exact));

      // Simula bug do CameraX ImageProxyUtils que aloca trailing bytes extras no final
      final Uint8List oversized = Uint8List(40);
      oversized.setRange(0, 24, exact);
      final Uint8List? trimmed = normalizeAndroidPlanesToNv21(
        width: w,
        height: h,
        planes: <RawImagePlane>[
          RawImagePlane(bytes: oversized, bytesPerRow: 4),
        ],
      );
      expect(trimmed, isNotNull);
      expect(trimmed!.length, 24);
      expect(trimmed, orderedEquals(exact));
    });

    test('remove row-padding de 1 plano NV21 quando bytesPerRow > width', () {
      const int w = 4;
      const int h = 4;
      const int stride = 8;
      // 4 linhas Y * 8 bytes + 2 linhas VU * 8 bytes = 48 bytes
      final Uint8List padded = Uint8List(48)..fillRange(0, 48, 0xCC);
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          padded[r * stride + c] = 10 + r * 4 + c;
        }
      }
      // VU começa após stride * h = 32
      padded.setRange(32, 36, <int>[200, 100, 201, 101]);
      padded.setRange(40, 44, <int>[202, 102, 203, 103]);

      final Uint8List? nv21 = normalizeAndroidPlanesToNv21(
        width: w,
        height: h,
        planes: <RawImagePlane>[
          RawImagePlane(bytes: padded, bytesPerRow: stride),
        ],
      );

      expect(nv21, isNotNull);
      expect(nv21!.length, 24);
      expect(nv21.sublist(0, 16), orderedEquals(List<int>.generate(16, (i) => 10 + i)));
      expect(
        nv21.sublist(16),
        orderedEquals(<int>[200, 100, 201, 101, 202, 102, 203, 103]),
      );
    });

    test('retorna null para payload corrompido ou dimensões inválidas', () {
      expect(
        normalizeAndroidPlanesToNv21(
          width: 0,
          height: 4,
          planes: <RawImagePlane>[
            RawImagePlane(bytes: Uint8List(24), bytesPerRow: 4),
          ],
        ),
        isNull,
      );
      expect(
        normalizeAndroidPlanesToNv21(
          width: 4,
          height: 4,
          planes: const <RawImagePlane>[],
        ),
        isNull,
      );
      expect(
        normalizeAndroidPlanesToNv21(
          width: 4,
          height: 4,
          planes: <RawImagePlane>[
            RawImagePlane(bytes: Uint8List(10), bytesPerRow: 4),
          ],
        ),
        isNull,
      );
    });
  });
}
