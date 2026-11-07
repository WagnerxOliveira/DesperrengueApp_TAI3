import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/speech_service.dart';
import '../../../core/services/text_refine_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/smart_transcript_formatter.dart';

enum VoiceState { idle, starting, listening, unavailable }

/// Cérebro do ditado por voz (sem widgets): **tap-to-toggle**, relato estruturado e SEM duplicar.
///
/// Um toque inicia a captação; outro encerra. Enquanto ouve, o motor pode "fechar" a sessão
/// sozinho em pausas longas — o app reabre até o cliente tocar de novo.
///
/// **Por que o texto duplicava**: os motores de voz (Android/Web) entregam o MESMO trecho várias
/// vezes — parciais crescentes, o resultado final e, às vezes, de novo ao parar/reabrir. Antes cada
/// resultado final virava um segmento novo ("Preciso de um eletricista. Preciso de um eletricista.").
/// Agora cada sessão de escuta ocupa UM "slot" que é SUBSTITUÍDO a cada resultado (parcial ou final),
/// e na montagem final trechos repetidos/cumulativos entre sessões são fundidos.
class VoiceDictationController extends ChangeNotifier {
  VoiceDictationController({required this.engine, required this.text, this.maxLength = 500, this.refiner});

  final SpeechEngine engine;

  /// Campo "O que precisa ser feito?".
  final TextEditingController text;
  final int maxLength;

  /// Revisão final opcional (acentos/maiúsculas/pontuação), depois de parar a gravação.
  final TextRefiner? refiner;

  VoiceState state = VoiceState.idle;
  double level = 0;
  String? message;

  /// `true` enquanto o texto está sendo aperfeiçoado pelo revisor (rede).
  bool refining = false;

  bool _initialized = false;
  bool _wantListening = false;
  bool _restarting = false;
  bool _disposed = false;
  String _base = '';
  String _lastRendered = '';
  String _lastSpoken = '';
  int _refineToken = 0;

  /// O slot corrente já recebeu um resultado FINAL (o trecho está "fechado").
  bool _slotFinal = false;

  /// Um slot por sessão de escuta; o último é o da sessão corrente.
  final List<String> _sessions = [];

  bool get isListening => state == VoiceState.listening || state == VoiceState.starting;

  /// O gesto único do botão do microfone.
  Future<void> toggle() => isListening ? stop() : start();

  Future<void> start() async {
    if (isListening) return;
    message = null;
    state = VoiceState.starting;
    notifyListeners();
    if (!_initialized) {
      _initialized = await engine.initialize(onStatus: _onStatus, onError: _onError);
    }
    if (!_initialized) {
      state = VoiceState.unavailable;
      message = 'Não foi possível usar o microfone. Verifique a permissão do navegador/app e tente de novo — ou digite o relato.';
      notifyListeners();
      return;
    }
    _refineToken++; // invalida qualquer revisão em andamento
    refining = false;
    _base = text.text;
    _lastRendered = text.text;
    _sessions.clear();
    _wantListening = true;
    await _listen();
  }

  Future<void> _listen() async {
    _sessions.add(''); // nova sessão = novo slot
    _slotFinal = false;
    try {
      await engine.listen(onResult: _onResult, onLevel: _onLevel);
      state = VoiceState.listening;
    } catch (e) {
      _wantListening = false;
      state = VoiceState.unavailable;
      message = 'Não foi possível iniciar a gravação. Tente novamente ou digite o relato.';
    }
    _notify();
  }

  Future<void> stop() async {
    if (!isListening && !_wantListening) return;
    _wantListening = false;
    try {
      await engine.stop();
    } catch (_) {}
    level = 0;
    state = VoiceState.idle;
    _render();
    _notify();
    unawaited(_refine());
  }

  void _onResult(String words, bool isFinal) {
    final w = words.trim();
    if (w.isEmpty || _sessions.isEmpty) return;
    // Resultado atrasado depois de parar: só vale se o cliente ainda não mexeu no texto.
    if (!_wantListening && text.text != _lastRendered) return;
    final cur = _sessions.last;
    if (cur.isNotEmpty && _slotFinal) {
      // O trecho já está fechado. Só repetição/pedaço tardio do mesmo trecho NÃO soma e NÃO encolhe;
      // uma fala realmente nova (motores contínuos) abre um slot novo.
      final kc = _key(cur);
      final kw = _key(w);
      if (kc.contains(kw)) return;
      if (!kw.contains(kc)) {
        _sessions.add(w);
        _slotFinal = isFinal;
        _render();
        return;
      }
    }
    _sessions[_sessions.length - 1] = w; // SUBSTITUI o slot (parcial → final nunca soma)
    _slotFinal = isFinal;
    _render();
  }

  void _onLevel(double l) {
    level = l;
    _notify();
  }

  void _onStatus(String status) {
    // O motor encerrou a sessão (pausa longa) mas o cliente ainda não tocou em parar.
    if ((status == 'done' || status == 'notListening') && _wantListening && !_restarting) {
      _restarting = true;
      Future<void>.delayed(const Duration(milliseconds: 200), () async {
        _restarting = false;
        if (_wantListening && !_disposed) await _listen();
      });
    }
  }

  void _onError(String error) {
    // Silêncio/sem fala não é erro para o usuário: o auto-reinício cuida. Erros reais encerram.
    if (error == 'error_no_match' || error == 'error_speech_timeout' || error == 'no-speech') return;
    if (_wantListening) {
      _wantListening = false;
      state = VoiceState.unavailable;
      message = 'O reconhecimento de voz parou ($error). O que foi captado já está no texto.';
      _render();
      _notify();
    }
  }

  // ------------------------------------------------------------------- montagem

  /// Funde as sessões: repetidas somem; uma sessão que é continuação (cumulativa) da anterior a substitui.
  @visibleForTesting
  static List<String> mergeSessions(Iterable<String> sessions) {
    final out = <String>[];
    for (final raw in sessions) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      if (out.isEmpty) {
        out.add(s);
        continue;
      }
      final prev = _key(out.last);
      final cur = _key(s);
      if (cur == prev || prev.contains(cur)) continue; // repetição / pedaço do que já temos
      if (cur.contains(prev)) {
        out[out.length - 1] = s; // a nova sessão já traz a anterior inteira
        continue;
      }
      out.add(s);
    }
    return out;
  }

  /// Chave de comparação: minúsculas, sem pontuação, espaços colapsados.
  static String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Escreve no campo o texto digitado antes + o relato falado, já estruturado.
  void _render() {
    _lastSpoken = SmartTranscriptFormatter.format('', segments: mergeSessions(_sessions));
    _write(SmartTranscriptFormatter.append(_base, _lastSpoken));
  }

  void _write(String value) {
    var out = value;
    if (out.length > maxLength) out = out.substring(0, maxLength);
    _lastRendered = out;
    text.value = TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }

  /// Revisão final (acentos, maiúsculas, pontuação) sem sobrescrever o que o cliente editou.
  Future<void> _refine() async {
    final r = refiner;
    final spoken = _lastSpoken;
    if (r == null || spoken.trim().length < 8) return;
    final token = ++_refineToken;
    refining = true;
    _notify();
    String refined;
    try {
      refined = await r.refine(spoken);
    } catch (_) {
      refined = spoken;
    }
    if (_disposed || token != _refineToken) return;
    refining = false;
    final untouched = text.text == _lastRendered; // o cliente não mexeu enquanto revisávamos
    if (untouched && refined.trim().isNotEmpty && refined != spoken) {
      _lastSpoken = refined;
      _write(SmartTranscriptFormatter.append(_base, refined));
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wantListening = false;
    if (engine.isListening) {
      unawaited(engine.stop().catchError((Object _) {}));
    }
    super.dispose();
  }
}

/// Bloco "Falar o que aconteceu": tutorial curto + microfone tap-to-toggle + ondas sonoras.
class VoiceDictationPanel extends StatefulWidget {
  const VoiceDictationPanel({
    super.key,
    required this.textController,
    this.maxLength = 500,
    this.engine,
    this.refiner,
    this.onChanged,
    this.onSpeechCompleted,
  });

  final TextEditingController textController;
  final int maxLength;

  /// Injetável nos testes (padrão: [PlatformSpeechEngine]).
  final SpeechEngine? engine;

  /// Injetável nos testes (padrão: [LanguageToolRefiner]).
  final TextRefiner? refiner;

  /// Avisa o formulário quando o texto muda por voz (para revalidar o botão "Avançar").
  final VoidCallback? onChanged;

  /// Disparado quando a gravação de voz encerra com texto válido (para acionar triagem IA).
  final VoidCallback? onSpeechCompleted;

  @override
  State<VoiceDictationPanel> createState() => _VoiceDictationPanelState();
}

class _VoiceDictationPanelState extends State<VoiceDictationPanel> with SingleTickerProviderStateMixin {
  late final VoiceDictationController _voice = VoiceDictationController(
    engine: widget.engine ?? PlatformSpeechEngine(),
    text: widget.textController,
    maxLength: widget.maxLength,
    refiner: widget.refiner ?? LanguageToolRefiner(),
  );
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _wasListening = false;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoice);
  }

  void _onVoice() {
    final nowListening = _voice.isListening;
    if (nowListening) {
      if (!_anim.isAnimating && !MediaQuery.disableAnimationsOf(context)) _anim.repeat();
    } else {
      _anim.stop();
      _anim.value = 0;
      if (_wasListening && widget.textController.text.trim().isNotEmpty) {
        widget.onSpeechCompleted?.call();
      }
    }
    _wasListening = nowListening;
    widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoice);
    _voice.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final listening = _voice.isListening;
    final accent = listening ? tk.danger : tk.clientAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tk.clientSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: listening ? 0.7 : 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(color: tk.text, fontSize: 13, height: 1.45),
              children: const [
                TextSpan(text: '🎙️ '),
                TextSpan(text: 'Como usar a voz: ', style: TextStyle(fontWeight: FontWeight.w900)),
                TextSpan(text: '1. Toque no microfone e solte'),
                TextSpan(text: ' • ', style: TextStyle(fontWeight: FontWeight.w900)),
                TextSpan(text: '2. Fale normalmente explicando o problema'),
                TextSpan(text: ' • ', style: TextStyle(fontWeight: FontWeight.w900)),
                TextSpan(text: '3. Toque novamente para parar e gerar o texto organizado.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Semantics(
              button: true,
              label: listening ? 'Parar gravação e organizar o texto' : 'Começar a falar',
              child: GestureDetector(
                key: const ValueKey('voice-mic'),
                onTap: _voice.toggle,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => CustomPaint(
                      painter: _RipplePainter(color: accent, t: _anim.value, active: listening, level: _voice.level),
                      child: Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, color: AppTokens.onColor(accent), size: 34),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (listening) Center(child: SoundWaveBars(animation: _anim, level: _voice.level, color: accent)),
          const SizedBox(height: 6),
          Center(
            child: _voice.refining
                ? Row(
                    key: const ValueKey('voice-refining'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
                      const SizedBox(width: 8),
                      Text('Aperfeiçoando o texto…', style: TextStyle(fontWeight: FontWeight.w800, color: accent)),
                    ],
                  )
                : Text(
                    listening ? 'Ouvindo… toque no botão para parar' : 'Toque para falar',
                    style: TextStyle(fontWeight: FontWeight.w800, color: accent),
                  ),
          ),
          if (_voice.message != null) ...[
            const SizedBox(height: 8),
            Text(_voice.message!, style: TextStyle(color: tk.danger, fontSize: 12.5, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

/// Ondas concêntricas ao redor do microfone enquanto ouve.
class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.color, required this.t, required this.active, required this.level});

  final Color color;
  final double t;
  final bool active;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = 34 + (maxR - 34) * p * (0.75 + 0.25 * level);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: (1 - p) * 0.55);
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t || old.active != active || old.level != level;
}

/// Barras de áudio (equalizador) que reagem ao nível do microfone.
class SoundWaveBars extends StatelessWidget {
  const SoundWaveBars({super.key, required this.animation, required this.level, required this.color, this.bars = 21});

  final Animation<double> animation;
  final double level;
  final Color color;
  final int bars;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = animation.value * 2 * math.pi;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < bars; i++)
              Container(
                key: i == 0 ? const ValueKey('voice-wave') : null,
                width: 4,
                height: 6 + 26 * (0.25 + 0.75 * level) * (math.sin(phase * 1.0 + i * 0.55).abs()),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(2)),
              ),
          ],
        );
      },
    );
  }
}
