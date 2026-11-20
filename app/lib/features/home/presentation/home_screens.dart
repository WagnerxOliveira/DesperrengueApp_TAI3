import 'package:flutter/material.dart';

import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';

/// Painel do administrador (placeholder). A revisão de KYC e a mediação de
/// disputas são feitas hoje pelo dashboard do Supabase (RPCs
/// `admin_review_kyc` e `admin_resolve_dispute`).
class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: AppAppBar(
        title: 'Administração',
        actions: [
          AppIconButton(
            tooltip: 'Sair da conta',
            icon: Icons.logout_rounded,
            onPressed: () => ProfileService().signOut(),
          ),
        ],
      ),
      body: AppEmptyState(
        icon: Icons.admin_panel_settings_rounded,
        title: 'Painel de segurança',
        message:
            'A validação de documentos (KYC) e a mediação de chamados são gerenciadas pela equipe de segurança no painel administrativo.',
        padding: EdgeInsets.all(context.layout.margin + AppSpace.s12),
        illustration: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: tk.accentSoft, shape: BoxShape.circle),
          child: Icon(Icons.admin_panel_settings_rounded, size: 44, color: tk.accentInk),
        ),
      ),
    );
  }
}
