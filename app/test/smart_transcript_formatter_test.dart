import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/utils/smart_transcript_formatter.dart';

String f(String raw, {List<String>? segments}) => SmartTranscriptFormatter.format(raw, segments: segments);

void main() {
  group('SmartTranscriptFormatter — sem duplicar (bug do microfone no Android)', () {
    test('o relato duplicado do cliente vira UMA frase', () {
      expect(
        f('Preciso de um eletricista para consertar um disjuntor. Preciso de um eletricista para consertar um disjuntor.'),
        'Preciso de um eletricista para consertar um disjuntor.',
      );
    });

    test('duplicado sem pontuação nem maiúsculas (como o reconhecedor entrega)', () {
      expect(
        f('preciso de um eletricista para consertar um disjuntor preciso de um eletricista para consertar um disjuntor'),
        'Preciso de um eletricista para consertar um disjuntor.',
      );
    });

    test('segmentos repetidos (parcial + final) colapsam', () {
      expect(f('', segments: ['a torneira vaza', 'a torneira vaza']), 'A torneira vaza.');
      expect(f('', segments: ['preciso de um eletricista para consertar um disjuntor', 'Preciso de um eletricista para consertar um disjuntor.']), 'Preciso de um eletricista para consertar um disjuntor.');
    });

    test('frases diferentes se mantêm; só a repetição imediata some', () {
      expect(
        f('a torneira vaza. a torneira vaza. a pia está entupida.'),
        'A torneira vaza. A pia está entupida.',
      );
      // Repetição NÃO adjacente pode ser intencional (ênfase): fica.
      expect(f('a torneira vaza. a pia está entupida. a torneira vaza.'), 'A torneira vaza. A pia está entupida. A torneira vaza.');
    });

    test('repetir palavras curtas (2 ou menos) é fala natural e não é cortado', () {
      expect(f('muito muito calor'), 'Muito muito calor.');
    });
  });

  group('SmartTranscriptFormatter — português falado vira escrito', () {
    test('"pra" → "para", "tá" → "está", "vc" → "você"', () {
      expect(f('preciso trocar pra amanhã'), 'Preciso trocar para amanhã.');
      expect(f('a luz tá piscando'), 'A luz está piscando.');
      expect(f('vc consegue vir hoje'), 'Você consegue vir hoje?');
    });

    test('saudação e agradecimento ganham pontuação própria', () {
      expect(f('olá preciso de um encanador'), 'Olá, preciso de um encanador.');
      expect(f('preciso trocar um chuveiro queimado obrigado'), 'Preciso trocar um chuveiro queimado. Obrigado.');
      expect(f('preciso de ajuda obrigado'), 'Preciso de ajuda obrigado.', reason: 'relato curto demais para separar');
    });

    test('"por favor" e "por exemplo" ficam entre vírgulas', () {
      expect(f('preciso de um orçamento por favor'), contains(', por favor'));
    });
  });

  group('SmartTranscriptFormatter', () {
    test('vazio e só espaço devolvem vazio', () {
      expect(f(''), '');
      expect(f('   \n  '), '');
    });

    test('capitaliza o início e fecha com ponto final', () {
      expect(f('o chuveiro parou de esquentar'), 'O chuveiro parou de esquentar.');
    });

    test('vírgula antes de conjunções adversativas/explicativas', () {
      expect(
        f('o disjuntor desarma toda hora mas já troquei o chuveiro'),
        'O disjuntor desarma toda hora, mas já troquei o chuveiro.',
      );
      expect(
        f('preciso de ajuda hoje porque a água não sai'),
        'Preciso de ajuda hoje, porque a água não sai.',
      );
    });

    test('não duplica vírgula já existente', () {
      expect(f('o disjuntor desarma, mas ninguém resolve'), 'O disjuntor desarma, mas ninguém resolve.');
    });

    test('perguntas ganham ponto de interrogação', () {
      expect(f('vocês conseguem vir amanhã'), 'Vocês conseguem vir amanhã?');
      expect(f('quanto custa a visita'), 'Quanto custa a visita?');
      expect(f('tem como trocar hoje'), 'Tem como trocar hoje?');
      expect(f('dá pra consertar sem quebrar a parede'), 'Dá para consertar sem quebrar a parede?');
      expect(f('fica pronto hoje né'), 'Fica pronto hoje né?');
    });

    test('afirmações NÃO viram pergunta', () {
      expect(f('a pia está vazando muito'), 'A pia está vazando muito.');
    });

    test('vários períodos: respeita pontuação existente e capitaliza cada um', () {
      expect(
        f('a torneira vaza. já tentei fechar o registro! não adiantou'),
        'A torneira vaza. Já tentei fechar o registro! Não adiantou.',
      );
    });

    test('comandos falados de pontuação', () {
      expect(f('a pia entupiu vírgula e a água não desce ponto final'), 'A pia entupiu, e a água não desce.');
      expect(f('vocês atendem sábado ponto de interrogação'), 'Vocês atendem sábado?');
      expect(f('socorro ponto de exclamação'), 'Socorro!');
    });

    test('remove hesitações e palavras repetidas por gagueira', () {
      expect(f('ééé o o chuveiro hum parou'), 'O chuveiro parou.');
      expect(f('ahn a a tomada está solta'), 'A tomada está solta.');
    });

    test('preserva decimais', () {
      expect(f('preciso de uma prateleira de 2.5 metros'), 'Preciso de uma prateleira de 2.5 metros.');
    });

    test('segmentos por pausa: curto vira vírgula, período cheio vira ponto', () {
      expect(
        f('', segments: ['o chuveiro queimou', 'e preciso trocar hoje']),
        'O chuveiro queimou, e preciso trocar hoje.',
      );
      expect(
        f('', segments: ['o chuveiro queimou de vez ontem à noite', 'preciso trocar hoje']),
        'O chuveiro queimou de vez ontem à noite. Preciso trocar hoje.',
      );
    });

    test('texto longo sem pontuação é quebrado em marcadores de discurso', () {
      final out = f(
        'minha casa é antiga e a fiação já deu problema outras vezes aí hoje o chuveiro começou a desarmar o disjuntor toda vez que ligo',
      );
      expect(out.split('.').where((s) => s.trim().isNotEmpty).length, greaterThanOrEqualTo(2));
      expect(out, startsWith('Minha casa'));
      expect(out, contains('Aí hoje'));
      expect(out.endsWith('.'), isTrue);
    });

    test('é idempotente para texto já organizado', () {
      const ok = 'O disjuntor desarma, mas ninguém resolve. Vocês conseguem vir amanhã?';
      expect(f(ok), ok);
    });

    test('append junta ao texto digitado sem duplicar pontuação', () {
      expect(SmartTranscriptFormatter.append('', 'Olá.'), 'Olá.');
      expect(SmartTranscriptFormatter.append('Já digitei isto.', 'Falei isto.'), 'Já digitei isto. Falei isto.');
      expect(SmartTranscriptFormatter.append('Sem ponto', 'Falei isto.'), 'Sem ponto. Falei isto.');
      expect(SmartTranscriptFormatter.append('Texto', ''), 'Texto');
    });
  });
}
