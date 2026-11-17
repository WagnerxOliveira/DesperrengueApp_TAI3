import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de aceite criptográfico dos Termos de Uso e da Cláusula-Mandato
/// Mercantil Expressa (Art. 653 a 692 do Código Civil + Segregação de Custódia).
class LegalMandateClause {
  const LegalMandateClause({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class LegalMandateService {
  const LegalMandateService._();

  static const String currentMandateVersion = '2026.11-ART653-V1';

  static const List<LegalMandateClause> canonicalClauses = <LegalMandateClause>[
    LegalMandateClause(
      title: '1. Objeto, Intermediação Digital e Validação de Segurança',
      body:
          'O Desperrengue atua exclusivamente como plataforma tecnológica de intermediação digital (Agente), '
          'conectando clientes residenciais a profissionais autônomos independentes verificados. '
          'A relação de prestação do serviço técnico ocorre diretamente entre o Profissional e o Cliente.',
    ),
    LegalMandateClause(
      title: '2. Cláusula-Mandato Mercantil Expressa (Arts. 653 a 692 do Código Civil)',
      body:
          'Pelo presente instrumento, o Profissional outorga mandato mercantil especial e específico ao Desperrengue '
          'para, em seu nome e por sua conta: (i) receber e manter em custódia segregada os valores pagos pelo Cliente; '
          '(ii) deduzir e liquidar exclusivamente a taxa de intermediação tecnológica de 13,5% (treze inteiros e cinco décimos por cento) '
          'sobre a mão de obra; (iii) destinar 1,5% (um inteiro e cinco décimos por cento) da mão de obra ao Fundo Garantidor '
          'de 90 dias em 3 camadas; e (iv) repassar integralmente ao Profissional os 85,0% (oitenta e cinco por cento) líquidos '
          'da mão de obra após o prazo de maturação antifraude.',
    ),
    LegalMandateClause(
      title: '3. Reembolso Isento de Peças e Materiais (0% de Taxa com NF-e)',
      body:
          'Materiais e peças adquiridos pelo Profissional para aplicação direta no imóvel do Cliente, quando acompanhados '
          'de Nota Fiscal Eletrônica válida de 44 dígitos conferida perante a Fazenda Estadual, constituem mero reembolso '
          'de despesa por conta e ordem do Cliente, com 0% (zero por cento) de comissão da plataforma.',
    ),
    LegalMandateClause(
      title: '4. Garantia de 90 Dias em 3 Camadas e Código PIN de Conclusão',
      body:
          'O valor pago pelo Cliente permanece 100% protegido em custódia até a confirmação presencial do serviço por código '
          'PIN de 4 dígitos. Todos os serviços concluídos contam com garantia técnica de 90 dias (Art. 26, II do CDC). '
          'Em situação de ameaça ou coação presencial, o protocolo silencioso de proteção retém preventivamente os valores em custódia.',
    ),
    LegalMandateClause(
      title: '5. Privacidade Geoespacial e Proteção de Dados (LGPD — Lei 13.709/2018)',
      body:
          'O endereço completo do imóvel permanece criptograficamente oculto durante a cotação e só é liberado ao '
          'Profissional contratado após a confirmação da custódia. O usuário pode gerenciar ou solicitar a exclusão '
          'de seus dados pessoais a qualquer momento nas configurações de perfil.',
    ),
  ];

  /// Texto integral canônico assinado por `SHA-256`.
  static String get canonicalFullText {
    final buffer = StringBuffer()
      ..writeln('DESPERRENGUE - TERMOS DE USO E CLAUSULA-MANDATO ART. 653 CC')
      ..writeln('VERSAO: $currentMandateVersion');
    for (final c in canonicalClauses) {
      buffer
        ..writeln(c.title)
        ..writeln(c.body);
    }
    return buffer.toString();
  }

  /// Digest hexadecimal `SHA-256` (64 caracteres) do contrato vigente.
  static String get currentDocumentSha256Hex =>
      sha256.convert(utf8.encode(canonicalFullText)).toString().toLowerCase();

  /// Registra no Supabase (`public.legal_mandate_acceptances`) o aceite assinado
  /// pelo usuário autenticado, disparando sincronização imediata em tempo real.
  /// Falha silenciosamente em modo offline/teste sem bloquear a jornada do usuário.
  static Future<bool> recordAcceptanceIfAuthenticated({
    String roleScope = 'CLIENT',
    SupabaseClient? clientOverride,
  }) async {
    try {
      final client = clientOverride ?? Supabase.instance.client;
      if (client.auth.currentUser == null) return false;
      final normalizedScope = switch (roleScope.trim().toUpperCase()) {
        'PROVIDER' => 'PROVIDER',
        'DUAL_MODE' => 'DUAL_MODE',
        _ => 'CLIENT',
      };
      await client.rpc<dynamic>(
        'record_legal_mandate_acceptance',
        params: <String, dynamic>{
          'p_mandate_version': currentMandateVersion,
          'p_document_sha256': currentDocumentSha256Hex,
          'p_role_scope': normalizedScope,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
