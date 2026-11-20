import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/provider_dossier_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/draft_store.dart';
import '../../../core/services/legal_mandate_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/profile_photo_viewer.dart';
import '../../shared/presentation/review_widgets.dart';
import 'dossie_servico_profissional_screen.dart';
import 'provider_portfolio_widgets.dart';

/// Editar Perfil (protótipo P02): foto, título, bio, especialidades, preços.
/// Em [setupMode] vira o 1º passo do cadastro inicial (botão "Continuar").
class EditProviderProfileScreen extends StatefulWidget {
  const EditProviderProfileScreen({
    super.key,
    this.setupMode = false,
    this.onDone,
    @visibleForTesting this.customPhotoPicker,
    @visibleForTesting this.customAvatarUploader,
    @visibleForTesting this.initialProfileOverride,
    @visibleForTesting this.initialProviderRowOverride,
  });

  final bool setupMode;
  final VoidCallback? onDone;
  final StagedPhotoPicker? customPhotoPicker;
  final AvatarBinaryUploader? customAvatarUploader;
  final UserProfile? initialProfileOverride;
  final Map<String, dynamic>? initialProviderRowOverride;

  @override
  State<EditProviderProfileScreen> createState() => _EditProviderProfileScreenState();
}

class _EditProviderProfileScreenState extends State<EditProviderProfileScreen> {
  ProfileService get _profiles => ProfileService();
  ProviderService get _providers => ProviderService();
  final _bio = TextEditingController();
  final _headline = TextEditingController();
  final _city = TextEditingController();
  final _hourly = TextEditingController();
  final _visit = TextEditingController(text: '30');
  final _specialties = <String>{};
  double _radius = 15;
  String? _avatarUrl;
  String _name = '';
  bool _loading = true;
  bool _saving = false;
  Timer? _saveTimer;
  String? _draftKey;

  bool get _hasPhoto => _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.setupMode) {
      _draftKey = DraftStore.keyFor('provider_setup');
      for (final c in [_bio, _headline, _hourly, _visit]) {
        c.addListener(_scheduleDraft);
      }
    }
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _bio.dispose();
    _headline.dispose();
    _city.dispose();
    _hourly.dispose();
    _visit.dispose();
    super.dispose();
  }

  void _scheduleDraft() {
    if (_draftKey == null || _loading) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () => DraftStore.write(_draftKey!, {
          'bio': _bio.text,
          'headline': _headline.text,
          'hourly': _hourly.text,
          'visit': _visit.text,
          'specialties': _specialties.toList(),
          'radius': _radius,
        }));
  }

  /// No cadastro inicial, reaplica o que o usuário já tinha digitado antes de sair.
  Future<void> _applyDraft() async {
    final key = _draftKey;
    if (key == null) return;
    final d = await DraftStore.read(key);
    if (d == null || !mounted) return;
    setState(() {
      String s(String k) => (d[k] as String?) ?? '';
      if (s('bio').isNotEmpty) _bio.text = s('bio');
      if (s('headline').isNotEmpty) _headline.text = s('headline');
      if (s('hourly').isNotEmpty) _hourly.text = s('hourly');
      if (s('visit').isNotEmpty) _visit.text = s('visit');
      final sp = (d['specialties'] as List?)?.cast<String>() ?? const <String>[];
      if (sp.isNotEmpty) {
        _specialties
          ..clear()
          ..addAll(sp);
      }
      final r = (d['radius'] as num?)?.toDouble();
      if (r != null) _radius = r.clamp(1, 100);
    });
  }

  Future<void> _load() async {
    try {
      final UserProfile? p;
      final Map<String, dynamic>? row;
      if (widget.initialProfileOverride != null || widget.initialProviderRowOverride != null) {
        p = widget.initialProfileOverride;
        row = widget.initialProviderRowOverride;
      } else {
        p = await _profiles.fetchCurrent();
        row = await _providers.myProviderRow();
      }
      if (!mounted) return;
      setState(() {
        _name = p?.fullName ?? '';
        _avatarUrl = p?.avatarUrl;
        _bio.text = p?.bio ?? '';
        _city.text = p?.addressCity ?? '';
        _headline.text = (row?['headline'] as String?) ?? '';
        _specialties.addAll(((row?['specialties'] as List?) ?? const []).cast<String>());
        final h = (row?['hourly_rate'] as num?)?.toDouble();
        if (h != null) _hourly.text = h.toStringAsFixed(h % 1 == 0 ? 0 : 2).replaceAll('.', ',');
        final v = (row?['visit_fee'] as num?)?.toDouble();
        if (v != null) _visit.text = v.toStringAsFixed(v % 1 == 0 ? 0 : 2).replaceAll('.', ',');
        _radius = ((row?['service_radius_km'] as num?)?.toDouble() ?? 15).clamp(1, 100);
        _loading = false;
      });
      await _applyDraft();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        if (widget.customPhotoPicker == null && widget.customAvatarUploader == null) {
          AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
        }
      }
    }
  }

  Future<void> _changePhoto() async {
    try {
      final url = await pickPreviewAndSaveAvatar(
        context,
        userName: _name.isEmpty ? 'Profissional' : _name,
        currentUrl: _avatarUrl,
        customPicker: widget.customPhotoPicker,
        customUploader: widget.customAvatarUploader,
      );
      if (url != null && mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  Future<void> _save() async {
    if (_specialties.isEmpty) {
      AppSnackbar.show(context, 'Escolha ao menos uma especialidade.', kind: AppSnackKind.error);
      return;
    }
    if (_bio.text.trim().length < 20) {
      AppSnackbar.show(context, 'Conte um pouco sobre você (mín. 20 caracteres).', kind: AppSnackKind.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _profiles.updateProfile({
        'bio': _bio.text.trim(),
        if (_city.text.trim().isNotEmpty) 'address_city': _city.text.trim(),
      });
      unawaited(
        LegalMandateService.recordAcceptanceIfAuthenticated(
          roleScope: 'PROVIDER',
        ),
      );
      await _providers.saveProviderProfile(
        headline: _headline.text.trim().isEmpty ? _specialties.first : _headline.text.trim(),
        specialties: _specialties.toList(),
        hourlyRate: parseBrl(_hourly.text),
        visitFee: parseBrl(_visit.text) ?? 30,
        radiusKm: _radius.round(),
      );
      AppSession.instance.refreshProfile();
      _saveTimer?.cancel();
      if (_draftKey != null) await DraftStore.clear(_draftKey!);
      if (!mounted) return;
      if (widget.setupMode) {
        widget.onDone?.call();
      } else {
        AppSnackbar.show(context, 'Perfil atualizado!', kind: AppSnackKind.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: AppAppBar(
        title: widget.setupMode ? 'Seu perfil profissional' : 'Editar perfil',
        automaticallyImplyLeading: !widget.setupMode,
      ),
      body: AppSkeletonSwitcher(
        loading: _loading,
        skeleton: const AppSkeletonList(count: 5),
        child: ListView(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
          children: [
            if (widget.setupMode) ...[
              const AppStepper(total: 3, current: 1),
              const SizedBox(height: AppSpace.s16),
              Text('Mostre quem você é', style: AppType.display.copyWith(color: tk.text)),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Clientes escolhem quem tem foto, boa descrição e especialidades claras.',
                style: AppType.body.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s20),
            ],
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _changePhoto,
                    child: Stack(
                      children: [
                        AppAvatar(url: _avatarUrl, name: _name.isEmpty ? '?' : _name, radius: 62),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: tk.accent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _changePhoto,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpace.s12),
                                child: Icon(Icons.photo_camera_rounded, color: tk.onAccent, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  AppButton(
                    key: const Key('edit-provider-change-photo-btn'),
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    expand: false,
                    onPressed: _changePhoto,
                    icon: _hasPhoto ? Icons.photo_camera_rounded : Icons.add_a_photo_rounded,
                    label: _hasPhoto ? 'Alterar foto' : 'Adicionar foto',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s24),
            Text('Título profissional', style: AppType.titleSm.copyWith(color: tk.text)),
            const SizedBox(height: AppSpace.s8),
            AppTextField(
              controller: _headline,
              maxLength: 60,
              hint: 'Ex: Eletricista residencial',
            ),
            const SizedBox(height: AppSpace.s16),
            Text('Cidade principal de atendimento', style: AppType.titleSm.copyWith(color: tk.text)),
            const SizedBox(height: AppSpace.s8),
            TextField(
              key: const ValueKey('provider-base-city-input'),
              controller: _city,
              maxLength: 80,
              decoration: const InputDecoration(
                hintText: 'Ex: Poços de Caldas - MG',
                prefixIcon: Icon(Icons.location_city_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final suggestedCity in const <String>[
                  'Poços de Caldas - MG',
                  'Pouso Alegre - MG',
                  'Varginha - MG',
                ])
                  ActionChip(
                    label: Text(
                      suggestedCity,
                      style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: tk.text),
                    ),
                    onPressed: () {
                      setState(() => _city.text = suggestedCity);
                      _scheduleDraft();
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            Text('Sobre mim', style: AppType.titleSm.copyWith(color: tk.text)),
            const SizedBox(height: AppSpace.s8),
            AppTextField(
              controller: _bio,
              maxLines: 5,
              maxLength: 500,
              hint: 'Descreva sua experiência em até 500 caracteres...',
            ),
            const SizedBox(height: AppSpace.s12),
            Text('Minhas especialidades', style: AppType.titleSm.copyWith(color: tk.text)),
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final c in kCategories)
                  FilterChip(
                    avatar: Icon(
                      _specialties.contains(c.name) ? Icons.check_rounded : Icons.add_rounded,
                      size: 16,
                      color: _specialties.contains(c.name) ? tk.onAccent : tk.accentInk,
                    ),
                    label: Text(c.name),
                    selected: _specialties.contains(c.name),
                    showCheckmark: false,
                    selectedColor: tk.accent,
                    labelStyle: AppType.bodySm.copyWith(
                      color: _specialties.contains(c.name) ? tk.onAccent : tk.text,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (v) {
                      setState(() => v ? _specialties.add(c.name) : _specialties.remove(c.name));
                      _scheduleDraft();
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s20),
            LayoutBuilder(
              builder: (context, constraints) {
                final visitField = TextField(
                  controller: _visit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Taxa de visita (R\$)', prefixText: 'R\$ '),
                );
                final hourlyField = TextField(
                  controller: _hourly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor/hora (opcional)', prefixText: 'R\$ '),
                );
                if (context.layout.isLargeText || constraints.maxWidth < 320) {
                  return Column(
                    children: [
                      visitField,
                      const SizedBox(height: AppSpace.s12),
                      hourlyField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: visitField),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(child: hourlyField),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpace.s16),
            Text(
              'Raio de atendimento: ${_radius.round()} km',
              style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
            ),
            Slider(
              value: _radius,
              min: 1,
              max: 100,
              divisions: 99,
              label: '${_radius.round()} km',
              onChanged: (v) {
                setState(() => _radius = v);
                _scheduleDraft();
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: widget.setupMode ? 'Continuar' : 'Salvar alterações',
          trailingArrow: widget.setupMode,
          loading: _saving,
          onPressed: _loading ? null : _save,
        ),
      ),
    );
  }
}

/// Meu Portfólio (protótipo P03): fotos públicas dos trabalhos.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, this.setupMode = false, this.onDone});

  final bool setupMode;
  final VoidCallback? onDone;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _providers = ProviderService();
  late Future<List<PortfolioItem>> _future = _loadSafe();
  bool _uploading = false;

  Future<List<PortfolioItem>> _loadSafe() async {
    try {
      return await _providers.portfolio(_providers.uid);
    } catch (_) {
      return const <PortfolioItem>[];
    }
  }

  void _reload() => setState(() {
        _future = _loadSafe();
      });

  Future<void> _add() async {
    final img = await pickImage(context);
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      final path = await MediaService().uploadPublicPath(img.bytes, img.ext, prefix: 'portfolio');
      await _providers.addPortfolio(path);
      _reload();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(PortfolioItem item) async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Excluir foto?',
      message: 'Ela deixará de aparecer no seu perfil.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _providers.deletePortfolio(item.id);
      _reload();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: AppAppBar(title: 'Meu Portfólio', automaticallyImplyLeading: !widget.setupMode),
      body: FutureBuilder<List<PortfolioItem>>(
        future: _future,
        builder: (context, snap) {
          final items = snap.data ?? const [];
          return ListView(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
            children: [
              if (widget.setupMode) ...[
                const AppStepper(total: 3, current: 2),
                const SizedBox(height: AppSpace.s16),
              ],
              const ProviderSmartPortfolioSection(isOwner: true),
              const SizedBox(height: AppSpace.section),
              AppSection(
                title: 'Galeria de Fotos Complementares',
                subtitle: 'Mostre a qualidade do seu trabalho para atrair mais clientes.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpace.s12,
                      crossAxisSpacing: AppSpace.s12,
                      children: [
                        AppPressable(
                          onTap: _uploading ? null : _add,
                          borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                          child: Container(
                            decoration: BoxDecoration(
                              color: tk.surface,
                              borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                              border: Border.all(color: tk.border, width: 1.5),
                            ),
                            child: Center(
                              child: _uploading
                                  ? const AppLoading()
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined, size: 36, color: tk.accentInk),
                                        const SizedBox(height: AppSpace.s8),
                                        Text('Adicionar', style: AppType.bodyStrong.copyWith(color: tk.accentInk)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        for (var idx = 0; idx < items.length; idx++)
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              AppPressable(
                                borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                                onTap: () => PortfolioFullScreenPhotoViewer.open(
                                  context,
                                  photos: items.map((e) => e.imagePath).toList(),
                                  initialIndex: idx,
                                  serviceTitle: items[idx].caption ?? 'Galeria do Meu Portfólio',
                                  usePublicBucket: true,
                                ),
                                child: PublicImage(path: items[idx].imagePath, radius: AppGeometry.itemRadius),
                              ),
                              Positioned(
                                right: AppSpace.s4,
                                top: AppSpace.s4,
                                child: Material(
                                  color: tk.card,
                                  shape: const CircleBorder(),
                                  child: AppIconButton(
                                    tooltip: 'Excluir foto',
                                    icon: Icons.delete_outline_rounded,
                                    size: 20,
                                    color: tk.dangerInk,
                                    onPressed: () => _delete(items[idx]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpace.s16),
                        child: InfoBanner(
                          'Fotos de antes e depois aumentam muito a confiança. Você também pode adicionar depois.',
                          tone: BannerTone.info,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: widget.setupMode
          ? AppBottomBar(child: AppButton(label: 'Continuar', trailingArrow: true, onPressed: widget.onDone))
          : null,
    );
  }
}

/// Meus Certificados (protótipo P04): cofre de qualificações.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final _providers = ProviderService();
  late Future<List<Certificate>> _future = _providers.myCertificates();

  void _reload() => setState(() {
        _future = _providers.myCertificates();
      });

  Future<void> _add() async {
    final title = TextEditingController();
    final issuer = TextEditingController();
    final year = TextEditingController();
    final saved = await AppSheet.show<bool>(
      context,
      title: 'Adicionar registro ou certificado',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(controller: title, label: 'Título (ex: Técnico em Eletrotécnica)'),
          const SizedBox(height: AppSpace.s12),
          AppTextField(controller: issuer, label: 'Emissor (ex: SENAI, CREA-MG)'),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            controller: year,
            keyboardType: TextInputType.number,
            label: 'Ano de emissão (opcional)',
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => AppButton(
            label: 'Salvar no cofre',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ),
      ],
    );
    if (saved == true && title.text.trim().isNotEmpty) {
      try {
        final y = int.tryParse(year.text.trim());
        await _providers.addCertificate(
          title: title.text.trim(),
          issuer: issuer.text.trim().isEmpty ? null : issuer.text.trim(),
          issuedAt: y == null ? null : DateTime(y),
        );
        _reload();
      } catch (e) {
        if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
      }
    }
    title.dispose();
    issuer.dispose();
    year.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Meus Certificados'),
      body: FutureBuilder<List<Certificate>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const AppSkeletonList(count: 3);
          final items = snap.data ?? const [];
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: margin, vertical: AppSpace.s20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: tk.providerSoft,
                  child: Icon(Icons.verified_user_rounded, size: 34, color: tk.accentInk),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Text('Certificações', textAlign: TextAlign.center, style: AppType.headline.copyWith(color: tk.text)),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Comprovar suas qualificações ajuda a conquistar a confiança dos clientes.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s20),
              for (final c in items)
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpace.s12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: tk.surface,
                        child: Icon(Icons.workspace_premium_rounded, color: tk.accentInk),
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: AppType.bodyStrong.copyWith(color: tk.text)),
                            Text(
                              [c.issuer, if (c.issuedAt != null) 'Emitido em ${c.issuedAt!.year}'].whereType<String>().join(' • '),
                              style: AppType.bodySm.copyWith(color: tk.textMuted),
                            ),
                            const SizedBox(height: AppSpace.s8),
                            const AppStatusChip('Em análise', tone: AppTone.warning, icon: Icons.schedule_rounded),
                          ],
                        ),
                      ),
                      AppIconButton(
                        tooltip: 'Excluir certificado',
                        icon: Icons.delete_outline_rounded,
                        color: tk.textMuted,
                        onPressed: () async {
                          await _providers.deleteCertificate(c.id);
                          _reload();
                        },
                      ),
                    ],
                  ),
                ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
                  child: Center(
                    child: Text('Nenhum certificado ainda.', style: AppType.bodySm.copyWith(color: tk.textMuted)),
                  ),
                ),
              const SizedBox(height: AppSpace.s8),
              AppButton(
                label: 'Adicionar registro ou certificado',
                variant: AppButtonVariant.secondary,
                icon: Icons.add_rounded,
                onPressed: _add,
              ),
              const SizedBox(height: AppSpace.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 15, color: tk.textMuted),
                  const SizedBox(width: AppSpace.s8),
                  Flexible(
                    child: Text(
                      'Seus dados são protegidos e visíveis só para você e a equipe.',
                      style: AppType.caption.copyWith(color: tk.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Minhas avaliações: nota, nota de ranqueamento, selos (com progresso) e
/// direito de resposta (uma vez por avaliação).
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _providers = ProviderService();
  late Future<({ProviderCard? card, List<OwnReview> reviews})> _future = _load();

  Future<({ProviderCard? card, List<OwnReview> reviews})> _load() async {
    final card = await _providers.byId(widget.profile.id);
    // Tela do próprio dono: usa my_received_reviews (com job_id), não a view pública.
    final reviews = await _providers.myReceivedReviews();
    return (card: card, reviews: reviews);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  /// Abre o dossiê interno do serviço avaliado (só o dono chega aqui).
  void _openDetails(OwnReview r) {
    final jobId = r.jobId;
    if (jobId == null) return;
    Navigator.of(context).push(AppRoute<void>(builder: (_) => DossieServicoProfissionalScreen(jobId: jobId)));
  }

  Future<void> _reply(OwnReview r) async {
    final ctl = TextEditingController();
    final text = await AppSheet.show<String>(
      context,
      title: 'Responder avaliação',
      subtitle: 'Sua resposta é pública e só pode ser enviada uma vez. Seja cordial e objetivo.',
      builder: (ctx) => AppTextField(
        controller: ctl,
        maxLines: 4,
        maxLength: 500,
        autofocus: true,
        hint: 'Escreva sua resposta...',
      ),
      actions: [
        Builder(
          builder: (ctx) => AppButton(
            label: 'Publicar resposta',
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
          ),
        ),
      ],
    );
    ctl.dispose();
    if (text == null || text.length < 3) return;
    try {
      await _providers.replyToReview(r.id, text);
      if (mounted) AppSnackbar.show(context, 'Resposta publicada!', kind: AppSnackKind.success);
      _reload();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Minhas avaliações'),
      body: FutureBuilder<({ProviderCard? card, List<OwnReview> reviews})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const AppSkeletonList(count: 4);
          if (snap.hasError) {
            return AppErrorState(
              message: 'Não foi possível carregar suas avaliações.',
              onRetry: _reload,
            );
          }
          final card = snap.data!.card;
          final reviews = snap.data!.reviews;
          final counts = <String, int>{};
          for (final r in reviews) {
            for (final t in r.tags) {
              counts[t] = (counts[t] ?? 0) + 1;
            }
          }
          var fiveStarStreak = 0;
          for (final r in reviews) {
            if (r.rating == 5) {
              fiveStarStreak++;
            } else {
              break;
            }
          }
          final avg = card?.ratingAvg ?? 0;
          final count = card?.ratingCount ?? 0;
          return ListView(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
            children: [
              AppCard(
                variant: AppCardVariant.elevated,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Text(
                          count > 0 ? avg.toStringAsFixed(2).replaceAll('.', ',') : '—',
                          style: AppType.figureXl.copyWith(color: tk.text),
                        ),
                        AppRating(value: avg, size: 16),
                        const SizedBox(height: AppSpace.s4),
                        Text(
                          '$count avaliações',
                          style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpace.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nota de ranqueamento', style: AppType.titleSm.copyWith(color: tk.text)),
                          Text(
                            card?.rankScore == null ? '—' : card!.rankScore!.toStringAsFixed(2).replaceAll('.', ','),
                            style: AppType.figure.copyWith(color: tk.accentInk),
                          ),
                          const SizedBox(height: AppSpace.s4),
                          Text(
                            'Define sua posição na busca. Considera a média e o volume de avaliações: quanto mais serviços bem avaliados, mais você sobe.',
                            style: AppType.caption.copyWith(color: tk.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              const InfoBanner(
                'As avaliações são cegas: a nota de um serviço só aparece aqui quando você e o cliente avaliarem, ou 48 horas depois da primeira avaliação.',
                tone: BannerTone.security,
                icon: Icons.visibility_off_rounded,
              ),
              const SizedBox(height: AppSpace.section),
              AppSection(
                title: 'Meus selos',
                child: BadgeWall(
                  earned: card?.badges ?? const [],
                  tagCounts: counts,
                  fiveStarCount: fiveStarStreak,
                  showProgress: true,
                ),
              ),
              const SizedBox(height: AppSpace.section),
              AppSection(
                title: 'Avaliações recebidas',
                child: reviews.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
                        child: Text(
                          'Você ainda não recebeu avaliações reveladas.',
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        ),
                      )
                    : Column(
                        children: [
                          for (final r in reviews)
                            ReviewCard(
                              // O card só recebe a projeção pública; o job_id fica aqui no closure do dono.
                              review: r.toPublic(),
                              onReply: r.hasReply ? null : () => _reply(r),
                              onOpenDetails: r.jobId == null ? null : () => _openDetails(r),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
