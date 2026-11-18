import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/legal_mandate_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/light_island.dart';

/// Tela oficial de Termos de Uso, Política de Privacidade e Cláusula-Mandato
/// Mercantil Expressa (Art. 653 do Código Civil — Split 85% / 13,5% / 1,5% + 0% Peças NF-e),
/// com seletor segmentado **Termos do Cliente** | **Termos do Profissional** para consulta
/// pública ou autenticada a qualquer momento.
class VerificacaoStep6cTermosScreen extends StatefulWidget {
  const VerificacaoStep6cTermosScreen({super.key, this.initialMode});

  final UserMode? initialMode;

  @override
  State<VerificacaoStep6cTermosScreen> createState() =>
      _VerificacaoStep6cTermosScreenState();
}

class _VerificacaoStep6cTermosScreenState
    extends State<VerificacaoStep6cTermosScreen> {
  static const Color _primaryBlue = Color(0xFF003366);
  static const Color _textDarkBlue = Color(0xFF001A33);
  static const Color _textSlate = Color(0xFF334155);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _textHeading = Color(0xFF0F172A);

  late UserMode _selectedMode = widget.initialMode ?? UserMode.provider;

  @override
  Widget build(BuildContext context) {
    final canonicalHex = LegalMandateService.currentDocumentSha256Hex;
    final modeHex = LegalMandateService.sha256ForMode(_selectedMode);
    final modeVersion = LegalMandateService.versionForMode(_selectedMode);
    final clauses = LegalMandateService.clausesForMode(_selectedMode);
    final isClient = _selectedMode == UserMode.client;

    return LightIsland(
      child: AppScaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _primaryBlue),
          title: const Text(
            'Termos e Mandato Legal',
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfficialTag(),
                  const SizedBox(height: 14),
                  _buildRoleSegmentSelector(),
                  const SizedBox(height: 16),
                  Text(
                    isClient
                        ? 'Termos de Uso e Proteção do Cliente Desperrengue'
                        : 'Termos de Uso, Custódia e Cláusula-Mandato',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _textDarkBlue,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versão vigente: $modeVersion · Código Civil Art. 653 e LGPD · Validação Semestral (6 meses)',
                    style: const TextStyle(fontSize: 12, color: _textMuted),
                  ),
                  const SizedBox(height: 18),
                  Divider(
                    color: Colors.grey.withValues(alpha: 0.15),
                    thickness: 1,
                  ),
                  const SizedBox(height: 18),
                  for (final clause in clauses)
                    _buildClause(title: clause.title, content: clause.body),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _primaryBlue.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selo Digital de Integridade Contratual (SHA-256)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          canonicalHex,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: _textMuted,
                          ),
                        ),
                        if (modeHex != canonicalHex) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Selo Específico (${isClient ? "Cliente" : "Profissional"}): $modeHex',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSegmentSelector() {
    final isClient = _selectedMode == UserMode.client;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withValues(alpha: 0.12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final clientTab = InkWell(
            key: const ValueKey('segment-terms-client'),
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => _selectedMode = UserMode.client),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: isClient ? _primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                'Termos do Cliente',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isClient ? Colors.white : _textDarkBlue,
                ),
              ),
            ),
          );

          final providerTab = InkWell(
            key: const ValueKey('segment-terms-provider'),
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => _selectedMode = UserMode.provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: !isClient ? _primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                'Termos do Profissional',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: !isClient ? Colors.white : _textDarkBlue,
                ),
              ),
            ),
          );

          if (constraints.maxWidth < 290) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [clientTab, const SizedBox(height: 4), providerTab],
            );
          }

          return Row(
            children: [
              Expanded(child: clientTab),
              const SizedBox(width: 6),
              Expanded(child: providerTab),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfficialTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _primaryBlue.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel_rounded, color: _primaryBlue, size: 14),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'DOCUMENTO OFICIAL · MANDATO ART. 653 CC',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClause({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: _textHeading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: _textSlate,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
