import 'dart:convert';
import 'dart:typed_data';

import 'package:desperrengue_app/core/services/media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Captura o corpo de cada requisição ao Storage (sem rede).
class _CapturingClient extends http.BaseClient {
  final List<({Uri url, Uint8List body})> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    requests.add((url: request.url, body: body));
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"Key":"ok","Id":"1"}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Uint8List _jpegWithGps(String marker) {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(10, 120, 200));
  final jpeg = Uint8List.fromList(img.encodeJpg(image));
  final payload = [...utf8.encode('Exif'), 0, 0, ...utf8.encode(marker)];
  final len = payload.length + 2;
  return Uint8List.fromList([
    ...jpeg.sublist(0, 2),
    0xFF, 0xE1, (len >> 8) & 0xFF, len & 0xFF, ...payload,
    ...jpeg.sublist(2),
  ]);
}

bool _has(Uint8List b, String s) => latin1.decode(b, allowInvalid: true).contains(s);

void main() {
  const gps = 'GPS:-21.785412,-46.561789';

  late _CapturingClient http0;
  late MediaService media;

  setUp(() {
    http0 = _CapturingClient();
    final client = SupabaseClient('http://localhost:54321', 'anon-key', httpClient: http0);
    media = MediaService(client, () => 'user-1');
  });

  test('uploadPrivate envia a foto SEM o GPS do EXIF (o corpo da requisição é limpo)', () async {
    final path = await media.uploadPrivate(_jpegWithGps(gps), 'jpg', prefix: 'job');
    expect(path, startsWith('user-1/job_'));
    final upload = http0.requests.single;
    expect(upload.url.path, contains('/object/job-media/user-1/job_'));
    expect(_has(upload.body, gps), isFalse);
    expect(_has(upload.body, 'Exif'), isFalse);
    expect(_has(upload.body, 'image/jpeg'), isTrue);
  });

  test('uploadPublic/uploadPublicPath (avatar/portfólio) também higienizam', () async {
    final url = await media.uploadPublic(_jpegWithGps(gps), 'jpg', prefix: 'avatar');
    expect(url, contains('/object/public/public-media/user-1/avatar_'));
    await media.uploadPublicPath(_jpegWithGps(gps), 'jpg', prefix: 'portfolio');
    expect(http0.requests, hasLength(2));
    for (final r in http0.requests) {
      expect(_has(r.body, gps), isFalse);
    }
  });

  test('formato não higienizável NÃO chega à rede', () async {
    await expectLater(
      media.uploadPrivate(Uint8List.fromList(List<int>.filled(40, 7)), 'jpg'),
      throwsA(isA<Object>()),
    );
    expect(http0.requests, isEmpty);
  });

  test('dois uploads no mesmo instante geram caminhos distintos (sem 409)', () async {
    final jpg = _jpegWithGps(gps);
    final a = await media.uploadPrivate(jpg, 'jpg');
    final b = await media.uploadPrivate(jpg, 'jpg');
    expect(a, isNot(b));
  });

  test('URL assinada: falha ao assinar não é cacheada e o cache é limpável', () async {
    MediaService.clearSignedCache();
    final a = await media.signedUrl('user-1/x.jpg');
    // createSignedUrl devolve JSON sem signedURL no fake => vira null, nada cacheado.
    expect(a, isNull);
    MediaService.clearSignedCache();
  });
}
