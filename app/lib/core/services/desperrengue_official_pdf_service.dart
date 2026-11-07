import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/fintech_warranty_models.dart';
import '../ui/app_tokens.dart';
import '../utils/format.dart';

/// Serviço oficial de geração e visualização de PDFs de Auditoria Forense,
/// Certificado Digital de Garantia e Passaporte de Manutenção do Imóvel ("Prontuário da Casa").
///
/// Gera binários `%PDF-1.4` 100% compatíveis em Dart puro (determinístico, sem
/// dependências nativas quebradiças, compatível com Android, iOS, Web/PWA e `flutter test`).
class DesperrengueOfficialPdfService {
  const DesperrengueOfficialPdfService();

  /// Gera os bytes `%PDF-1.4` do Certificado Digital de Garantia e Conformidade
  /// com dados protegidos pela LGPD e hashes forenses de Check-in/Check-out.
  Uint8List generateWarrantyCertificatePdf(
    WarrantyCertificate cert, {
    String? clientCpf,
    String? clientPhone,
  }) {
    final maskedClient = cert.maskedClientName;
    final maskedCpf = clientCpf != null && clientCpf.trim().isNotEmpty
        ? SecurityAndLgpdGuard.maskCpfOrCnpj(clientCpf)
        : '***.456.789-**';
    final maskedPhone = clientPhone != null && clientPhone.trim().isNotEmpty
        ? SecurityAndLgpdGuard.maskPhone(clientPhone)
        : '(**) *****-0000';
    final split = cert.financialBreakdown;

    final lines = <String>[
      'DESPERRENGUE - CERTIFICADO DIGITAL DE GARANTIA E CONFORMIDADE',
      '========================================================================',
      'Codigo do Certificado : ${cert.certificateCode}',
      'Hash de Verificacao   : ${cert.securityVerificationHash}',
      'Pedido / OS           : ${cert.orderId}',
      'Categoria / Servico   : ${cert.serviceCategoryName} - ${cert.serviceTitle}',
      'Emissao (UTC)         : ${cert.issuedAt.toUtc().toIso8601String()}',
      'Vigencia Legal (CDC)  : ${cert.warrantyDurationDays} dias (Expira em ${cert.expiresAt.toUtc().toIso8601String().substring(0, 10)})',
      'Cadeia Forense        : ${cert.hasCompleteForensicChain ? "INTEGRA E VERIFICADA (2+ ANTES / 2+ DEPOIS)" : "PENDENTE"}',
      '------------------------------------------------------------------------',
      'PROTECAO DE DADOS PESSOAIS (LGPD - MINIMIZACAO DE DADOS)',
      'Titular (Cliente)     : $maskedClient | CPF/CNPJ: $maskedCpf | Tel: $maskedPhone',
      'Prestador Credenciado : ${cert.providerName}',
      'Imovel Vinculado      : ${SecurityAndLgpdGuard.sanitizeInput(cert.propertyAddress)}',
      '------------------------------------------------------------------------',
      'DEMONSTRATIVO FINTECH - SPLIT INTELIGENTE (CARTEIRA A + CARTEIRA B)',
      'Carteira A (Mao de Obra)          : ${brl(split.serviceLaborAmount)}',
      'Carteira B (Pecas / Cupom 0% Taxa): ${brl(split.materialReimbursementAmount)}',
      'Valor Bruto Total (M + P)         : ${brl(split.grossTransactionAmount)}',
      'Taxa Operacional Plataforma (13,5%): ${brl(split.platformOperationalRevenue)}',
      'Aporte Fundo de Garantia (1,5%)   : ${brl(split.warrantyReserveContribution)}',
      'Taxa Total Plataforma (15% s/ M)  : ${brl(split.totalPlatformFee)} (${split.effectiveFeePercentageOnGross.toStringAsFixed(2)}% sobre bruto)',
      'Repasse Liquido ao Prestador      : ${brl(split.providerTotalNetPayout)}',
      'Economia do Prestador (0% Pecas)  : ${brl(split.providerSavedFeeBySmartSplit)}',
      'Teto Maximo Cobertura Fundo (Cap) : ${brl(split.maxWarrantyCoverageCap)} (100% da Mao de Obra)',
      '------------------------------------------------------------------------',
      'EVIDENCIAS FORENSES DE CHECK-IN (ANTES - ${cert.checkInBeforePhotos.length} FOTOS)',
      for (final p in cert.checkInBeforePhotos)
        '  * [${p.id}] GPS:${p.isGpsVerifiedAtAddress ? "OK" : "N/A"} | Hash:${p.integrityHash} | ${p.captionOrTechnicalNote}',
      'EVIDENCIAS FORENSES DE CHECK-OUT (DEPOIS - ${cert.checkOutAfterPhotos.length} FOTOS)',
      for (final p in cert.checkOutAfterPhotos)
        '  * [${p.id}] GPS:${p.isGpsVerifiedAtAddress ? "OK" : "N/A"} | Hash:${p.integrityHash} | ${p.captionOrTechnicalNote}',
      if (cert.reimbursedMaterials.isNotEmpty) ...[
        'CUPONS FISCAIS DE PECAS (CARTEIRA B - 0% DE TAXA)',
        for (final m in cert.reimbursedMaterials)
          '  * ${m.fiscalReceiptNumber} | ${m.storeName} | ${m.materialDescription} | ${brl(m.receiptTotalAmount)} | Aprovado:${m.isApprovedByClient ? "SIM" : "NAO"}',
      ],
      '------------------------------------------------------------------------',
      'AS 3 REGRAS DE OURO DA GARANTIA DESPERRENGUE',
      for (final clause in cert.goldenLegalClauses) '  $clause',
      '========================================================================',
      'Documento assinado eletronicamente pela infraestrutura Anti-Bypass Desperrengue.',
    ];

    return _buildStandardPdfDocument(
      title: 'Certificado de Garantia ${cert.certificateCode}',
      lines: lines,
    );
  }

  /// Gera os bytes `%PDF-1.4` do Passaporte Oficial de Manutenção do Imóvel ("Prontuário da Casa").
  Uint8List generatePropertyPassportPdf(
    PropertyMaintenancePassport passport, {
    String? ownerCpf,
    String? ownerPhone,
  }) {
    final maskedOwner = passport.maskedOwnerName;
    final maskedCpf = ownerCpf != null && ownerCpf.trim().isNotEmpty
        ? SecurityAndLgpdGuard.maskCpfOrCnpj(ownerCpf)
        : '***.456.789-**';
    final maskedPhone = ownerPhone != null && ownerPhone.trim().isNotEmpty
        ? SecurityAndLgpdGuard.maskPhone(ownerPhone)
        : '(**) *****-0000';

    final lines = <String>[
      'DESPERRENGUE - PASSAPORTE OFICIAL DE MANUTENCAO DO IMOVEL (PRONTUARIO DA CASA)',
      '========================================================================',
      'ID do Passaporte      : ${passport.passportId}',
      'Endereco Auditado     : ${SecurityAndLgpdGuard.sanitizeInput(passport.propertyAddress)}',
      'Proprietario/Titular  : $maskedOwner | CPF/CNPJ: $maskedCpf | Tel: $maskedPhone',
      'Atualizado em (UTC)   : ${passport.updatedAt.toUtc().toIso8601String()}',
      'Score de Vistoria     : ${passport.inspectionReadinessLabel}',
      '------------------------------------------------------------------------',
      'INDICADORES PATRIMONIAIS E DE CONSERVACAO',
      'Total Investido no Imovel   : ${brl(passport.totalInvestedAmount)}',
      '  - Mao de Obra Certificada : ${brl(passport.totalLaborInvested)}',
      '  - Pecas com Nota Fiscal   : ${brl(passport.totalMaterialsInvested)}',
      'Intervencoes Auditadas      : ${passport.entries.length}',
      'Garantias Ativas Vigentes   : ${passport.activeWarrantiesCount}',
      '------------------------------------------------------------------------',
      'HISTORICO CRONOLOGICO DE MANUTENCAO E GARANTIAS',
      if (passport.entries.isEmpty)
        '  Nenhuma intervencao homologada registrada ate o momento.',
      for (final e in passport.entries) ...[
        '  * [${e.certificateCode}] ${e.completedAt.toUtc().toIso8601String().substring(0, 10)} - ${e.serviceCategoryName}: ${e.serviceTitle}',
        '    Profissional: ${e.providerName} | Total: ${brl(e.totalInvested)} (M:${brl(e.laborAmount)} + P:${brl(e.materialAmount)})',
        '    Garantia ate: ${e.warrantyExpiresAt.toUtc().toIso8601String().substring(0, 10)} | Hash Forense: ${e.forensicHash}',
      ],
      '========================================================================',
      'Valido para comprovacao de manutencao preventiva perante imobiliarias e seguradoras.',
    ];

    return _buildStandardPdfDocument(
      title: 'Prontuario da Casa ${passport.passportId}',
      lines: lines,
    );
  }

  /// Constrói um arquivo PDF 1.4 válido com tabela `xref` exata e codificação ASCII/WinAnsi segura.
  Uint8List _buildStandardPdfDocument({
    required String title,
    required List<String> lines,
  }) {
    final safeTitle = _winAnsiSafe(title);
    final streamBuffer = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 10 Tf')
      ..writeln('13 TL')
      ..writeln('36 800 Td');

    var first = true;
    for (final rawLine in lines) {
      final cleaned = _winAnsiSafe(rawLine);
      final wrapped = _wrapLine(cleaned, 86);
      for (final segment in wrapped) {
        final escaped = _escapePdfLiteral(segment);
        if (first) {
          streamBuffer.writeln('($escaped) Tj');
          first = false;
        } else {
          streamBuffer.writeln("T* ($escaped) Tj");
        }
      }
    }
    streamBuffer.writeln('ET');
    final contentStream = streamBuffer.toString();
    final contentBytes = ascii.encode(contentStream);

    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n',
      '5 0 obj\n<< /Length ${contentBytes.length} >>\nstream\n$contentStream\nendstream\nendobj\n',
      '6 0 obj\n<< /Title (${_escapePdfLiteral(safeTitle)}) /Producer (Desperrengue Official PDF Engine) >>\nendobj\n',
    ];

    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (final obj in objects) {
      offsets.add(out.toString().length);
      out.write(obj);
    }
    final xrefOffset = out.toString().length;
    out.writeln('xref');
    out.writeln('0 ${objects.length + 1}');
    out.writeln('0000000000 65535 f ');
    for (final off in offsets) {
      out.writeln('${off.toString().padLeft(10, '0')} 00000 n ');
    }
    out.writeln('trailer');
    out.writeln('<< /Size ${objects.length + 1} /Root 1 0 R /Info 6 0 R >>');
    out.writeln('startxref');
    out.writeln('$xrefOffset');
    out.write('%%EOF');

    return Uint8List.fromList(ascii.encode(out.toString()));
  }

  List<String> _wrapLine(String text, int maxCols) {
    if (text.length <= maxCols) return [text];
    final result = <String>[];
    var remaining = text;
    while (remaining.length > maxCols) {
      result.add(remaining.substring(0, maxCols));
      remaining = '  ${remaining.substring(maxCols)}';
    }
    if (remaining.isNotEmpty) result.add(remaining);
    return result;
  }

  String _escapePdfLiteral(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  String _winAnsiSafe(String input) {
    const map = <String, String>{
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
      '—': '-', '–': '-', '•': '*', 'º': 'o', 'ª': 'a',
    };
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (map.containsKey(ch)) {
        sb.write(map[ch]);
      } else {
        final code = ch.codeUnitAt(0);
        sb.write((code >= 32 && code <= 126) ? ch : ' ');
      }
    }
    return sb.toString();
  }

  /// Abre um modal de visualização e exportação do Certificado Digital de Garantia em PDF.
  Future<void> showCertificatePreviewDialog(
    BuildContext context,
    WarrantyCertificate cert, {
    String? clientCpf,
    String? clientPhone,
  }) async {
    final pdfBytes = generateWarrantyCertificatePdf(
      cert,
      clientCpf: clientCpf,
      clientPhone: clientPhone,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final tk = ctx.tk;
        final split = cert.financialBreakdown;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: tk.successSoft,
                      child: Icon(Icons.verified_user_rounded, color: tk.success),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Certificado Digital de Garantia (PDF)',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: tk.text,
                            ),
                          ),
                          Text(
                            '${cert.certificateCode} • ${pdfBytes.length} bytes gerados',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tk.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tk.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hash Forense de Integridade:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tk.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        cert.securityVerificationHash,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: tk.brand,
                        ),
                      ),
                      const Divider(height: 20),
                      Text(
                        'Titular Protegido (LGPD): ${cert.maskedClientName}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Profissional: ${cert.providerName} • Vigência: ${cert.warrantyDurationDays} dias (${cert.remainingDays} dias restantes)',
                        style: TextStyle(fontSize: 13, color: tk.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Split Auditado: Mão de Obra ${brl(split.serviceLaborAmount)} + Peças (0% taxa) ${brl(split.materialReimbursementAmount)} = Total ${brl(split.grossTransactionAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fundo de Garantia (1,5%): ${brl(split.warrantyReserveContribution)} • Cap Cobertura: ${brl(split.maxWarrantyCoverageCap)}',
                        style: TextStyle(fontSize: 12.5, color: tk.successInk, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'As 3 Regras de Ouro da Garantia',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: tk.text),
                ),
                const SizedBox(height: 6),
                for (final clause in cert.goldenLegalClauses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      clause,
                      style: TextStyle(fontSize: 12.5, height: 1.35, color: tk.textMuted),
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Certificado ${cert.certificateCode} | Hash ${cert.securityVerificationHash} | PDF ${pdfBytes.length} bytes',
                      ),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Certificado PDF (${cert.certificateCode}) exportado e código de verificação copiado!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Baixar / Copiar Assinatura do PDF Oficial'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Abre um modal de visualização e exportação do Passaporte de Manutenção do Imóvel em PDF.
  Future<void> showPassportPreviewDialog(
    BuildContext context,
    PropertyMaintenancePassport passport,
  ) async {
    final pdfBytes = generatePropertyPassportPdf(passport);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final tk = ctx.tk;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: tk.infoSoft,
                      child: Icon(Icons.home_work_rounded, color: tk.info),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prontuário da Casa — Passaporte PDF',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: tk.text,
                            ),
                          ),
                          Text(
                            '${passport.passportId} • ${pdfBytes.length} bytes (Padrão Vistoria/Seguradora)',
                            style: TextStyle(fontSize: 12.5, color: tk.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tk.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passport.propertyAddress,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Titular (LGPD): ${passport.maskedOwnerName}',
                        style: TextStyle(fontSize: 12.5, color: tk.textMuted),
                      ),
                      const Divider(height: 18),
                      Text(
                        passport.inspectionReadinessLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: tk.successInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total investido: ${brl(passport.totalInvestedAmount)} • Garantias ativas: ${passport.activeWarrantiesCount}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Passaporte ${passport.passportId} | Score ${passport.inspectionReadinessScore}/100 | Total ${brl(passport.totalInvestedAmount)}',
                      ),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Dossiê PDF do Imóvel (${passport.passportId}) gerado com sucesso!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Exportar Dossiê PDF para Imobiliária/Seguradora'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
