import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Serviço de aceite criptográfico dos Termos de Uso Específicos por Perfil
/// (`Cliente` vs. `Profissional`) e da Cláusula-Mandato Mercantil Expressa
/// (Arts. 653 a 692 do Código Civil + Segregação de Custódia + Revalidação 6 Meses).
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

  /// Versão unificada retrocompatível (`v1`) preservada para suítes existentes.
  static const String currentMandateVersion = '2026.11-ART653-V1';

  /// Versão vigente dos Termos de Uso e Proteção do Cliente (`v2`).
  static const String currentClientTermsVersion = '2026.11-CLIENT-V2';

  /// Versão vigente dos Termos de Parceria e Cláusula-Mandato do Profissional (`v2`).
  static const String currentProviderTermsVersion = '2026.11-PROVIDER-V2';

  /// Cláusulas canônicas retrocompatíveis (`v1`).
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

  /// Contrato exclusivo do Modo Cliente (6 cláusulas completas).
  static const List<LegalMandateClause> clientTermsClauses = <LegalMandateClause>[
    LegalMandateClause(
      title: '1. Objeto e Intermediação Digital Residencial',
      body:
          'O Desperrengue atua como plataforma tecnológica de intermediação digital segura, conectando você '
          'a profissionais autônomos independentes previamente identificados. Os orçamentos, prazos e execução '
          'técnica do serviço residencial são realizados pelo Profissional escolhido por você no aplicativo.',
    ),
    LegalMandateClause(
      title: '2. Custódia Protegida e Liberação por Código PIN de 4 Dígitos',
      body:
          'Todo pagamento realizado no aplicativo permanece 100% protegido em conta de custódia segregada até '
          'que o serviço seja concluído no local. A liberação financeira só ocorre mediante a entrega voluntária '
          'do seu código PIN exclusivo de 4 dígitos após sua conferência do trabalho executado.',
    ),
    LegalMandateClause(
      title: '3. Peças e Materiais com 0% de Taxa mediante Nota Fiscal (NF-e)',
      body:
          'Quando o atendimento exigir compra de peças ou materiais consumíveis pelo Profissional, o reembolso '
          'é integralmente isento de comissão da plataforma (0% de taxa) mediante apresentação de Nota Fiscal '
          'Eletrônica válida de 44 dígitos vinculada ao atendimento, garantindo transparência total de custos.',
    ),
    LegalMandateClause(
      title: '4. Garantia Técnica de 90 Dias em 3 Camadas (Art. 26, II do CDC)',
      body:
          'Todos os serviços concluídos pela plataforma contam com garantia legal e contratual de 90 (noventa) dias '
          'sobre a mão de obra executada, assegurada em 3 camadas: atendimento prioritário pelo prestador original, '
          'mediação técnica assistida e cobertura pelo Fundo Garantidor Desperrengue para reparo corretivo.',
    ),
    LegalMandateClause(
      title: '5. Privacidade Geoespacial do Imóvel e LGPD (Lei 13.709/2018)',
      body:
          'Seu endereço completo, número da residência e coordenadas exatas permanecem ocultos durante toda a fase '
          'de orçamento, exibindo apenas uma região aproximada. Os dados exatos só são liberados ao Profissional '
          'efetivamente contratado na data programada para o serviço, podendo você excluir sua conta a qualquer momento.',
    ),
    LegalMandateClause(
      title: '6. Validação Semestral de Segurança e Antecedentes (a cada 6 Meses)',
      body:
          'Para proteger os lares e todos os participantes da comunidade, o Desperrengue exige validação de documento '
          'oficial, biometria facial ao vivo e Certidão Negativa de Antecedentes Criminais da Polícia Federal, com '
          'renovação periódica obrigatória a cada 6 (seis) meses. Caso você ative também o modo Profissional dentro '
          'desse período válido, sua validação é reaproveitada sem novo envio de documentos.',
    ),
  ];

  /// Contrato exclusivo do Modo Profissional (7 cláusulas completas incluindo Cláusula-Mandato Art. 653 CC).
  static const List<LegalMandateClause> providerTermsClauses = <LegalMandateClause>[
    LegalMandateClause(
      title: '1. Parceria Autônoma Independente e Inexistência de Vínculo Empregatício',
      body:
          'O Profissional atua com total autonomia técnica, liberdade de agenda, livre precificação de seus orçamentos '
          'e ausência de exclusividade ou subordinação jurídica, inexistindo vínculo empregatício de qualquer natureza '
          'com o Desperrengue, nos termos da legislação civil aplicável.',
    ),
    LegalMandateClause(
      title: '2. Cláusula-Mandato Mercantil Expressa (Arts. 653 a 692 do Código Civil — 85% / 13,5% / 1,5%)',
      body:
          'Pelo presente instrumento, o Profissional outorga mandato mercantil especial e específico ao Desperrengue '
          'para, em seu nome e por sua conta: (i) receber e manter em custódia segregada os valores pagos pelos Clientes; '
          '(ii) deduzir exclusivamente a taxa de intermediação tecnológica de 13,5% (treze inteiros e cinco décimos por cento) '
          'sobre o valor da mão de obra; (iii) destinar 1,5% (um inteiro e cinco décimos por cento) da mão de obra ao Fundo '
          'Garantidor de 90 dias; e (iv) repassar integralmente ao Profissional os 85,0% (oitenta e cinco por cento) líquidos '
          'da mão de obra para a conta titular vinculada ao seu CPF após a maturação de segurança.',
    ),
    LegalMandateClause(
      title: '3. Reembolso Integral de Peças e Materiais (0% de Taxa com NF-e de 44 Dígitos)',
      body:
          'Insumos e peças consumíveis aplicados diretamente na ordem de serviço, quando comprovados por Nota Fiscal '
          'Eletrônica autêntica de 44 dígitos autorizada na SEFAZ (excluídas ferramentas de uso permanente), são '
          'reembolsados ao Profissional com 0% (zero por cento) de retenção de taxa. O cancelamento indevido da nota '
          'fiscal após a conclusão enseja estorno compensatório da taxa correspondente.',
    ),
    LegalMandateClause(
      title: '4. Garantia Técnica de 90 Dias e Conduta Ética Residencial',
      body:
          'O Profissional compromete-se a executar os serviços com excelência técnica, pontualidade, respeito no interior '
          'das residências e registro fotográfico de entrada e conclusão, prestando suporte de garantia de 90 dias (Art. 26, '
          'II do CDC) sobre vícios de execução e vedando qualquer tentativa de desvio de chamados por fora da custódia segura.',
    ),
    LegalMandateClause(
      title: '5. Antecedentes Criminais e Revalidação Semestral Obrigatória (a cada 6 Meses)',
      body:
          'É requisito indispensável para manter o perfil ativo a comprovação de identidade civil, prova de vida facial '
          'e Certidão Negativa de Antecedentes Criminais emitida pela Polícia Federal (SINIC/ePol), devendo toda a '
          'documentação ser obrigatoriamente revalidada a cada 6 (seis) meses. Caso o Profissional já possua validação '
          'vigente realizada no modo Cliente, os documentos são reaproveitados automaticamente até o fim do semestre.',
    ),
    LegalMandateClause(
      title: '6. Protocolo de Proteção Física Anti-Coação',
      body:
          'Para proteção da integridade física de Clientes e Profissionais em atendimentos presenciais, a plataforma '
          'dispõe de mecanismos silenciosos anti-coação que congelam preventivamente a liquidação financeira sem expor '
          'a vítima no local, submetendo o evento à auditoria de segurança.',
    ),
    LegalMandateClause(
      title: '7. Sigilo Estrito de Endereço e Conformidade LGPD (Lei 13.709/2018)',
      body:
          'Os endereços, fotos técnicas e dados de contato dos Clientes são confiados ao Profissional exclusivamente '
          'para a execução da ordem de serviço contratada, sendo terminantemente proibido o armazenamento externo, '
          'compartilhamento com terceiros ou uso para finalidade diversa, sob as penas da Lei Geral de Proteção de Dados.',
    ),
  ];

  /// Retorna a lista de cláusulas jurídicas específicas do [mode] (`client` ou `provider`).
  static List<LegalMandateClause> clausesForMode(UserMode mode) =>
      mode == UserMode.provider ? providerTermsClauses : clientTermsClauses;

  /// Retorna o identificador de versão contratual do [mode].
  static String versionForMode(UserMode mode) => mode == UserMode.provider
      ? currentProviderTermsVersion
      : currentClientTermsVersion;

  /// Título oficial amigável do contrato para exibição na interface.
  static String titleForMode(UserMode mode) => mode == UserMode.provider
      ? 'Termos de Parceria e Cláusula-Mandato do Profissional'
      : 'Termos de Uso e Proteção do Cliente Desperrengue';

  /// Texto integral determinístico assinado por `SHA-256` para o [mode].
  static String fullTextForMode(UserMode mode) {
    final version = versionForMode(mode);
    final clauses = clausesForMode(mode);
    final header = mode == UserMode.provider
        ? 'DESPERRENGUE - TERMOS DE PARCERIA E CLAUSULA-MANDATO DO PROFISSIONAL (ART. 653 CC)'
        : 'DESPERRENGUE - TERMOS DE USO E PROTECAO DO CLIENTE RESIDENCIAL';
    final buffer = StringBuffer()
      ..writeln(header)
      ..writeln('VERSAO: $version');
    for (final c in clauses) {
      buffer
        ..writeln(c.title)
        ..writeln(c.body);
    }
    return buffer.toString();
  }

  /// Digest hexadecimal `SHA-256` (64 caracteres minúsculos) específico do [mode].
  static String sha256ForMode(UserMode mode) =>
      sha256.convert(utf8.encode(fullTextForMode(mode))).toString().toLowerCase();

  /// Texto integral canônico retrocompatível (`v1`) assinado por `SHA-256`.
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

  /// Digest hexadecimal `SHA-256` (64 caracteres) do contrato retrocompatível (`v1`).
  static String get currentDocumentSha256Hex =>
      sha256.convert(utf8.encode(canonicalFullText)).toString().toLowerCase();

  /// Registra no Supabase (`public.legal_mandate_acceptances`) o aceite assinado
  /// pelo usuário autenticado, disparando sincronização imediata em tempo real.
  /// Falha silenciosamente em modo offline/teste sem bloquear a jornada do usuário.
  static Future<bool> recordAcceptanceIfAuthenticated({
    String roleScope = 'CLIENT',
    String? mandateVersionOverride,
    String? documentSha256Override,
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
          'p_mandate_version': mandateVersionOverride ?? currentMandateVersion,
          'p_document_sha256': documentSha256Override ?? currentDocumentSha256Hex,
          'p_role_scope': normalizedScope,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Registra o aceite específico do [mode] (`CLIENT` ou `PROVIDER`) com sua versão
  /// e assinatura `SHA-256` correspondentes.
  static Future<bool> recordModeTermsAcceptanceIfAuthenticated(
    UserMode mode, {
    SupabaseClient? clientOverride,
  }) =>
      recordAcceptanceIfAuthenticated(
        roleScope: mode == UserMode.provider ? 'PROVIDER' : 'CLIENT',
        mandateVersionOverride: versionForMode(mode),
        documentSha256Override: sha256ForMode(mode),
        clientOverride: clientOverride,
      );
}
