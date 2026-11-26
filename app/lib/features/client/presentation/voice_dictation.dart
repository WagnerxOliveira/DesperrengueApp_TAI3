import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/speech_service.dart';
import '../../../core/services/text_refine_service.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/utils/smart_transcript_formatter.dart';
import '../../../core/utils/structured_voice_brief.dart';

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
  VoiceDictationController({required this.engine, required this.text, this.maxLength = 500, this.refiner}) {
    text.addListener(_onTextChanged);
  }

  /// Quantas amostras de volume o histórico guarda (alimenta a onda rolante do painel).
  static const int historyLength = 48;

  /// Histórico (0..1) do volume real do microfone, do mais antigo ao mais recente.
  final List<double> levelHistory = <double>[];

  final Stopwatch _clock = Stopwatch();

  /// Tempo de gravação da sessão corrente (zera a cada nova gravação).
  Duration get elapsed => _clock.elapsed;

  /// `true` enquanto o próprio controlador escreve no campo (não confundir com "apagou tudo").
  bool _writing = false;

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
  String? _rawPreStructured;
  String? _structuredVersion;
  bool _showingOriginal = false;
  int _refineToken = 0;

  /// `true` quando há versão estruturada e o cliente pode alternar para ver a fala original.
  bool get hasOriginalToggle =>
      _rawPreStructured != null &&
      _structuredVersion != null &&
      _rawPreStructured != _structuredVersion;

  bool get showingOriginal => _showingOriginal;

  /// Alterna entre a versão estruturada para o profissional e o texto original falado.
  void toggleOriginalVsStructured() {
    if (!hasOriginalToggle) return;
    _showingOriginal = !_showingOriginal;
    final selected = _showingOriginal ? _rawPreStructured! : _structuredVersion!;
    _lastSpoken = selected;
    _write(SmartTranscriptFormatter.append(_base, selected));
    _notify();
  }

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
    _rawPreStructured = null;
    _structuredVersion = null;
    _showingOriginal = false;
    _base = text.text;
    _lastRendered = text.text;
    _sessions.clear();
    levelHistory.clear();
    _clock
      ..reset()
      ..start();
    _wantListening = true;
    await _listen();
  }

  /// O cliente apagou o texto (botão "Apagar tudo" ou limpando o campo): esquece a versão
  /// estruturada, cancela a revisão em andamento e, se estiver gravando, para a captação —
  /// senão a próxima parcial do motor (cumulativa) traria o texto apagado de volta.
  void reset() {
    final hadState = _rawPreStructured != null ||
        _structuredVersion != null ||
        refining ||
        isListening ||
        _wantListening ||
        message != null ||
        _sessions.isNotEmpty;
    _refineToken++;
    refining = false;
    _rawPreStructured = null;
    _structuredVersion = null;
    _showingOriginal = false;
    _sessions.clear();
    _slotFinal = false;
    _lastSpoken = '';
    _base = '';
    _lastRendered = '';
    message = null;
    levelHistory.clear();
    level = 0;
    if (isListening || _wantListening) {
      _wantListening = false;
      unawaited(engine.stop().catchError((Object _) {}));
    }
    _clock.stop();
    state = VoiceState.idle;
    if (hadState) _notify();
  }

  void _onTextChanged() {
    if (_writing || _disposed) return;
    if (text.text.isEmpty) reset();
  }

  Future<void> _listen() async {
    _sessions.add(''); // nova sessão = novo slot
    _slotFinal = false;
    try {
      await engine.listen(onResult: _onResult, onLevel: _onLevel);
      state = VoiceState.listening;
    } catch (e) {
      _wantListening = false;
      _clock.stop();
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
    _clock.stop();
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
    level = l.clamp(0.0, 1.0);
    levelHistory.add(level);
    if (levelHistory.length > historyLength) {
      levelHistory.removeRange(0, levelHistory.length - historyLength);
    }
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
      _clock.stop();
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
    _writing = true;
    try {
      text.value = TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
    } finally {
      _writing = false;
    }
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
      if (StructuredVoiceBrief.tryParseStructuredText(refined) != null) {
        _rawPreStructured = spoken;
        _structuredVersion = refined;
        _showingOriginal = false;
      }
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
    text.removeListener(_onTextChanged);
    if (engine.isListening) {
      unawaited(engine.stop().catchError((Object _) {}));
    }
    super.dispose();
  }
}

/// Bloco "Falar o que aconteceu" (v2.38.0): cabeçalho + guia retrátil em 3 passos + microfone
/// tap-to-toggle com pulso e onda reagindo ao volume REAL + estados claros (ouvindo, organizando
/// com a IA, pronto, indisponível). Sem dependências novas: tudo em `CustomPainter` + tokens.
class VoiceDictationPanel extends StatefulWidget {
  const VoiceDictationPanel({
    super.key,
    required this.textController,
    this.maxLength = 500,
    this.engine,
    this.refiner,
    this.enableStructuredBrief = false,
    this.category,
    this.photoNotes = const [],
    this.onStructuredBriefReady,
    this.onChanged,
    this.onSpeechCompleted,
  });

  final TextEditingController textController;
  final int maxLength;

  /// Injetável nos testes (padrão: [PlatformSpeechEngine]).
  final SpeechEngine? engine;

  /// Injetável nos testes (padrão: [LanguageToolRefiner] ou [StructuredVoiceRefiner]).
  final TextRefiner? refiner;

  /// Quando `true` (e [refiner] não for sobrescrito), estrutura automaticamente o áudio
  /// via [StructuredVoiceRefiner] (IA gratuita + fallback local semântico).
  final bool enableStructuredBrief;
  final String? category;
  final List<String> photoNotes;
  final ValueChanged<StructuredVoiceBrief>? onStructuredBriefReady;

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
    refiner: widget.refiner ??
        (widget.enableStructuredBrief
            ? StructuredVoiceRefiner(
                categoryProvider: () => widget.category,
                photoNotesProvider: () => widget.photoNotes,
                maxLength: widget.maxLength,
                onBriefReady: widget.onStructuredBriefReady,
              )
            : LanguageToolRefiner()),
  );
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _wasListening = false;

  /// Guia "Como usar a voz": aberto na primeira vez; recolhe sozinho ao começar a gravar
  /// (divulgação progressiva) e o cliente pode reabrir quando quiser.
  late bool _showGuide = widget.textController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoice);
  }

  void _onVoice() {
    final nowListening = _voice.isListening;
    if (nowListening) {
      if (!_wasListening) _showGuide = false;
      if (!_anim.isAnimating && !AppMotion.reduced(context)) _anim.repeat();
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

  static String _clock(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final listening = _voice.isListening;
    final refining = _voice.refining;
    final accent = listening ? tk.danger : tk.accent;
    final accentInk = listening ? tk.dangerInk : tk.accentInk;
    return AppCard(
      variant: AppCardVariant.tonal,
      color: tk.accentSoft,
      borderColor: listening ? tk.danger.withValues(alpha: 0.6) : tk.accent.withValues(alpha: 0.32),
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(tk),
          const SizedBox(height: AppSpace.s12),
          _guide(tk),
          const SizedBox(height: AppSpace.s8),
          Center(child: _micButton(tk, listening: listening, refining: refining, accent: accent)),
          const SizedBox(height: AppSpace.s4),
          Center(child: _status(tk, listening: listening, refining: refining, accentInk: accentInk)),
          if (listening) ...[
            const SizedBox(height: AppSpace.s8),
            Center(child: _wave(accent)),
          ],
          if (_voice.hasOriginalToggle && !listening) ...[
            const SizedBox(height: AppSpace.s12),
            _doneStrip(tk),
          ],
          if (_voice.message != null) ...[
            const SizedBox(height: AppSpace.s12),
            _unavailable(tk),
          ],
        ],
      ),
    );
  }

  Widget _header(AppTokens tk) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tk.accent, Color.lerp(tk.accent, tk.accentInk, 0.5)!],
            ),
          ),
          child: Icon(Icons.record_voice_over_rounded, size: 24, color: AppTokens.onColor(tk.accent)),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Falar o que aconteceu', style: AppType.titleSm.copyWith(color: tk.text)),
              const SizedBox(height: AppSpace.s2),
              Text(
                'A IA organiza o seu relato para o profissional.',
                style: AppType.bodySm.copyWith(color: tk.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guide(AppTokens tk) {
    const steps = <(String, String)>[
      ('Toque no microfone', 'Se o celular pedir, autorize o uso do microfone.'),
      ('Fale normalmente', 'Conte o que aconteceu, onde fica e desde quando.'),
      ('Toque de novo para parar', 'A IA organiza o texto. Você pode editar ou apagar.'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        border: Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _showGuide,
            label: 'Como usar a voz',
            excludeSemantics: true,
            onTap: () => setState(() => _showGuide = !_showGuide),
            child: InkWell(
              key: const ValueKey('voice-guide-toggle'),
              borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
              onTap: () => setState(() => _showGuide = !_showGuide),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 20, color: tk.accentInk),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(child: Text('Como usar a voz', style: AppType.bodyStrong.copyWith(color: tk.text))),
                      AnimatedRotation(
                        turns: _showGuide ? 0.5 : 0,
                        duration: AppMotion.d(context, const Duration(milliseconds: 200)),
                        child: Icon(Icons.expand_more_rounded, size: 24, color: tk.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.d(context, const Duration(milliseconds: 220)),
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: _showGuide
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.s12, 0, AppSpace.s12, AppSpace.s12),
                    child: Column(
                      key: const ValueKey('voice-guide-steps'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpace.s12),
                          _GuideStep(number: i + 1, title: steps[i].$1, hint: steps[i].$2),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _micButton(AppTokens tk, {required bool listening, required bool refining, required Color accent}) {
    final ink = listening ? tk.dangerInk : tk.accentInk;
    final label = listening
        ? 'Parar gravação e organizar o texto'
        : (refining ? 'Organizando o relato com a IA' : 'Começar a falar');
    return Semantics(
      button: true,
      label: label,
      child: AppPressScale(
        child: GestureDetector(
          key: const ValueKey('voice-mic'),
          onTap: _voice.toggle,
          behavior: HitTestBehavior.opaque,
          child: RepaintBoundary(
            child: SizedBox(
              width: 128,
              height: 128,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, child) => CustomPaint(
                  painter: _PulsePainter(color: accent, t: _anim.value, active: listening, level: _voice.level),
                  child: child,
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, Color.lerp(accent, ink, 0.45)!],
                      ),
                      boxShadow: tk.isDark ? const [] : [BoxShadow(color: accent.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Icon(
                      listening ? Icons.stop_rounded : (refining ? Icons.auto_awesome_rounded : Icons.mic_rounded),
                      color: AppTokens.onColor(accent),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(AppTokens tk, {required bool listening, required bool refining, required Color accentInk}) {
    if (refining && !listening) {
      return Semantics(
        liveRegion: true,
        child: Row(
          key: const ValueKey('voice-refining'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSkeleton(width: 16, height: 16, circle: true),
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: Text(
                'A IA está organizando o seu relato…',
                textAlign: TextAlign.center,
                style: AppType.bodyStrong.copyWith(color: accentInk),
              ),
            ),
          ],
        ),
      );
    }
    if (!listening) {
      return Semantics(
        liveRegion: true,
        child: Text('Toque para falar', textAlign: TextAlign.center, style: AppType.bodyStrong.copyWith(color: accentInk)),
      );
    }
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _voice.state == VoiceState.starting ? 'Abrindo o microfone…' : 'Ouvindo… toque no botão para parar',
            textAlign: TextAlign.center,
            style: AppType.bodyStrong.copyWith(color: accentInk),
          ),
          const SizedBox(height: AppSpace.s8),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Container(
              key: const ValueKey('voice-timer'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
              decoration: BoxDecoration(
                color: tk.surface,
                borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                border: Border.all(color: tk.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: tk.danger, shape: BoxShape.circle)),
                  const SizedBox(width: AppSpace.s8),
                  Text(
                    'Gravando ${_clock(_voice.elapsed)}',
                    style: AppType.tabular(AppType.bodySm).copyWith(color: tk.dangerInk, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wave(Color color) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          key: const ValueKey('voice-wave'),
          width: 280,
          height: 44,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => CustomPaint(
              painter: _WavePainter(levels: List<double>.of(_voice.levelHistory), color: color, phase: _anim.value),
              size: const Size(280, 44),
            ),
          ),
        ),
      ),
    );
  }

  Widget _doneStrip(AppTokens tk) {
    final original = _voice.showingOriginal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        border: Border.all(color: tk.success.withValues(alpha: 0.45)),
      ),
      child: Wrap(
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(original ? Icons.mic_none_rounded : Icons.auto_awesome_rounded, size: 18, color: tk.successInk),
              const SizedBox(width: AppSpace.s8),
              Text(
                original ? 'Exibindo a fala original' : 'Relato organizado pela IA',
                style: AppType.bodySm.copyWith(color: tk.text, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          AppButton(
            key: const ValueKey('voice-toggle-structured'),
            label: original ? 'Usar versão organizada' : 'Ver fala original',
            variant: AppButtonVariant.tertiary,
            compact: true,
            expand: false,
            onPressed: _voice.toggleOriginalVsStructured,
          ),
        ],
      ),
    );
  }

  Widget _unavailable(AppTokens tk) {
    return Container(
      key: const ValueKey('voice-unavailable'),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: tk.dangerSoft,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        border: Border.all(color: tk.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mic_off_rounded, size: 20, color: tk.dangerInk),
          const SizedBox(width: AppSpace.s8),
          Expanded(child: Text(_voice.message!, style: AppType.bodySm.copyWith(color: tk.dangerInk))),
        ],
      ),
    );
  }
}

/// Um passo numerado do guia ("1 · Toque no microfone").
class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.title, required this.hint});

  final int number;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      container: true,
      label: 'Passo $number: $title. $hint',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tk.accent, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: AppType.tabular(AppType.bodySm).copyWith(color: AppTokens.onColor(tk.accent), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.bodyStrong.copyWith(color: tk.text)),
                const SizedBox(height: AppSpace.s2),
                Text(hint, style: AppType.bodySm.copyWith(color: tk.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Halo do microfone: anéis em repouso + ondas concêntricas e brilho que reagem ao volume.
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.color, required this.t, required this.active, required this.level});

  final Color color;
  final double t;
  final bool active;
  final double level;

  static const double _buttonRadius = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    // Halos suaves em repouso: convidam ao toque sem animar.
    canvas.drawCircle(c, _buttonRadius + 14, Paint()..color = color.withValues(alpha: active ? 0.10 : 0.12));
    canvas.drawCircle(c, _buttonRadius + 7, Paint()..color = color.withValues(alpha: active ? 0.16 : 0.18));
    if (!active) return;
    // Brilho proporcional ao volume real.
    canvas.drawCircle(c, _buttonRadius + 6 + 14 * level, Paint()..color = color.withValues(alpha: 0.12 + 0.18 * level));
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = _buttonRadius + (maxR - _buttonRadius) * p * (0.7 + 0.3 * level);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: (1 - p) * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t || old.active != active || old.level != level || old.color != color;
}

/// Onda rolante: cada barra é uma amostra do volume real do microfone (mais recente à direita).
class _WavePainter extends CustomPainter {
  _WavePainter({required this.levels, required this.color, required this.phase});

  final List<double> levels;
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 3.5;
    final n = (size.width / (barW + gap)).floor();
    final midY = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    for (var i = 0; i < n; i++) {
      final idx = levels.length - n + i;
      final v = (idx >= 0 && idx < levels.length) ? levels[idx] : 0.0;
      // "Respiração" mínima: a onda nunca parece congelada, mas só o volume real a faz crescer.
      final breathe = 0.07 + 0.04 * math.sin(phase * 2 * math.pi + i * 0.55);
      final amp = math.max(math.pow(v, 0.7).toDouble(), breathe);
      final h = 4 + (size.height - 4) * amp;
      final x = i * (barW + gap) + barW / 2;
      paint.color = color.withValues(alpha: 0.35 + 0.65 * (i / math.max(1, n - 1)));
      canvas.drawLine(Offset(x, midY - h / 2), Offset(x, midY + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}