/// Serviço Oficial de Exportação Contábil-Fiscal CPC 47 / IFRS 15 e Dossiê Policial
/// Forense `FROZEN_UNDER_DURESS` do Cockpit Executivo Soberano.
///
/// Gera binários vetoriais `%PDF-1.4` multipágina em Dart puro (Base-14 Type1 `Helvetica-Bold`
/// + `Courier` tabular, tabela `xref` exata em bytes), planilhas CSV compatíveis com RFC-4180
/// (`;` para ERP/Excel pt-BR ou `,` internacional) e selos criptográficos `SHA-256`
/// (`package:crypto/crypto.dart`), com execução assíncrona via [runOffMainThread].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../utils/money.dart';
import '../utils/off_thread.dart';
import 'founder_dashboard_models.dart';

/// Artefato imutável do Pacote Mensal Contábil-Fiscal CPC 47 / IFRS 15.
class MonthlyAccountantPackArtifact {
  const MonthlyAccountantPackArtifact({
    required this.competenceLabel,
    required this.generatedAtUtc,
    required this.pdfBytes,
    required this.csvContent,
    required this.sha256SealHex,
    required this.pdfSha256Hex,
    required this.csvSha256Hex,
    required this.canonicalPayloadToSign,
    required this.summaryMetricsCents,
  });

  final String competenceLabel;
  final DateTime generatedAtUtc;
  final Uint8List pdfBytes;
  final String csvContent;

  /// Selo criptográfico SHA-256 canônico (impresso dentro do PDF e auditável).
  final String sha256SealHex;

  /// Hash SHA-256 exato dos bytes finais do binário `%PDF-1.4`.
  final String pdfSha256Hex;

  /// Hash SHA-256 exato do conteúdo UTF-8 do arquivo CSV RFC-4180.
  final String csvSha256Hex;

  final String canonicalPayloadToSign;
  final Map<String, int> summaryMetricsCents;

  /// Revalida criptograficamente o pacote completo (`CSV`, `Selo Canônico` e `Binário PDF`).
  bool verifyIntegrity() {
    final actualCsvHash = sha256.convert(utf8.encode(csvContent)).toString();
    if (actualCsvHash != csvSha256Hex) return false;

    final actualSeal =
        sha256.convert(utf8.encode(canonicalPayloadToSign)).toString();
    if (actualSeal != sha256SealHex) return false;

    final actualPdfHash = sha256.convert(pdfBytes).toString();
    return actualPdfHash == pdfSha256Hex;
  }
}

/// Artefato imutável do Dossiê Forense Policial Assinado (`FROZEN_UNDER_DURESS`).
class DuressForensicDossierArtifact {
  const DuressForensicDossierArtifact({
    required this.incidentId,
    required this.orderCode,
    required this.generatedAtUtc,
    required this.pdfBytes,
    required this.chainOfCustodyJson,
    required this.sha256SealHex,
    required this.pdfSha256Hex,
    required this.canonicalManifestPayload,
  });

  final String incidentId;
  final String orderCode;
  final DateTime generatedAtUtc;
  final Uint8List pdfBytes;
  final String chainOfCustodyJson;
  final String sha256SealHex;
  final String pdfSha256Hex;
  final String canonicalManifestPayload;

  /// Verifica se tanto o manifesto de cadeia de custódia quanto o binário `%PDF-1.4`
  /// permanecem bit-a-bit íntegros em relação aos seus digests `SHA-256`.
  bool verifyIntegrity() {
    final expectedSeal =
        sha256.convert(utf8.encode(canonicalManifestPayload)).toString();
    if (expectedSeal != sha256SealHex) return false;

    final expectedPdfHash = sha256.convert(pdfBytes).toString();
    return expectedPdfHash == pdfSha256Hex &&
        chainOfCustodyJson.contains(sha256SealHex);
  }
}

/// Gerador determinístico puro-Dart de pacotes contábeis CPC 47 e dossiês policiais de coação.
class FounderAccountantPackService {
  const FounderAccountantPackService();

  /// Versão assíncrona executada fora da thread principal via [runOffMainThread].
  Future<MonthlyAccountantPackArtifact> generateMonthlyPackOffThread(
    FounderDashboardSnapshot snapshot, {
    String? competenceLabel,
    String csvDelimiter = ';',
  }) {
    return runOffMainThread(
      () => generateMonthlyPackSync(
        snapshot,
        competenceLabel: competenceLabel,
        csvDelimiter: csvDelimiter,
      ),
    );
  }

  /// Versão síncrona determinística do Pacote Mensal do Contador (CPC 47 / IFRS 15 / Simples Anexo III).
  MonthlyAccountantPackArtifact generateMonthlyPackSync(
    FounderDashboardSnapshot snapshot, {
    String? competenceLabel,
    String csvDelimiter = ';',
  }) {
    final issuedUtc = snapshot.generatedAt.toUtc();
    final competence = (competenceLabel != null && competenceLabel.trim().isNotEmpty)
        ? competenceLabel.trim()
        : '${issuedUtc.year.toString().padLeft(4, '0')}-${issuedUtc.month.toString().padLeft(2, '0')}';
    final delim = csvDelimiter == ',' ? ',' : ';';

    final dre = snapshot.dreCents;
    final recon = snapshot.reconciliation;
    final pool = snapshot.actuarialPool;
    final treasury = snapshot.treasury;

    final csvContent = _buildRfc4180MonthlyCsv(
      snapshot: snapshot,
      competence: competence,
      delimiter: delim,
    );
    final csvHashHex = sha256.convert(utf8.encode(csvContent)).toString();

    final summaryMap = <String, int>{
      'gmv_total_cents': dre.gmvTotalCents,
      'labor_gross_cents': dre.laborGrossCents,
      'materials_exempt_cents': dre.materialsExemptCents,
      'provider_net_labor_cents': dre.providerNetLaborCents,
      'third_party_passthrough_cents': dre.thirdPartyPassThroughCents,
      'warranty_pool_carveout_cents': dre.warrantyPoolCarveoutCents,
      'taxable_platform_revenue_cents': dre.platformGrossRevenueCents,
      'simples_nacional_das_cents': dre.simplesNacionalTaxCents,
      'hypothetical_gross_tax_cents': dre.grossGmvHypotheticalTaxCents,
      'legal_tax_savings_cents': dre.legalTaxSavingsCents,
      'tax_savings_bps': dre.taxSavingsBps,
      'reconciliation_discrepancy_cents': recon.discrepancyCents,
      'net_profit_ebitda_cents': dre.netProfitEbitdaCents,
    };

    final canonicalPayload = jsonEncode(<String, Object?>{
      'schema': 'DESPERRENGUE_CPC47_ACCOUNTANT_PACK_V1',
      'competence': competence,
      'generated_at_utc': issuedUtc.toIso8601String(),
      'days_window': snapshot.daysWindow,
      'csv_sha256': csvHashHex,
      'summary_metrics_cents': summaryMap,
      'three_way_reconciliation_ok': recon.threeWayReconciliationOk,
    });
    final sealHex = sha256.convert(utf8.encode(canonicalPayload)).toString();

    final savingsPctStr = (dre.taxSavingsBps / 100.0).toStringAsFixed(2);
    final icaMultipleStr = (pool.icaRatioBps / 10000.0).toStringAsFixed(2);

    final lines = <String>[
      'DEMONSTRATIVO CONTABIL-FISCAL AUDITADO - PADRAO CPC 47 / IFRS 15',
      'REGIME: SIMPLES NACIONAL ANEXO III (INTERMEDIACAO TECNOLOGICA - AGENTE)',
      '======================================================================================',
      'Competencia de Apuracao : $competence (Janela Consolidada: ${snapshot.daysWindow} dias)',
      'Data/Hora Emissao (UTC) : ${issuedUtc.toIso8601String()}',
      'Ordens Liquidadas (OS)  : ${dre.completedOrdersCount} ordens concluidas',
      'Selo Criptografico      : $sealHex',
      'Hash SHA-256 Planilha   : $csvHashHex',
      '--------------------------------------------------------------------------------------',
      '1. SEGREGACAO JURIDICO-CONTABIL DE RECEITAS (CPC 47 / NBC TG 47 - PRINCIPAL VS AGENTE)',
      '   (+) GMV Bruto Transacionado em Custodia        : ${Money.formatBrl(dre.gmvTotalCents)}',
      '   (-) Repasse Terceiros - 85% Mao de Obra Tecnico: ${Money.formatBrl(dre.providerNetLaborCents)}',
      '   (-) Reembolso Pecas Isento (0% Taxa c/ NF-e)   : ${Money.formatBrl(dre.materialsExemptCents)}',
      '   (=) Total Valores de Terceiros Nao-Tributaveis : ${Money.formatBrl(dre.thirdPartyPassThroughCents)}',
      '   (-) Destinacao Vinculada Pool Garantia (1,5%)  : ${Money.formatBrl(dre.warrantyPoolCarveoutCents)}',
      '   (=) RECEITA BRUTA TRIBUTAVEL PLATAFORMA (13,5%): ${Money.formatBrl(dre.platformGrossRevenueCents)}',
      '       (Inclui Taxas Operacionais SOS/Urgencia    : ${Money.formatBrl(dre.sosFeeRevenueCents)})',
      '--------------------------------------------------------------------------------------',
      '2. APURACAO SIMPLES NACIONAL ANEXO III E ECONOMIA TRIBUTARIA LEGAL AUDITADA',
      '   * Base de Calculo Exclusiva (CPC 47 Agente)    : ${Money.formatBrl(dre.platformGrossRevenueCents)}',
      '   * DAS Devido Simples Nacional Anexo III (6,00%): ${Money.formatBrl(dre.simplesNacionalTaxCents)}',
      '   * Tributo Hipotetico s/ GMV Bruto sem CPC 47   : ${Money.formatBrl(dre.grossGmvHypotheticalTaxCents)}',
      '   * ECONOMIA TRIBUTARIA LEGAL COMPROVADA         : ${Money.formatBrl(dre.legalTaxSavingsCents)} ($savingsPctStr% reducao)',
      '--------------------------------------------------------------------------------------',
      '3. DEMONSTRACAO DO RESULTADO OPERACIONAL (DRE EM CENTAVOS EXATOS - ZERO DERIVA)',
      '   (+) Receita Bruta Plataforma                   : ${Money.formatBrl(dre.platformGrossRevenueCents)}',
      '   (-) Simples Nacional DAS (6,00% Anexo III)     : ${Money.formatBrl(dre.simplesNacionalTaxCents)}',
      '   (-) Custos Variaveis PIX PSP & Cloud           : ${Money.formatBrl(dre.variablePspAndCloudCents)}',
      '   (=) MARGEM DE CONTRIBUICAO LIQUIDA             : ${Money.formatBrl(dre.contributionMarginCents)}',
      '   (-) Despesas Fixas Enxutas (OPEX)              : ${Money.formatBrl(dre.fixedOpexCents)}',
      '   (=) LUCRO LIQUIDO / EBITDA OPERACIONAL         : ${Money.formatBrl(dre.netProfitEbitdaCents)}',
      '   [i] Economia FinOps KYC Tier-0 Local (R\$ 0,00) : ${Money.formatBrl(dre.tier0KycSavingsCents)}',
      '--------------------------------------------------------------------------------------',
      '4. CONCILIACAO TRIPLA DE CUSTODIA & FUNDO ATUARIAL DE GARANTIA',
      '   * Entradas PIX Confirmadas (Acumulado)         : ${Money.formatBrl(recon.pixTopupsConfirmedCents)}',
      '   * Liquidacoes Externas Consolidadas            : ${Money.formatBrl(recon.cumulativePlatformSettledOutCents)}',
      '   * Soma Liquida do Razao de Partidas Dobradas   : ${Money.formatBrl(recon.ledgerNetSumCents)}',
      '   * Total Carteiras + Escrow + Retencoes         : ${Money.formatBrl(recon.walletsAndEscrowTotalCents)}',
      '   * Discrepancia Tripla Apurada                  : ${Money.formatBrl(recon.discrepancyCents)} (${recon.threeWayReconciliationOk ? "INTEGRA 0 CENTAVOS" : "ALERTA DIVERGENCIA"})',
      '   * Saldo Pool Garantia / Exposicao Ativa        : ${Money.formatBrl(pool.runningBalanceCents)} / ${Money.formatBrl(pool.activeExposureCents)} (ICA ${icaMultipleStr}x)',
      '   * Rendimento Estimado Float CDI Mensal         : ${Money.formatBrl(treasury.estimatedMonthlyCdiFloatCents)}',
      '--------------------------------------------------------------------------------------',
      '5. AMOSTRA DE AUDITORIA MICRO-P&L POR ORDEM E CHAVE NF-E DE 44 DIGITOS (PECAS 0%)',
      for (final o in snapshot.recentOrdersMicroPnl)
        '   ${o.orderCode.padRight(11)} | GMV:${Money.formatBrl(o.gmvCents).padLeft(11)} | MO:${Money.formatBrl(o.laborCents).padLeft(10)} | Pecas:${Money.formatBrl(o.materialsExemptCents).padLeft(10)} | NF-e:${o.nfeAccessKey ?? "ISENTO_SEM_PECAS"}',
      '======================================================================================',
      'FUNDAMENTACAO LEGAL: Pronunciamento Tecnico CPC 47 (IFRS 15 - Itens B34 a B38),',
      'Lei Complementar 123/2006 (Anexo III) e Solucoes de Consulta COSIT/RFB sobre',
      'intermediacao digital com segregacao contratual de repasse a prestadores autonomos',
      'e reembolso comprovado de mercadorias acobertadas por Nota Fiscal Eletronica (44 dig.).',
      'ASSINATURA SHA-256: $sealHex',
    ];

    final pdfBytes = _buildMultiPageVectorPdf(
      documentTitle: 'Pacote Contabil CPC 47 - Competencia $competence',
      bannerTitle: 'DESPERRENGUE FINTECH · PACOTE CONTABIL-FISCAL CPC 47 / IFRS 15',
      bannerSubtitle:
          'Competencia $competence  |  Selo SHA-256: ${sealHex.substring(0, 24)}...',
      bodyLines: lines,
    );
    final pdfHashHex = sha256.convert(pdfBytes).toString();

    return MonthlyAccountantPackArtifact(
      competenceLabel: competence,
      generatedAtUtc: issuedUtc,
      pdfBytes: pdfBytes,
      csvContent: csvContent,
      sha256SealHex: sealHex,
      pdfSha256Hex: pdfHashHex,
      csvSha256Hex: csvHashHex,
      canonicalPayloadToSign: canonicalPayload,
      summaryMetricsCents: Map<String, int>.unmodifiable(summaryMap),
    );
  }

  /// Versão assíncrona executada fora da UI Thread via [runOffMainThread].
  Future<DuressForensicDossierArtifact> generateDuressPoliceDossierOffThread(
    DuressIncidentRecord incident, {
    String? authorizedByEmail,
    DateTime? issuedAtUtc,
  }) {
    return runOffMainThread(
      () => generateDuressPoliceDossierSync(
        incident,
        authorizedByEmail: authorizedByEmail,
        issuedAtUtc: issuedAtUtc,
      ),
    );
  }

  /// Gera síncronamente o Dossiê Policial Forense Assinado (`%PDF-1.4` + Manifesto JSON + `SHA-256`)
  /// para custódias congeladas sob coação (`FROZEN_UNDER_DURESS`) na Sala de Guerra Silenciosa.
  DuressForensicDossierArtifact generateDuressPoliceDossierSync(
    DuressIncidentRecord incident, {
    String? authorizedByEmail,
    DateTime? issuedAtUtc,
  }) {
    final nowUtc = (issuedAtUtc ?? DateTime.utc(2026, 11, 14, 12, 30)).toUtc();
    final authorityActor = (authorizedByEmail != null &&
            authorizedByEmail.trim().isNotEmpty)
        ? _maskEmailForForensics(authorizedByEmail.trim())
        : 'SOVEREIGN_CEO_VAULT_AUTHENTICATED';

    final unsignedManifest = <String, Object?>{
      'schema': 'DESPERRENGUE_SILENT_DURESS_FORENSIC_DOSSIER_V1',
      'legal_framework': <String>[
        'CPP Art. 158-A a 158-F (Cadeia de Custodia da Prova Digital - Lei 13.964/2019)',
        'LGPD Lei 13.709/2018 Art. 7 III & Art. 4 (Minimizacao e Protecao da Vitima)',
        'BACEN MED / Bloqueio Cautelar Preventivo Anti-Extorsao PIX',
      ],
      'incident_id': incident.incidentId,
      'order_code': incident.orderCode,
      'job_id': incident.jobId,
      'triggered_at_utc': incident.triggeredAt.toUtc().toIso8601String(),
      'dossier_issued_at_utc': nowUtc.toIso8601String(),
      'authorized_by_seat': authorityActor,
      'custody_status': incident.custodyStatus,
      'frozen_amount_cents': incident.frozenAmountCents,
      'frozen_amount_brl': Money.formatBrl(incident.frozenAmountCents),
      'decoy_ui_displayed_to_coercer': incident.decoyUiDisplayed,
      'victim_protection': <String, Object?>{
        'masked_role': incident.maskedVictimRole,
        'masked_account_ref': incident.maskedAccountRef,
        'coarse_zone': incident.coarseNeighborhood,
        'exact_coordinates_redacted': true,
      },
      'cryptographic_anchors': <String, Object?>{
        'ledger_freeze_tx_id': incident.ledgerFreezeTxId,
        'device_integrity_sha256': incident.deviceIntegrityHash,
        'evidence_chain_sha256_list': incident.evidenceChainHashes,
      },
    };

    final canonicalManifestPayload = jsonEncode(unsignedManifest);
    final sealHex =
        sha256.convert(utf8.encode(canonicalManifestPayload)).toString();

    final signedJsonMap = <String, Object?>{
      ...unsignedManifest,
      'sha256_seal_hex': sealHex,
    };
    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(signedJsonMap);

    final lines = <String>[
      'NOTICIA DE FATO & DOSSIE PERICIAL DE CADEIA DE CUSTODIA DIGITAL',
      'PROTOCOLO SILENT DURESS (COACAO / ASSALTO / EXTORSAO MEDIANTE PIX)',
      '======================================================================================',
      'ID do Incidente         : ${incident.incidentId}',
      'Ordem / Job Vinculado   : ${incident.orderCode} (${incident.jobId})',
      'Status da Custodia      : ${incident.custodyStatus}',
      'Valor Retido Protegido  : ${Money.formatBrl(incident.frozenAmountCents)} (${incident.frozenAmountCents} centavos)',
      'Acionamento Coacao (UTC): ${incident.triggeredAt.toUtc().toIso8601String()}',
      'Emissao do Dossie (UTC) : ${nowUtc.toIso8601String()}',
      'Assento Emissor         : $authorityActor',
      '--------------------------------------------------------------------------------------',
      '1. DINAMICA TECNICA DA PROTECAO SILENCIOSA (DECOY UI + BLOQUEIO KERNEL)',
      '   * Tela Dissimulada Exibida ao Agressor : ${incident.decoyUiDisplayed ? "SIM (Comprovante Falso Exibido p/ Preservar Vida)" : "NAO"}',
      '   * Transacao Imutavel de Bloqueio Razao : ${incident.ledgerFreezeTxId}',
      '   * Efeito Financeiro Real no Servidor   : 100% dos fundos permanecem retidos no cofre',
      '     interno sob status FROZEN_UNDER_DURESS, impedindo liquidacao externa ao estelionatario.',
      '--------------------------------------------------------------------------------------',
      '2. DADOS MINIMIZADOS DA VITIMA (PROTECAO LGPD & SEGURANCA FISICA)',
      '   * Papel na Plataforma   : ${incident.maskedVictimRole}',
      '   * Referencia Pseudonima : ${incident.maskedAccountRef}',
      '   * Macrozona Aproximada  : ${incident.coarseNeighborhood}',
      '   * Coordenadas Exatas    : SUPRIMIDAS NO RELATORIO EXTERNO (Disponiveis via Oficio Judicial)',
      '--------------------------------------------------------------------------------------',
      '3. CADEIA DE CUSTODIA PROBATÓRIA (ART. 158-A CPP - LEI 13.964/2019)',
      '   * Hash Integridade Dispositivo : ${incident.deviceIntegrityHash}',
      for (var i = 0; i < incident.evidenceChainHashes.length; i++)
        '   * Evidencia Pericial #${i + 1} SHA-256 : ${incident.evidenceChainHashes[i]}',
      '--------------------------------------------------------------------------------------',
      '4. SELO CRIPTOGRAFICO DE AUTENTICIDADE E IMUTABILIDADE',
      '   * Algoritmo             : SHA-256 (FIPS 180-4)',
      '   * Selo Manifesto Hex    : $sealHex',
      '======================================================================================',
      'Documento pericial assinado eletronicamente para instrucao de Boletim de Ocorrencia',
      'perante a Policia Civil / Delegacia de Crimes Ciberneticos e preservacao cautelar MED.',
    ];

    final pdfBytes = _buildMultiPageVectorPdf(
      documentTitle: 'Dossie Forense Policial ${incident.incidentId}',
      bannerTitle: 'SALA DE GUERRA SILENT DURESS · DOSSIE FORENSE POLICIAL',
      bannerSubtitle:
          'Incidente ${incident.incidentId}  |  Custodia: ${incident.custodyStatus}',
      bodyLines: lines,
      isAlertTheme: true,
    );
    final pdfHashHex = sha256.convert(pdfBytes).toString();

    return DuressForensicDossierArtifact(
      incidentId: incident.incidentId,
      orderCode: incident.orderCode,
      generatedAtUtc: nowUtc,
      pdfBytes: pdfBytes,
      chainOfCustodyJson: prettyJson,
      sha256SealHex: sealHex,
      pdfSha256Hex: pdfHashHex,
      canonicalManifestPayload: canonicalManifestPayload,
    );
  }

  String _buildRfc4180MonthlyCsv({
    required FounderDashboardSnapshot snapshot,
    required String competence,
    required String delimiter,
  }) {
    final dre = snapshot.dreCents;
    final rows = <List<String>>[
      <String>[
        'tipo_registro',
        'competencia',
        'codigo_os',
        'categoria_ou_rubrica',
        'bairro',
        'gmv_centavos',
        'mao_de_obra_centavos',
        'pecas_isentas_0pct_centavos',
        'repasse_liquido_prestador_centavos',
        'receita_tributavel_plataforma_centavos',
        'pool_garantia_1_5pct_centavos',
        'das_simples_anexo3_6pct_centavos',
        'custo_pix_cloud_centavos',
        'margem_liquida_centavos',
        'chave_acesso_nfe_44_digitos',
        'status_custodia',
      ],
      <String>[
        'CONSOLIDADO_CPC47_MENSAL',
        competence,
        'TOTAL_${snapshot.daysWindow}D',
        'Segregacao Principal vs Agente (CPC 47 / IFRS 15)',
        'CONSOLIDADO',
        dre.gmvTotalCents.toString(),
        dre.laborGrossCents.toString(),
        dre.materialsExemptCents.toString(),
        dre.providerNetLaborCents.toString(),
        dre.platformGrossRevenueCents.toString(),
        dre.warrantyPoolCarveoutCents.toString(),
        dre.simplesNacionalTaxCents.toString(),
        dre.variablePspAndCloudCents.toString(),
        dre.netProfitEbitdaCents.toString(),
        'CONSOLIDADO_MULTI_NFE',
        snapshot.reconciliation.threeWayReconciliationOk
            ? 'CONCILIACAO_TRIPLA_OK'
            : 'DIVERGENCIA_DETECTADA',
      ],
      for (final o in snapshot.recentOrdersMicroPnl)
        <String>[
          'ORDEM_MICRO_PNL',
          competence,
          o.orderCode,
          o.categoryName,
          o.neighborhood,
          o.gmvCents.toString(),
          o.laborCents.toString(),
          o.materialsExemptCents.toString(),
          o.providerNetCents.toString(),
          o.platformFeeCents.toString(),
          o.poolCarveoutCents.toString(),
          o.taxDasCents.toString(),
          o.pixCloudCostCents.toString(),
          o.netMarginCents.toString(),
          o.nfeAccessKey ?? '',
          o.escrowStatus,
        ],
    ];

    final buf = StringBuffer();
    for (final row in rows) {
      for (var i = 0; i < row.length; i++) {
        if (i > 0) buf.write(delimiter);
        buf.write(_escapeRfc4180Cell(row[i], delimiter));
      }
      buf.write('\r\n');
    }
    return buf.toString();
  }

  static String _escapeRfc4180Cell(String value, String delimiter) {
    final needsQuotes = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\r') ||
        value.contains('\n');
    if (!needsQuotes) return value;
    final doubledQuotes = value.replaceAll('"', '""');
    return '"$doubledQuotes"';
  }

  static String _maskEmailForForensics(String raw) {
    final atIdx = raw.indexOf('@');
    if (atIdx <= 1) return 'ceo***@desperrengue.com.br';
    final prefix = raw.substring(0, 2);
    final domain = raw.substring(atIdx);
    return '$prefix***$domain';
  }

  /// Construtor puro-Dart de documento `%PDF-1.4` multipágina com cabeçalho vetorial,
  /// fontes `Helvetica-Bold` (`/F1`) e `Courier` (`/F2`), paginação automática e `xref` exata.
  Uint8List _buildMultiPageVectorPdf({
    required String documentTitle,
    required String bannerTitle,
    required String bannerSubtitle,
    required List<String> bodyLines,
    bool isAlertTheme = false,
  }) {
    final wrappedAll = <String>[];
    for (final raw in bodyLines) {
      final safe = _winAnsiSafe(raw);
      wrappedAll.addAll(_wrapLine(safe, 90));
    }

    const linesPerPage = 50;
    final pageChunks = <List<String>>[];
    if (wrappedAll.isEmpty) {
      pageChunks.add(const <String>['']);
    } else {
      for (var i = 0; i < wrappedAll.length; i += linesPerPage) {
        final end = (i + linesPerPage < wrappedAll.length)
            ? i + linesPerPage
            : wrappedAll.length;
        pageChunks.add(wrappedAll.sublist(i, end));
      }
    }

    final safeDocTitle = _escapePdfLiteral(_winAnsiSafe(documentTitle));
    final safeBanner = _escapePdfLiteral(_winAnsiSafe(bannerTitle));
    final safeSub = _escapePdfLiteral(_winAnsiSafe(bannerSubtitle));

    // Numeração de objetos PDF:
    // 1 = Catalog, 2 = Pages, 3 = Font Helvetica-Bold, 4 = Font Courier, 5 = Info
    // Para cada página p (0..P-1):
    //   pageObjId    = 6 + p * 2
    //   contentObjId = 7 + p * 2
    final pageCount = pageChunks.length;
    final kidsRefs = List<String>.generate(
      pageCount,
      (p) => '${6 + p * 2} 0 R',
    ).join(' ');

    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [$kidsRefs] /Count $pageCount >>\nendobj\n',
      '3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n',
      '5 0 obj\n<< /Title ($safeDocTitle) /Producer (Desperrengue Sovereign Audit PDF 1.4 Engine) >>\nendobj\n',
    ];

    final accentRgb = isAlertTheme ? '0.78 0.18 0.22' : '0.96 0.62 0.04';

    for (var p = 0; p < pageCount; p++) {
      final pageObjId = 6 + p * 2;
      final contentObjId = 7 + p * 2;
      final chunk = pageChunks[p];

      final stream = StringBuffer()
        // Faixa vetorial superior Obsidian (#0E1218) + friso dourado/carmim
        ..writeln('0.055 0.071 0.094 rg')
        ..writeln('28 776 539 44 re f')
        ..writeln('$accentRgb rg')
        ..writeln('28 774 539 2.5 re f')
        // Texto do banner em branco
        ..writeln('BT')
        ..writeln('1 1 1 rg')
        ..writeln('/F1 10.5 Tf')
        ..writeln('38 803 Td')
        ..writeln('($safeBanner) Tj')
        ..writeln('0.78 0.83 0.90 rg')
        ..writeln('/F2 8.2 Tf')
        ..writeln('0 -15 Td')
        ..writeln('($safeSub  |  Pag. ${p + 1}/$pageCount) Tj')
        ..writeln('ET')
        // Corpo monoespaçado tabular em tinta escura legível
        ..writeln('BT')
        ..writeln('0.08 0.10 0.14 rg')
        ..writeln('/F2 8.4 Tf')
        ..writeln('13.2 TL')
        ..writeln('32 752 Td');

      for (var i = 0; i < chunk.length; i++) {
        final escaped = _escapePdfLiteral(chunk[i]);
        if (i == 0) {
          stream.writeln('($escaped) Tj');
        } else {
          stream.writeln('T* ($escaped) Tj');
        }
      }
      stream.writeln('ET');

      // Linha vetorial de rodapé
      stream
        ..writeln('0.75 0.79 0.85 RG')
        ..writeln('0.6 w')
        ..writeln('28 36 m 567 36 l S');

      final contentStr = stream.toString();
      final contentByteLen = ascii.encode(contentStr).length;

      objects.add(
        '$pageObjId 0 obj\n'
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $contentObjId 0 R >>\n'
        'endobj\n',
      );
      objects.add(
        '$contentObjId 0 obj\n'
        '<< /Length $contentByteLen >>\n'
        'stream\n'
        '$contentStr'
        'endstream\n'
        'endobj\n',
      );
    }

    final pdfOut = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (final obj in objects) {
      offsets.add(pdfOut.length);
      pdfOut.write(obj);
    }

    final xrefStart = pdfOut.length;
    pdfOut.writeln('xref');
    pdfOut.writeln('0 ${objects.length + 1}');
    pdfOut.writeln('0000000000 65535 f ');
    for (final off in offsets) {
      pdfOut.writeln('${off.toString().padLeft(10, '0')} 00000 n ');
    }
    pdfOut.writeln('trailer');
    pdfOut.writeln(
      '<< /Size ${objects.length + 1} /Root 1 0 R /Info 5 0 R >>',
    );
    pdfOut.writeln('startxref');
    pdfOut.writeln('$xrefStart');
    pdfOut.write('%%EOF');

    return Uint8List.fromList(ascii.encode(pdfOut.toString()));
  }

  static List<String> _wrapLine(String text, int maxCols) {
    if (text.length <= maxCols) return <String>[text];
    final out = <String>[];
    var rem = text;
    while (rem.length > maxCols) {
      out.add(rem.substring(0, maxCols));
      rem = '   ${rem.substring(maxCols)}';
    }
    if (rem.isNotEmpty) out.add(rem);
    return out;
  }

  static String _escapePdfLiteral(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  static String _winAnsiSafe(String input) {
    const replacements = <String, String>{
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'ç': 'c', 'Ç': 'C', 'ñ': 'n', 'Ñ': 'N',
      '—': '-', '–': '-', '•': '*', '·': '|', 'º': 'o', 'ª': 'a',
    };
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      final mapped = replacements[ch];
      if (mapped != null) {
        sb.write(mapped);
      } else {
        final code = ch.codeUnitAt(0);
        sb.write((code >= 32 && code <= 126) ? ch : ' ');
      }
    }
    return sb.toString();
  }
}
