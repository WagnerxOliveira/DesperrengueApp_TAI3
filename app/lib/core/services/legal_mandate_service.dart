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

  /// Versão vigente dos Termos de Uso e Proteção do Cliente (`v3` — blindagem jurídica BR completa).
  static const String currentClientTermsVersion = '2026.11-CLIENT-V3';

  /// Versão vigente dos Termos de Parceria e Cláusula-Mandato do Profissional (`v3` — blindagem jurídica BR completa).
  static const String currentProviderTermsVersion = '2026.11-PROVIDER-V3';

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

  /// Contrato completo e juridicamente blindado do Modo Cliente (12 cláusulas —
  /// LGPD Lei 13.709/2018, CDC Lei 8.078/1990, Marco Civil Lei 12.965/2014,
  /// Código Civil, MP 2.200-2/2001, Lei 14.063/2020 e Ciclo de 90 Dias PF).
  static const List<LegalMandateClause> clientTermsClauses = <LegalMandateClause>[
    LegalMandateClause(
      title: '1. Objeto, Natureza da Intermediação Digital e Elegibilidade',
      body:
          'O Desperrengue atua exclusivamente como plataforma tecnológica de intermediação digital segura, '
          'conectando Clientes residenciais e comerciais a Profissionais autônomos independentes previamente '
          'verificados (Arts. 593 a 609 do Código Civil). Para criar e manter uma conta de Cliente, o titular '
          'declara ser pessoa física plenamente capaz (maior de 18 anos), possuir CPF ativo e regular perante '
          'a Receita Federal do Brasil e fornecer dados rigorosamente verdadeiros, assumindo integral '
          'responsabilidade civil e penal pela veracidade das informações prestadas.',
    ),
    LegalMandateClause(
      title: '2. Verificação de Identidade (KYC), Biometria Facial e Renovação de 90 Dias (Polícia Federal)',
      body:
          'Para proteger os lares e todos os membros da comunidade, a ativação da conta exige validação '
          'automatizada de documento oficial com foto (CNH, CIN ou RG), prova de vida facial ao vivo '
          'contra fraudes e Certidão Negativa de Antecedentes Criminais ("Nada Consta") emitida pela Polícia '
          'Federal (ePol/SINIC). Alinhada à validade oficial da certidão da Polícia Federal, a verificação '
          'de segurança possui vigência de 90 (noventa) dias corridos, com envio de avisos prévios automáticos '
          'por e-mail antes do vencimento (15 dias e 5 dias antes) para renovação simples. Dentro desses 90 dias '
          'válidos, sua validação é reaproveitada automaticamente caso você decida ativar também o modo Profissional.',
    ),
    LegalMandateClause(
      title: '3. Aprovação Cadastral e Confirmação Obrigatória de E-mail',
      body:
          'Após a aprovação das verificações de identidade e antecedentes, o Desperrengue envia um e-mail '
          'oficial de confirmação para o endereço cadastrado pelo titular. O acesso pleno à solicitação de '
          'serviços é liberado após a validação desse e-mail de aprovação, garantindo a autenticidade do canal '
          'de comunicações jurídicas, recibos, garantias e alertas de vencimento de segurança.',
    ),
    LegalMandateClause(
      title: '4. Orçamentos, Pagamento em Custódia Protegida (Escrow) e Código PIN de 4 Dígitos',
      body:
          'Os valores acordados no aplicativo permanecem 100% protegidos em conta de custódia segregada desde '
          'a confirmação do pedido até a conclusão presencial do atendimento. A liberação financeira ao Profissional '
          'somente ocorre após a entrega voluntária do seu código PIN pessoal e intransferível de 4 dígitos, '
          'fornecido exclusivamente após você conferir o serviço executado no local.',
    ),
    LegalMandateClause(
      title: '5. Peças e Materiais Consumíveis com 0% de Comissão mediante NF-e',
      body:
          'Quando o serviço demandar a aquisição de peças de reposição ou materiais consumíveis pelo Profissional, '
          'o reembolso desses itens é totalmente isento de taxa ou comissão da plataforma (0% de comissão), '
          'condicionado à apresentação e conferência de Nota Fiscal Eletrônica (NF-e/NFC-e) autêntica de 44 dígitos '
          'junto à SEFAZ, vinculada à respectiva ordem de serviço.',
    ),
    LegalMandateClause(
      title: '6. Direito de Arrependimento, Cancelamento e Reagendamento (Art. 49 do CDC)',
      body:
          'Em conformidade com o Código de Defesa do Consumidor (Lei 8.078/1990), o Cliente pode cancelar ou '
          'reagendar o atendimento diretamente pelo aplicativo sem qualquer custo antes do início do deslocamento '
          'do Profissional, bem como exercer o direito de arrependimento (Art. 49 do CDC) nos serviços ainda não '
          'iniciados. Em caso de cancelamento quando o Profissional já estiver em deslocamento ou no local combinado '
          'sem acesso ao imóvel por culpa do Cliente, poderá incidir apenas taxa transparente de deslocamento '
          'previamente informada; havendo ausência injustificada do Profissional, o reembolso ao Cliente é integral.',
    ),
    LegalMandateClause(
      title: '7. Garantia Legal e Contratual de 90 Dias em 3 Camadas (Art. 26, II do CDC)',
      body:
          'Todos os serviços contratados e pagos integralmente dentro do aplicativo contam com garantia de '
          '90 (noventa) dias sobre vícios de execução da mão de obra (Art. 26, II do CDC), estruturada em '
          '3 camadas: (i) retorno corretivo prioritário e sem custo adicional pelo Profissional original; '
          '(ii) mediação técnica documentada pela equipe Desperrengue; e (iii) acionamento do Fundo Garantidor '
          'Desperrengue para reparo corretivo ou ressarcimento proporcional, conforme evidências fotográficas.',
    ),
    LegalMandateClause(
      title: '8. Conduta Segura no Imóvel, Política Anticontorno e Protocolo Anti-Coação',
      body:
          'O Cliente compromete-se a manter ambiente seguro, respeitoso e livre de riscos não informados para a '
          'execução do serviço, bem como a não propor nem aceitar pagamentos por fora da plataforma para chamados '
          'originados no Desperrengue — a contratação por fora extingue automaticamente a custódia, o seguro e a '
          'garantia de 90 dias. Em qualquer situação de ameaça ou coação presencial, o aplicativo disponibiliza '
          'protocolo silencioso de proteção que retém preventivamente os valores em custódia sem expor o usuário.',
    ),
    LegalMandateClause(
      title: '9. Privacidade Geoespacial e Proteção de Dados Pessoais (LGPD — Lei 13.709/2018)',
      body:
          'Seu endereço exato, complemento e coordenadas permanecem criptograficamente protegidos durante a etapa '
          'de orçamento (exibindo apenas a região aproximada) e são liberados exclusivamente ao Profissional '
          'contratado após a confirmação da custódia. Dados pessoais sensíveis (biometria facial e documentos de '
          'identificação) são tratados sob sigilo estrito e criptografia, exclusivamente para prevenção à fraude e '
          'garantia de segurança do titular (Art. 11, II, "g" da LGPD). Você pode exercer a qualquer momento seus '
          'direitos de acesso, correção, portabilidade, revogação e eliminação de conta (Art. 18 da LGPD) nas '
          'configurações do aplicativo ou junto ao Encarregado de Dados (DPO) em privacidade@desperrengue.com.br.',
    ),
    LegalMandateClause(
      title: '10. Marco Civil da Internet, Registros de Auditoria e Propriedade Intelectual',
      body:
          'Em observância ao Marco Civil da Internet (Lei 12.965/2014 e Decreto 8.771/2016), o Desperrengue mantém '
          'registros seguros de data, hora, identificação e integridade de acessos e aceites pelo prazo legal. '
          'Marcas, códigos-fonte, algoritmos, interfaces, fluxos e conteúdos da plataforma são de titularidade '
          'exclusiva do Desperrengue (Leis 9.609/1998 e 9.610/1998), sendo vedada sua cópia, engenharia reversa '
          'ou exploração comercial não autorizada.',
    ),
    LegalMandateClause(
      title: '11. Limitação de Responsabilidade, Caso Fortuito e Força Maior (Art. 393 do Código Civil)',
      body:
          'O Desperrengue emprega as melhores práticas de segurança digital e verificação documental, mas não '
          'responde por interrupções decorrentes de caso fortuito ou força maior (Art. 393 do Código Civil), '
          'falhas de operadoras de internet, órgãos públicos emissores de certidões ou por acordos paralelos '
          'firmados diretamente fora do aplicativo. A responsabilidade técnica pela execução física do reparo '
          'pertence ao Profissional escolhido, sem prejuízo da cobertura da Garantia de 90 Dias nas regras aqui previstas.',
    ),
    LegalMandateClause(
      title: '12. Assinatura Eletrônica SHA-256, Atualizações Contratuais e Foro (MP 2.200-2/2001)',
      body:
          'O aceite eletrônico registrado nesta tela possui plena validade jurídica e força probante (MP 2.200-2/2001 '
          'e Lei 14.063/2020), sendo vinculado de forma imutável à sua conta por selo criptográfico SHA-256 e '
          'carimbo de data/hora. Eventuais atualizações relevantes destes Termos serão comunicadas previamente por '
          'e-mail e notificação no aplicativo. Estes Termos são regidos pelas leis da República Federativa do Brasil, '
          'preservando-se o foro do domicílio do consumidor para resolução de controvérsias (Art. 101, I do CDC).',
    ),
  ];

  /// Contrato completo e juridicamente blindado do Modo Profissional (13 cláusulas —
  /// CLT Art. 442-B, Código Civil Arts. 593–609 e Arts. 653–692 Cláusula-Mandato,
  /// LGPD Lei 13.709/2018, CDC Lei 8.078/1990, Marco Civil e Ciclo de 90 Dias PF).
  static const List<LegalMandateClause> providerTermsClauses = <LegalMandateClause>[
    LegalMandateClause(
      title: '1. Parceria Autônoma Independente e Inexistência de Vínculo Empregatício (Art. 442-B da CLT)',
      body:
          'O Profissional atua como prestador de serviços autônomo e independente (Arts. 593 a 609 do Código Civil '
          'e Art. 442-B da CLT), com plena autonomia técnica, liberdade absoluta de agenda, direito de recusar ou '
          'aceitar chamados sem penalidade, livre precificação de seus orçamentos e total ausência de exclusividade '
          'ou subordinação jurídica. O presente instrumento não estabelece vínculo empregatício, sociedade, '
          'representação comercial exclusiva ou franquia entre o Profissional e o Desperrengue.',
    ),
    LegalMandateClause(
      title: '2. Verificação de Identidade, Antecedentes Criminais PF e Renovação Obrigatória de 90 Dias',
      body:
          'É requisito indispensável para habilitação e permanência na plataforma a comprovação de identidade civil '
          '(documento oficial com foto), prova de vida facial ao vivo e Certidão Negativa de Antecedentes Criminais '
          '("Nada Consta") emitida pela Polícia Federal (ePol/SINIC). Alinhada ao prazo máximo oficial de validade '
          'da certidão da Polícia Federal, toda a validação de segurança possui vigência de 90 (noventa) dias corridos, '
          'devendo ser renovada ao final de cada ciclo mediante lembretes prévios enviados automaticamente por e-mail '
          '(15 dias e 5 dias antes do vencimento). Caso o Profissional já possua validação vigente feita no modo Cliente, '
          'os documentos são reaproveitados automaticamente até o término dos 90 dias sem nova cobrança.',
    ),
    LegalMandateClause(
      title: '3. Aprovação Cadastral e Validação Obrigatória de E-mail',
      body:
          'Concluída a análise documental e de segurança, o Desperrengue encaminha e-mail oficial de aprovação ao '
          'endereço eletrônico do Profissional. A ativação definitiva para recebimento de chamados e liquidação de '
          'repasses depende da confirmação desse e-mail oficial, mantendo válido o canal de notificações contratuais, '
          'extratos financeiros e avisos de renovação de 90 dias.',
    ),
    LegalMandateClause(
      title: '4. Cláusula-Mandato Mercantil Expressa — Smart Split 85% / 13,5% / 1,5% (Arts. 653 a 692 do CC)',
      body:
          'Pelo presente instrumento, o Profissional outorga mandato mercantil especial e específico ao Desperrengue '
          '(Arts. 653 a 692 do Código Civil) para, em seu nome e por sua conta: (i) receber e manter em conta de '
          'custódia segregada os valores pagos pelos Clientes; (ii) deduzir exclusivamente a taxa de intermediação '
          'tecnológica de 13,5% (treze inteiros e cinco décimos por cento) sobre a mão de obra; (iii) destinar '
          '1,5% (um inteiro e cinco décimos por cento) da mão de obra ao Fundo Garantidor de 90 dias; e (iv) repassar '
          'integralmente ao Profissional os 85,0% (oitenta e cinco por cento) líquidos da mão de obra para conta '
          'bancária ou chave PIX de mesma titularidade CPF/CNPJ após o prazo de maturação antifraude.',
    ),
    LegalMandateClause(
      title: '5. Reembolso Integral de Peças e Materiais (0% de Taxa com NF-e de 44 Dígitos)',
      body:
          'Peças e materiais consumíveis adquiridos pelo Profissional para aplicação direta no imóvel do Cliente, '
          'quando comprovados por Nota Fiscal Eletrônica (NF-e/NFC-e) autêntica de 44 dígitos autorizada na SEFAZ '
          '(excluídas ferramentas e equipamentos permanentes de trabalho), constituem mero reembolso de despesas '
          'por conta e ordem do Cliente, com 0% (zero por cento) de comissão da plataforma. O cancelamento indevido '
          'ou fraude na nota fiscal após o repasse autoriza estorno compensatório imediato e bloqueio cadastral.',
    ),
    LegalMandateClause(
      title: '6. Autonomia Fiscal, Tributária e Previdenciária do Profissional',
      body:
          'O Profissional é o único e exclusivo responsável pela regularidade fiscal e previdenciária de sua atividade '
          '(MEI, autônomo ou pessoa jurídica), incluindo a emissão de Nota Fiscal de Serviços (NFS-e) ou recibo ao '
          'Cliente pelo valor total de sua mão de obra quando exigido por lei, bem como o recolhimento de ISS, INSS, '
          'DAS-MEI, IRPF/IRPJ e demais encargos incidentes sobre sua remuneração, sem qualquer solidariedade trabalhista.',
    ),
    LegalMandateClause(
      title: '7. Excelência Técnica, Registro Fotográfico, PIN de Conclusão e Garantia de 90 Dias (Art. 26, II CDC)',
      body:
          'O Profissional compromete-se a executar os serviços com rigor técnico, pontualidade, observância das normas '
          'de segurança (incluindo NR-10, NR-35 e EPIs quando aplicáveis) e registro fotográfico de início e conclusão '
          'no aplicativo, encerrando cada ordem de serviço exclusivamente mediante validação do código PIN presencial '
          'fornecido pelo Cliente. O Profissional assegura garantia legal de 90 (noventa) dias sobre vícios de execução '
          'da mão de obra (Art. 26, II do CDC), comprometendo-se ao pronto retorno corretivo sem custo adicional quando '
          'constatada falha técnica atribuível ao serviço realizado.',
    ),
    LegalMandateClause(
      title: '8. Conduta Ética Residencial, Política Anticontorno e Sanções Progressivas',
      body:
          'É estritamente proibido ao Profissional solicitar ou aceitar pagamentos por fora do aplicativo para clientes '
          'ou chamados intermediados pelo Desperrengue, repassar credenciais de conta a terceiros, subcontratar pessoa '
          'não verificada para entrar na residência do Cliente ou adotar conduta intimidadora, discriminatória ou ilegal. '
          'Infrações sujeitam a conta a advertência, suspensão preventiva, compensação de prejuízos comprovados ou '
          'banimento definitivo com bloqueio permanente do CPF.',
    ),
    LegalMandateClause(
      title: '9. Protocolo Silencioso de Proteção Física Anti-Coação',
      body:
          'Para salvaguardar a integridade física tanto do Profissional quanto do Cliente durante atendimentos presenciais, '
          'a plataforma opera protocolo silencioso anti-coação que congela preventivamente a liquidação financeira sem '
          'expor a parte vulnerável no local, encaminhando a ocorrência para auditoria de segurança e apoio prioritário.',
    ),
    LegalMandateClause(
      title: '10. Sigilo Estrito de Endereços e Conformidade LGPD (Lei 13.709/2018)',
      body:
          'Endereços, telefones, fotografias internas de imóveis e quaisquer dados pessoais dos Clientes são confiados '
          'ao Profissional exclusivamente para execução da ordem de serviço contratada, sendo terminantemente proibido '
          'copiar, divulgar, armazenar externamente ou reutilizar tais dados após o atendimento, sob pena de rescisão '
          'imediata e responsabilização integral na forma da LGPD (Lei 13.709/2018). Os dados biométricos e documentais '
          'do Profissional são tratados com base no Art. 11, II, "g" da LGPD para prevenção à fraude e segurança; '
          'solicitações de direitos do titular (Art. 18) podem ser exercidas no app ou via privacidade@desperrengue.com.br.',
    ),
    LegalMandateClause(
      title: '11. Marco Civil da Internet, Registros de Acesso e Propriedade Intelectual',
      body:
          'Nos termos do Marco Civil da Internet (Lei 12.965/2014 e Decreto 8.771/2016), o Desperrengue registra logs '
          'seguros de acessos, aceites contratuais, transações e confirmações de PIN para fins de auditoria e proteção '
          'jurídica. Todo software, marca, algoritmo, layout e material da plataforma são protegidos pelas Leis '
          '9.609/1998 e 9.610/1998, sendo vedado seu uso não autorizado.',
    ),
    LegalMandateClause(
      title: '12. Responsabilidade Civil Técnica, Indenização e Força Maior (Art. 393 do Código Civil)',
      body:
          'O Profissional responde civil e tecnicamente pelos danos materiais ou pessoais comprovadamente causados por '
          'dolo, imperícia, imprudência ou negligência durante a execução dos serviços no imóvel do Cliente, autorizando '
          'a retenção cautelar ou compensação de valores em custódia enquanto perdurar apuração de disputa formal. '
          'Nenhuma das partes responderá por eventos caracterizados como caso fortuito ou força maior (Art. 393 do CC).',
    ),
    LegalMandateClause(
      title: '13. Vigência, Rescisão, Assinatura Eletrônica SHA-256 e Foro (MP 2.200-2/2001)',
      body:
          'Este contrato vigora por prazo indeterminado e pode ser encerrado por qualquer das partes mediante aviso no '
          'aplicativo, ressalvadas as ordens de serviço em andamento, garantias de 90 dias já assumidas e saldos '
          'pendentes de maturação. O aceite eletrônico possui plena validade jurídica e força executiva (MP 2.200-2/2001 '
          'e Lei 14.063/2020), autenticado por hash SHA-256 e carimbo temporal imutável. Aplica-se integralmente a '
          'legislação brasileira, priorizando-se mediação eletrônica prévia antes da via judicial.',
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
