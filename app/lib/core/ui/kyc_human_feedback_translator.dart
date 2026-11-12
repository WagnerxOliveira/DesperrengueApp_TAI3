/// Tradutor e Sanitizador Determinístico de Feedback Humano (Zero Jargão Técnico).
///
/// Garante que o usuário final (Cliente ou Profissional) jamais veja códigos crus
/// de erro (`ERR_...`, `StateError`) ou siglas matemáticas/criptográficas
/// (`SHAP`, `ASN.1`, `VIO`, `YCbCr`, `EAR`, `Yaw`, `dHash`, `MAD`, `mTLS`,
/// `Tier-0`, `Tier-1`, `Laplaciano`, `Mod 11`, `MRZ`, `ICAO`, `ROI`, `pHash`).
class KycHumanFeedbackTranslator {
  KycHumanFeedbackTranslator._();

  /// Lista normativa de termos técnicos estritamente proibidos na camada de UI.
  static const List<String> prohibitedJargonTokens = <String>[
    'SHAP',
    'ASN.1',
    'VIO',
    'YCbCr',
    'EAR',
    'Yaw',
    'dHash',
    'MAD',
    'mTLS',
    'Tier-0',
    'Tier-1',
    'Laplaciano',
    'Laplaciana',
    'Mod 11',
    'Mod-11',
    'Módulo 11',
    'Modulo 11',
    'MRZ',
    'ICAO',
    'ROI',
    'pHash',
    'Hamming',
    'SERPRO',
    'PKCS#7',
    'ECDSA',
  ];

  static final List<RegExp> _prohibitedPatterns = <RegExp>[
    RegExp(r'\bERR_[A-Z0-9_]+\b', caseSensitive: false),
    RegExp(r'\bBad state:\s*', caseSensitive: false),
    RegExp(r'\bStateError\b', caseSensitive: false),
    RegExp(r'\bSHAP\b', caseSensitive: false),
    RegExp(r'ASN\.1', caseSensitive: false),
    RegExp(r'\bVIO\b', caseSensitive: false),
    RegExp(r'\bYCbCr\b', caseSensitive: false),
    RegExp(r'\bEAR\b', caseSensitive: false),
    RegExp(r'\bYaw\b', caseSensitive: false),
    RegExp(r'\bdHash\b', caseSensitive: false),
    RegExp(r'\bpHash\b', caseSensitive: false),
    RegExp(r'\bMAD\b', caseSensitive: false),
    RegExp(r'\bmTLS\b', caseSensitive: false),
    RegExp(r'\bTier-[012]\b', caseSensitive: false),
    RegExp(r'Laplacian[oa]s?', caseSensitive: false),
    RegExp(r'M[oó]d(?:ulo)?[\s\-]*1[01]\b', caseSensitive: false),
    RegExp(r'\bMRZ\b', caseSensitive: false),
    RegExp(r'\bICAO\b', caseSensitive: false),
    RegExp(r'\bROI\b', caseSensitive: false),
    RegExp(r'\bHamming\b', caseSensitive: false),
    RegExp(r'\bSERPRO\b', caseSensitive: false),
    RegExp(r'PKCS#7', caseSensitive: false),
    RegExp(r'\bECDSA\b', caseSensitive: false),
  ];

  /// Verifica se um texto contém qualquer jargão técnico proibido ou código `ERR_`.
  static bool containsBannedTechnicalJargon(String text) {
    if (text.trim().isEmpty) return false;
    for (final pattern in _prohibitedPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  /// Converte qualquer exceção, código de erro ou diagnóstico em uma orientação
  /// curta, gentil, clara e imediatamente acionável em português.
  static String translateError(Object? errorOrMessage) {
    final raw = (errorOrMessage ?? '').toString().trim();
    if (raw.isEmpty) {
      return 'Não foi possível concluir a leitura agora. Posicione o documento em um local bem iluminado e tente novamente.';
    }

    final upper = raw.toUpperCase();

    if (upper.contains('ERR_EXCESSIVE_GLARE') ||
        upper.contains('GLARE') ||
        upper.contains('REFLEXO ESPECULAR')) {
      return 'Havia um pequeno reflexo de luz sobre a foto do documento. Incline levemente o cartão em um local bem iluminado para capturar com nitidez.';
    }

    if (upper.contains('ERR_BLURRY_DOCUMENT_IMAGE') ||
        upper.contains('LAPLACIAN') ||
        upper.contains('DESFOCADA') ||
        upper.contains('NITIDEZ')) {
      return 'A imagem ficou um pouco desfocada. Apoie o documento sobre uma superfície firme, aguarde a câmera focar e capture novamente.';
    }

    if (upper.contains('ERR_DUPLICATE_FRONT_BACK_PHOTO') ||
        upper.contains('IDÊNTICA À FOTO DA FRENTE') ||
        upper.contains('MESMA FACE DO DOCUMENTO')) {
      return 'Percebemos que o mesmo lado do documento foi fotografado duas vezes. Agora vire o documento e fotografe o outro lado.';
    }

    if (upper.contains('ERR_NO_HUMAN_FACE_IN_OVAL') ||
        upper.contains('NENHUM ROSTO HUMANO') ||
        upper.contains('BLUE_MONITOR') ||
        upper.contains('REPLAY')) {
      return 'Não conseguimos identificar seu rosto com clareza na moldura oval. Posicione seu rosto de frente para a câmera em um ambiente bem iluminado, sem usar fotos ou telas.';
    }

    if (upper.contains('ERR_LIVENESS_BLINK_NOT_DETECTED') ||
        upper.contains('PISCADA NATURAL') ||
        upper.contains('BLINK')) {
      return 'Quase lá! Pisque os olhos de forma natural olhando para a câmera para concluirmos a confirmação facial.';
    }

    if (upper.contains('ERR_LIVENESS_YAW_NOT_DETECTED') ||
        upper.contains('ROTAÇÃO HORIZONTAL') ||
        upper.contains('YAW')) {
      return 'Para concluir a confirmação ao vivo, gire levemente a cabeça para a esquerda e para a direita dentro da moldura oval.';
    }

    if (upper.contains('ERR_LIVENESS_LUMINANCE_OUT_OF_RANGE') ||
        upper.contains('ILUMINAÇÃO INADEQUADA') ||
        upper.contains('INSUFFICIENT_FRAMES')) {
      return 'A iluminação do ambiente está muito baixa ou intensa demais. Procure um local com luz suave de frente para o seu rosto e tente novamente.';
    }

    if (upper.contains('ERR_FACE_MISMATCH') ||
        upper.contains('NÃO CORRESPONDE AO ROSTO')) {
      return 'A foto do documento parece pouco visível para compararmos com a sua confirmação facial. Limpe a lente da câmera e fotografe a frente do documento mais de perto.';
    }

    if (upper.contains('ERR_MISSING_OFFICIAL_HEADER') ||
        upper.contains('CABEÇALHO OFICIAL')) {
      return 'Não conseguimos identificar um documento oficial completo na foto. Encaixe o RG, CIN, CNH ou Passaporte inteiramente dentro da guia luminosa.';
    }

    if (upper.contains('ERR_INVALID_MRZ_OR_QR') ||
        upper.contains('MRZ') ||
        upper.contains('ICAO')) {
      return 'A parte de leitura do verso do documento não ficou totalmente visível. Fotografe o verso completo sobre uma mesa bem iluminada, sem cortar as bordas.';
    }

    if (upper.contains('ERR_OCR_INVALID_CPF') ||
        upper.contains('ERR_INVALID_TYPED_CPF_MOD11') ||
        upper.contains('DÍGITO VERIFICADOR DO CPF INVÁLIDO')) {
      return 'O número de CPF informado parece conter um dígito incorreto. Confira os 11 números do seu documento e tente novamente.';
    }

    if (upper.contains('ERR_CPF_OCR_MISMATCH') ||
        upper.contains('DIVERGE DO CPF INFORMADO')) {
      return 'O CPF lido no documento é diferente do CPF digitado no cadastro. Confira se o documento fotografado pertence ao titular da conta.';
    }

    if (upper.contains('ERR_NAME_OCR_MISMATCH') ||
        upper.contains('DIVERGE DO NOME CADASTRADO')) {
      return 'O nome identificado no documento não coincide com o nome informado no cadastro. Verifique se digitou seu nome completo corretamente.';
    }

    if (upper.contains('ERR_GALLERY_UPLOAD_BLOCKED') ||
        upper.contains('GALERIA')) {
      return 'Para sua proteção, utilize a câmera ao vivo para fotografar o documento no momento da verificação.';
    }

    if (upper.contains('ERR_VIRTUAL_CAMERA_DETECTED') ||
        upper.contains('CÂMERA VIRTUAL') ||
        upper.contains('VIRTUALCAM')) {
      return 'Detectamos um aplicativo de câmera virtual ativo. Selecione a câmera física principal do seu aparelho para continuar com segurança.';
    }

    if (upper.contains('ERR_SESSION_EXPIRED_OR_SWAP') ||
        upper.contains('ERR_CANONICAL_SELFIE_SWAP_DETECTED') ||
        upper.contains('ERR_REQUEST_HASH_MISMATCH') ||
        upper.contains('EXPIROU')) {
      return 'Por segurança, o tempo desta etapa expirou. Renovamos sua sessão automaticamente para você concluir a captura com tranquilidade.';
    }

    if (upper.contains('ERR_EMPTY_DOCUMENT_BYTES') ||
        upper.contains('ERR_UNREADABLE_DOCUMENT_IMAGE')) {
      return 'Não conseguimos abrir a imagem capturada. Fotografe novamente mantendo o aparelho firme por um instante.';
    }

    return sanitizeForHumanDisplay(raw);
  }

  /// Traduz fatores técnicos de explicabilidade (SHAP / telemetria óptica)
  /// em orientações humanas claras e sem siglas técnicas.
  static List<String> translateShapFactors(Iterable<String> rawFactors) {
    final results = <String>[];
    for (final factor in rawFactors) {
      final lower = factor.trim().toLowerCase();
      if (lower.isEmpty) continue;
      String translated;
      if (lower.contains('glare') || lower.contains('reflexo')) {
        translated =
            'Incline levemente o documento para evitar o brilho direto da lâmpada sobre o plástico.';
      } else if (lower.contains('laplacian') ||
          lower.contains('blur') ||
          lower.contains('nitidez')) {
        translated =
            'Apoie o documento em uma mesa firme e aguarde o foco automático antes de capturar.';
      } else if (lower.contains('dhash') ||
          lower.contains('mad') ||
          lower.contains('duplicate') ||
          lower.contains('verso')) {
        translated =
            'Certifique-se de fotografar a frente na primeira etapa e o verso na segunda etapa.';
      } else if (lower.contains('ear') ||
          lower.contains('blink') ||
          lower.contains('piscada')) {
        translated =
            'Pisque os olhos naturalmente mantendo o rosto centralizado na moldura.';
      } else if (lower.contains('yaw') || lower.contains('rotação')) {
        translated =
            'Movimente suavemente o rosto para os lados quando solicitado na tela.';
      } else if (lower.contains('mrz') ||
          lower.contains('icao') ||
          lower.contains('qr')) {
        translated =
            'Mantenha todas as bordas e códigos do verso visíveis dentro da moldura.';
      } else if (lower.contains('mtls') ||
          lower.contains('serpro') ||
          lower.contains('homologation')) {
        translated =
            'Verificação concluída com proteção local dos seus dados pessoais.';
      } else {
        translated = sanitizeForHumanDisplay(factor);
      }

      if (!results.contains(translated)) {
        results.add(translated);
      }
    }
    return results;
  }

  /// Sanitiza qualquer string arbitrária garantindo que nenhum termo técnico
  /// proibido sobreviva até a camada visual.
  static String sanitizeForHumanDisplay(String input) {
    var cleaned = input
        .replaceAll(RegExp(r'\bBad state:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bStateError:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bERR_[A-Z0-9_]+:?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bSHAP\b', caseSensitive: false), 'análise visual')
        .replaceAll(RegExp(r'ASN\.1', caseSensitive: false), 'assinatura digital')
        .replaceAll(RegExp(r'\bVIO\b', caseSensitive: false), 'código seguro')
        .replaceAll(RegExp(r'\bYCbCr\b', caseSensitive: false), 'iluminação natural')
        .replaceAll(RegExp(r'\bEAR\b', caseSensitive: false), 'piscada natural')
        .replaceAll(RegExp(r'\bYaw\b', caseSensitive: false), 'movimento lateral')
        .replaceAll(RegExp(r'\bdHash\b', caseSensitive: false), 'comparação visual')
        .replaceAll(RegExp(r'\bpHash\b', caseSensitive: false), 'comparação visual')
        .replaceAll(RegExp(r'\bMAD\b', caseSensitive: false), 'diferença de imagem')
        .replaceAll(RegExp(r'\bmTLS\b', caseSensitive: false), 'conexão segura')
        .replaceAll(RegExp(r'\bTier-[012]\b', caseSensitive: false), 'verificação rápida')
        .replaceAll(RegExp(r'Laplacian[oa]s?', caseSensitive: false), 'nitidez')
        .replaceAll(
          RegExp(r'\(?M[oó]d(?:ulo)?[\s\-]*1[01]\s*(?:RFB)?\)?', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\bMRZ\b', caseSensitive: false), 'faixa de leitura')
        .replaceAll(RegExp(r'\bICAO\b', caseSensitive: false), 'padrão oficial')
        .replaceAll(RegExp(r'\bROI\b', caseSensitive: false), 'área central')
        .replaceAll(RegExp(r'\bHamming\b', caseSensitive: false), 'semelhança')
        .replaceAll(RegExp(r'\bSERPRO\b', caseSensitive: false), 'base oficial')
        .replaceAll(RegExp(r'PKCS#7', caseSensitive: false), 'assinatura digital')
        .replaceAll(RegExp(r'\bECDSA\b', caseSensitive: false), 'chave oficial')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (cleaned.isEmpty || containsBannedTechnicalJargon(cleaned)) {
      return 'Ajuste o enquadramento do documento em um local bem iluminado e tente novamente.';
    }
    return cleaned;
  }

  /// Formata o CPF com máscara de privacidade Quiet Luxury (`***.456.789-**`)
  /// ou no formato completo (`123.456.789-01`) para conferência do titular.
  static String formatCpfQuietLuxury(String rawCpf, {bool masked = true}) {
    final digits = rawCpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      return masked ? '***.***.***-**' : rawCpf;
    }
    if (masked) {
      return '***.${digits.substring(3, 6)}.${digits.substring(6, 9)}-**';
    }
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9, 11)}';
  }
}
