import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';

import '../../../core/state/theme_controller.dart';
import '../../../core/ui/profile_and_achievement_emblems.dart';

/// Seletor de aparência (Automático · Claro · Escuro), persistido no cache.
/// Entrada: `showThemePicker(context)` a partir do Perfil (cliente e profissional).
Future<void> showThemePicker(BuildContext context) => AppSheet.show<void>(
      context,
      title: 'Aparência',
      subtitle: 'O modo escuro usa fundo grafite azulado e cores suavizadas para cansar menos a vista.',
      builder: (_) => const _ThemePickerSheet(),
    );

/// Linha de menu "Aparência" com o valor atual — usada nos dois perfis.
class AppearanceTile extends ConsumerWidget {
  const AppearanceTile({
    super.key,
    required this.accent,
    required this.soft,
    this.kind = ProfileMenuIconKind.clientAppearance,
  });

  final Color accent;
  final Color soft;
  final ProfileMenuIconKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return AppListTile(
      padding: EdgeInsets.zero,
      leading: ProfileMenuEmblem(kind: kind, size: 42),
      title: 'Aparência',
      subtitle: 'Tema ${mode.label.toLowerCase()}',
      showChevron: true,
      onTap: () => showThemePicker(context),
    );
  }
}

class _ThemePickerSheet extends ConsumerWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final tk = context.tk;
    return RadioGroup<AppThemeMode>(
      groupValue: current,
      onChanged: (v) {
        if (v != null) ref.read(themeModeProvider.notifier).select(v);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in AppThemeMode.values)
            RadioListTile<AppThemeMode>(
              contentPadding: EdgeInsets.zero,
              value: m,
              secondary: Icon(m.icon, color: m == current ? tk.accentInk : tk.textMuted),
              title: Text(m.label, style: AppType.bodyStrong.copyWith(color: tk.text)),
              subtitle: m == AppThemeMode.system
                  ? Text('Segue o tema do aparelho', style: AppType.bodySm.copyWith(color: tk.textMuted))
                  : null,
            ),
        ],
      ),
    );
  }
}
