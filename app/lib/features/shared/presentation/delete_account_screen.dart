import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/account_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../provider/presentation/pix_withdraw_screen.dart';

typedef DeletionStatusLoader = Future<DeletionStatus> Function(DeletionScope scope);
typedef AccountDeleter = Future<DeletionResult> Function(DeletionScope scope);
typedef DeletionProfileLoader = Future<UserProfile?> Function();
typedef AfterDeletion = Future<void> Function(BuildContext context, DeletionResult result, UserMode deletedFrom);

/// Excluir conta (LGPD, art. 18, VI) com **guardrail financeiro** e **escopo por perfil**.
///
///  * Quem tem só um perfil: exclui a conta inteira (sem escolha).
///  * Quem é Cliente E Profissional escolhe: só o perfil em que está agora (o outro e o login
///    continuam) ou as DUAS contas de uma vez.
///  * Saldo > 0 → NÃO exclui: BottomSheet pedindo o Pix para conta própria.
///  * Valores em custódia / serviço em andamento NO ESCOPO escolhido → NÃO exclui.
///  * Liberado → Edge Function `excluir-conta`: envia o Dossiê de Despedida (PDF só do que está
///    sendo excluído) por e-mail e SÓ DEPOIS apaga os dados.
/// O servidor repete a checagem (a tela é só experiência; a regra é do banco).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    this.asProvider = false,
    this.statusLoader,
    this.deleter,
    this.profileLoader,
    this.afterDeletion,
    this.email,
  });

  /// Perfil em que o usuário está agora (define o que "só esta conta" significa).
  final bool asProvider;

  /// Injetáveis nos testes (padrão: serviços reais).
  final DeletionStatusLoader? statusLoader;
  final AccountDeleter? deleter;
  final DeletionProfileLoader? profileLoader;
  final AfterDeletion? afterDeletion;
  final String? email;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _providers = ProviderService();
  final _confirm = TextEditingController();
  bool _busy = false;

  /// null = ainda carregando / desconhecido.
  bool? _both;

  /// Só vale quando [_both] é true; padrão = o perfil atual (a escolha mais segura).
  bool _deleteBoth = false;

  UserMode get _current => widget.asProvider ? UserMode.provider : UserMode.client;
  String get _currentName => widget.asProvider ? 'Profissional' : 'Cliente';
  String get _otherName => widget.asProvider ? 'Cliente' : 'Profissional';

  String get _email {
    if (widget.email != null) return widget.email!;
    try {
      return Supabase.instance.client.auth.currentUser?.email ?? 'seu e-mail';
    } catch (_) {
      return 'seu e-mail';
    }
  }

  bool get _typed => _confirm.text.trim().toUpperCase() == 'EXCLUIR';

  /// Escopo efetivo. Sem perfil carregado (ou com um só perfil) usamos `all`: é sempre válido.
  DeletionScope get _scope {
    if (_both != true || _deleteBoth) return DeletionScope.all;
    return widget.asProvider ? DeletionScope.provider : DeletionScope.client;
  }

  bool get _partial => _scope != DeletionScope.all;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await (widget.profileLoader ?? ProfileService().fetchCurrent)();
      if (!mounted) return;
      setState(() => _both = p?.hasBothModes ?? false);
    } catch (_) {
      if (mounted) setState(() => _both = false);
    }
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      final scope = _scope;
      final status = await (widget.statusLoader ?? (s) => _providers.deletionStatus(scope: s))(scope);
      if (!mounted) return;
      if (status.hasBalance) {
        await _showPixSheet(status);
        return;
      }
      if (status.hasOngoing) {
        await _showOngoingSheet(status);
        return;
      }
      await _runOffboarding(scope);
    } on DeletionBlocked {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Há saldo, valores em custódia ou serviço em andamento. Verifique e tente de novo.',
          kind: AppSnackKind.error,
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runOffboarding(DeletionScope scope) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final msg = scope == DeletionScope.all
        ? 'Gerando seu Dossiê de Despedida e excluindo seus dados...'
        : 'Gerando o Dossiê da conta de $_currentName e excluindo os dados...';
    AppDialog.show<void>(
      context,
      title: 'Processando exclusão',
      barrierDismissible: false,
      content: PopScope(
        canPop: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: AppLoading(message: msg),
        ),
      ),
    );
    final DeletionResult result;
    try {
      result = await (widget.deleter ?? (s) => _providers.deleteAccount(scope: s))(scope);
    } catch (e) {
      navigator.pop(); // fecha o diálogo de progresso
      rethrow;
    }
    if (mounted) navigator.pop(); // fecha o diálogo de progresso
    if (!mounted) return;
    await (widget.afterDeletion ?? _defaultAfterDeletion)(context, result, _current);
  }

  /// Conta inteira removida → limpa o aparelho e volta ao Login.
  /// Só um perfil removido → a conta segue: reabre direto no perfil que sobrou.
  Future<void> _defaultAfterDeletion(BuildContext context, DeletionResult result, UserMode deletedFrom) async {
    final navigator = Navigator.of(context);
    if (result.accountRemoved) {
      await LocalPrefs.remove(LocalPrefs.keyLastProfile);
      try {
        await ProfileService().signOut();
      } catch (_) {/* sessão já invalidada no servidor */}
      AppSession.instance.reset();
      if (context.mounted) {
        AppSnackbar.show(
          context,
          '${result.scope == DeletionScope.all && _both == true ? 'Contas excluídas' : 'Conta excluída'}. Enviamos o Dossiê de Despedida para $_email.',
          kind: AppSnackKind.info,
          duration: const Duration(seconds: 8),
        );
      }
    } else {
      final remaining = result.scope == DeletionScope.client ? UserMode.provider : UserMode.client;
      final removedName = result.scope == DeletionScope.client ? 'Cliente' : 'Profissional';
      AppSession.instance.choose(remaining);
      AppSession.instance.refreshProfile();
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Conta de $removedName excluída. Enviamos o Dossiê dessa conta para $_email.',
          kind: AppSnackKind.info,
          duration: const Duration(seconds: 8),
        );
      }
    }
    navigator.pushAndRemoveUntil(AppRoute(builder: (_) => const AuthGate()), (_) => false);
  }

  Future<void> _showPixSheet(DeletionStatus s) {
    return AppSheet.show<void>(
      context,
      builder: (sheet) => _BlockSheet(
        icon: Icons.warning_amber_rounded,
        title: 'Você possui fundos retidos',
        message: 'Transfira seu dinheiro para uma conta bancária externa de sua titularidade via Pix antes de excluir sua conta.\n\nSaldo disponível: ${brl(s.available)}.',
        actionLabel: 'Transferir via Pix',
        actionIcon: Icons.pix_rounded,
        onAction: () async {
          Navigator.pop(sheet);
          final done = await Navigator.of(context).push<bool>(AppRoute(builder: (_) => PixWithdrawScreen(available: s.available)));
          if (done == true && mounted) {
            AppSnackbar.show(context, 'Saldo transferido. Agora você já pode excluir a conta.', kind: AppSnackKind.success);
          }
        },
      ),
    );
  }

  Future<void> _showOngoingSheet(DeletionStatus s) {
    final parts = <String>[
      if (s.activeJobs > 0) '${s.activeJobs} serviço(s) em andamento',
      if (s.held > 0) '${brl(s.held)} em custódia',
    ];
    return AppSheet.show<void>(
      context,
      builder: (sheet) => _BlockSheet(
        icon: Icons.hourglass_top_rounded,
        title: 'Ainda há pendências',
        message: 'Para proteger você e a outra parte, só é possível excluir ${_partial ? 'a conta de $_currentName' : 'a conta'} depois de concluir ou cancelar tudo: ${parts.isEmpty ? 'serviços e valores em aberto' : parts.join(' e ')}.',
        actionLabel: 'Entendi',
        onAction: () => Navigator.pop(sheet),
      ),
    );
  }

  String get _buttonLabel {
    if (_both != true) return 'Excluir minha conta';
    return _deleteBoth ? 'Excluir as duas contas' : 'Excluir conta de $_currentName';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final both = _both == true;
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Excluir conta'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
        children: [
          const InfoBanner('Esta ação é permanente e não pode ser desfeita.', tone: BannerTone.danger, icon: Icons.delete_forever_rounded),
          if (both) ...[
            const SizedBox(height: AppSpace.section),
            AppSection(
              title: 'O que você quer excluir?',
              child: Column(
                children: [
                  _ScopeCard(
                    key: const Key('scope-current'),
                    selected: !_deleteBoth,
                    icon: widget.asProvider ? Icons.handyman_rounded : Icons.person_rounded,
                    title: 'Só minha conta de $_currentName',
                    subtitle: 'Seu perfil de $_otherName e seu login continuam funcionando normalmente.',
                    onTap: () => setState(() => _deleteBoth = false),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  _ScopeCard(
                    key: const Key('scope-all'),
                    selected: _deleteBoth,
                    icon: Icons.group_remove_rounded,
                    title: 'As duas contas (Cliente e Profissional)',
                    subtitle: 'Apaga tudo de uma vez e encerra seu acesso ao Desperrengue.',
                    onTap: () => setState(() => _deleteBoth = true),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'O que acontece',
            child: Column(
              children: [
                _Bullet(
                  Icons.mail_outline_rounded,
                  !both
                      ? 'Você recebe o Dossiê de Despedida (PDF) em $_email, com seu histórico, total gasto, total economizado e total de lucro.'
                      : _deleteBoth
                          ? 'Você recebe em $_email o Dossiê de Despedida (PDF) com as informações das DUAS contas excluídas: histórico, total gasto, economizado e lucro.'
                          : 'Você recebe em $_email o Dossiê (PDF) só da conta de $_currentName, com histórico, total gasto, economizado e lucro dela.',
                ),
                _Bullet(
                  Icons.delete_sweep_rounded,
                  !both || _deleteBoth
                      ? 'Excluímos seu perfil, documentos, fotos, mensagens e endereços.'
                      : widget.asProvider
                          ? 'Excluímos seu perfil profissional: especialidades, vitrine, documentos de verificação e dados de atendimento.'
                          : 'Excluímos seu perfil de cliente: pedidos, endereço de atendimento e carteira.',
                ),
                if (both && !_deleteBoth)
                  _Bullet(Icons.verified_user_outlined, 'Sua conta de $_otherName permanece intacta e você continua entrando com o mesmo e-mail e senha.'),
                const _Bullet(Icons.gavel_rounded, 'Mantemos só os registros financeiros exigidos por lei, sem nome nem vínculo com você.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Text('Para confirmar, digite EXCLUIR', style: AppType.bodyStrong.copyWith(color: tk.text)),
          const SizedBox(height: AppSpace.s8),
          AppTextField(
            controller: _confirm,
            hint: 'EXCLUIR',
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: _buttonLabel,
          icon: Icons.delete_forever_rounded,
          variant: AppButtonVariant.destructive,
          loading: _busy,
          onPressed: (_typed && !_busy) ? _delete : null,
        ),
      ),
    );
  }
}

/// Opção selecionável (estilo "radio card"): área de toque grande e estado óbvio.
class _ScopeCard extends StatelessWidget {
  const _ScopeCard({super.key, required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap});

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final borderColor = selected ? tk.danger : tk.border;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        child: AnimatedContainer(
          duration: AppMotion.d(context, AppMotion.fade),
          padding: const EdgeInsets.all(AppSpace.s16),
          decoration: BoxDecoration(
            color: selected ? tk.dangerSoft : tk.card,
            borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 26, color: selected ? tk.dangerInk : tk.textMuted),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppType.bodyStrong.copyWith(color: tk.text)),
                const SizedBox(height: AppSpace.s4),
                Text(subtitle, style: AppType.bodySm.copyWith(color: tk.textMuted)),
              ]),
            ),
            const SizedBox(width: AppSpace.s8),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? tk.dangerInk : tk.textMuted),
          ]),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: tk.textMuted),
        const SizedBox(width: AppSpace.s12),
        Expanded(child: Text(text, style: AppType.body.copyWith(color: tk.text))),
      ]),
    );
  }
}

class _BlockSheet extends StatelessWidget {
  const _BlockSheet({required this.icon, required this.title, required this.message, required this.actionLabel, required this.onAction, this.actionIcon});

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 44, color: tk.warningInk),
      const SizedBox(height: AppSpace.s12),
      Text(title, textAlign: TextAlign.center, style: AppType.title.copyWith(color: tk.text)),
      const SizedBox(height: AppSpace.s8),
      Text(message, textAlign: TextAlign.center, style: AppType.body.copyWith(color: tk.textMuted)),
      const SizedBox(height: AppSpace.s20),
      AppButton(label: actionLabel, icon: actionIcon, onPressed: onAction),
    ]);
  }
}
