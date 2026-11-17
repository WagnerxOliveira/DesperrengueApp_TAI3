import 'package:flutter/material.dart';

import '../../../core/services/legal_mandate_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/light_island.dart';

/// Tela oficial de Termos de Uso, Política de Privacidade e Cláusula-Mandato
/// Mercantil Expressa (Art. 653 do Código Civil — Split 85% / 13,5% / 1,5% + 0% Peças NF-e).
class VerificacaoStep6cTermosScreen extends StatelessWidget {
  const VerificacaoStep6cTermosScreen({super.key});

  static const Color _primaryBlue = Color(0xFF003366);
  static const Color _textDarkBlue = Color(0xFF001A33);
  static const Color _textSlate = Color(0xFF334155);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _textHeading = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final sealHex = LegalMandateService.currentDocumentSha256Hex;

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
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfficialTag(),
                  const SizedBox(height: 16),
                  const Text(
                    'Termos de Uso, Custódia e Cláusula-Mandato',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: _textDarkBlue,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Versão vigente: ${LegalMandateService.currentMandateVersion} · Código Civil Art. 653 e LGPD',
                    style: TextStyle(fontSize: 12, color: _textMuted),
                  ),
                  const SizedBox(height: 20),
                  Divider(
                    color: Colors.grey.withValues(alpha: 0.15),
                    thickness: 1,
                  ),
                  const SizedBox(height: 20),
                  for (final clause in LegalMandateService.canonicalClauses)
                    _buildClause(
                      title: clause.title,
                      content: clause.body,
                    ),
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
                          sealHex,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: _textMuted,
                          ),
                        ),
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
      padding: const EdgeInsets.only(bottom: 24.0),
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
