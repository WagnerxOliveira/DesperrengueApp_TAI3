import '../../../core/ui/app_scaffold.dart';
import 'package:flutter/material.dart';

import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_tokens.dart';

/// Painel do administrador (placeholder). A revisão de KYC e a mediação de
/// disputas são feitas hoje pelo dashboard do Supabase (RPCs
/// `admin_review_kyc` e `admin_resolve_dispute`).
class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Administração'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ProfileService().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_rounded, size: 72, color: context.tk.brand),
              SizedBox(height: 16),
              const Text(
                'A validação de documentos (KYC) e a mediação de chamados são gerenciadas pela equipe de segurança no painel administrativo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
