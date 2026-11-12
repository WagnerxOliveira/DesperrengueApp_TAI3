import 'package:flutter/foundation.dart';

import 'scheduling_models.dart';

/// Endereço estruturado imutável de altíssima precisão para ordens de serviço.
///
/// Garante por contrato que `streetName`, `houseNumber`, `neighborhood`, `city` e `uf`
/// informados pelo cliente jamais sejam apagados ou sobrescritos por respostas
/// parciais/incompletas de geocodificadores externos (OSM/Nominatim/Photon).
@immutable
class StructuredServiceAddress {
  const StructuredServiceAddress({
    this.streetName = '',
    this.houseNumber = '',
    this.complement = '',
    this.neighborhood = '',
    this.city = '',
    this.uf = '',
    this.cep = '',
    this.referencePoint = '',
    this.latitude,
    this.longitude,
    this.precision = DestinationPrecision.street,
    this.pinConfirmed = false,
  });

  final String streetName;
  final String houseNumber;
  final String complement;
  final String neighborhood;
  final String city;
  final String uf;
  final String cep;
  final String referencePoint;
  final double? latitude;
  final double? longitude;
  final DestinationPrecision precision;
  final bool pinConfirmed;

  static final RegExp _cepRegex = RegExp(
    r'(?:cep[:\s]*)?(\d{5})-?(\d{3})\b',
    caseSensitive: false,
  );
  static final RegExp _ufTokenRegex = RegExp(r'^[A-Za-z]{2}$');
  static final RegExp _citySlashUfRegex = RegExp(r'^(.+?)\s*/\s*([A-Za-z]{2})$');
  static final RegExp _snRegex = RegExp(
    r'^(?:s\s*/?\s*n\.?|sem\s+n[uú]mero)$',
    caseSensitive: false,
  );
  static final RegExp _numberWithOptionalCompRegex = RegExp(
    r'^(?:n[º°o.]?\s*)?(\d+[A-Za-z]?(?:-[A-Za-z0-9]+)?)(?:\s*[,/-]?\s+(.+))?$',
    caseSensitive: false,
  );
  static final RegExp _trailingStreetNumberRegex = RegExp(
    r'^(.+?)\s+(?:n[º°o.]?\s*)?(\d+[A-Za-z]?|S/N|s/n)$',
  );

  /// Extrai sem erros todos os formatos brasileiros reais de endereço, preservando
  /// logradouro, número exato (`"200"`, `"203"`, `"S/N"`, `"120A"`), complemento,
  /// bairro, cidade, UF, CEP e ponto de referência.
  factory StructuredServiceAddress.parse(
    String rawAddressLine, {
    String? summary,
    String? cep,
    String? referencePoint,
    double? latitude,
    double? longitude,
    DestinationPrecision precision = DestinationPrecision.street,
    bool pinConfirmed = false,
  }) {
    var extractedRef = (referencePoint ?? '').trim();
    var workingLine = rawAddressLine.trim();

    if (workingLine.contains('|')) {
      final pipeSegments = workingLine.split('|');
      workingLine = pipeSegments.first.trim();
      if (extractedRef.isEmpty && pipeSegments.length > 1) {
        final tail = pipeSegments.sublist(1).join(' | ').trim();
        extractedRef = tail
            .replaceFirst(RegExp(r'^ref(?:\.|er[êe]ncia)?[:\s]*', caseSensitive: false), '')
            .trim();
      }
    }

    var workingSummary = (summary ?? '').split('|').first.trim();

    var extractedCep = _normalizeCep(cep);
    final lineCepMatch = _cepRegex.firstMatch(workingLine);
    if (lineCepMatch != null) {
      if (extractedCep.isEmpty) {
        extractedCep = '${lineCepMatch.group(1)}-${lineCepMatch.group(2)}';
      }
      workingLine = workingLine
          .replaceRange(lineCepMatch.start, lineCepMatch.end, '')
          .replaceAll(RegExp(r'\s*,\s*,+'), ', ')
          .replaceAll(RegExp(r'[\s,-]+$'), '')
          .trim();
    }

    if (extractedCep.isEmpty && workingSummary.isNotEmpty) {
      final summaryCepMatch = _cepRegex.firstMatch(workingSummary);
      if (summaryCepMatch != null) {
        extractedCep = '${summaryCepMatch.group(1)}-${summaryCepMatch.group(2)}';
        workingSummary = workingSummary
            .replaceRange(summaryCepMatch.start, summaryCepMatch.end, '')
            .replaceAll(RegExp(r'[\s,-]+$'), '')
            .trim();
      }
    }

    final blocks = workingLine
        .split(RegExp(r'\s+[–—-]\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    var street = '';
    var number = '';
    var comp = '';
    var hood = '';
    var city = '';
    var uf = '';

    void assignCityAndOptionalUf(String rawCityToken) {
      final trimmed = rawCityToken.trim();
      if (trimmed.isEmpty) return;
      final slashMatch = _citySlashUfRegex.firstMatch(trimmed);
      if (slashMatch != null) {
        city = slashMatch.group(1)!.trim();
        if (uf.isEmpty) uf = slashMatch.group(2)!.toUpperCase();
      } else {
        city = trimmed;
      }
    }

    if (blocks.isNotEmpty) {
      // Se o último bloco for UF ("MG"), destaca-o para simplificar os blocos anteriores.
      var effectiveBlocks = List<String>.from(blocks);
      if (effectiveBlocks.length >= 2 && _isUf(effectiveBlocks.last)) {
        uf = effectiveBlocks.removeLast().toUpperCase();
      }

      if (effectiveBlocks.length >= 3) {
        // Ex.: ["Rua X, 203", "Maria Imaculada", "Poços de Caldas"] (com UF já destacada)
        final parsedStreet = _parseStreetBlock(effectiveBlocks.first);
        street = parsedStreet.street;
        number = parsedStreet.number;
        comp = parsedStreet.complement;
        hood = effectiveBlocks[1];
        assignCityAndOptionalUf(effectiveBlocks[2]);
      } else if (effectiveBlocks.length == 2) {
        // Ex.: ["Travessa Pedro de Castro Souza, 200", "Country Club, Poços de Caldas"]
        // ou ["Rua Padre José Geraldi, 203", "Maria Imaculada"] (com summary contendo Cidade - UF)
        final parsedStreet = _parseStreetBlock(effectiveBlocks.first);
        street = parsedStreet.street;
        number = parsedStreet.number;
        comp = parsedStreet.complement;

        final placeBits = effectiveBlocks[1]
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (placeBits.length >= 2) {
          if (_isUf(placeBits.last) && uf.isEmpty) {
            uf = placeBits.removeLast().toUpperCase();
          }
          if (placeBits.length >= 2) {
            hood = placeBits.first;
            assignCityAndOptionalUf(placeBits.last);
          } else if (placeBits.length == 1) {
            assignCityAndOptionalUf(placeBits.first);
          }
        } else if (placeBits.length == 1) {
          final single = placeBits.first;
          final slashMatch = _citySlashUfRegex.firstMatch(single);
          if (slashMatch != null) {
            assignCityAndOptionalUf(single);
          } else if (uf.isNotEmpty) {
            // Ex.: "Rua X, 203 - Poços de Caldas - MG"
            assignCityAndOptionalUf(single);
          } else if (workingSummary.isNotEmpty) {
            // Ex.: "Rua X, 203 - Maria Imaculada" com summary "Poços de Caldas - MG"
            hood = single;
          } else {
            assignCityAndOptionalUf(single);
          }
        }
      } else if (effectiveBlocks.length == 1) {
        final singleBlock = effectiveBlocks.first;
        final commaBits = singleBlock
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (commaBits.isNotEmpty && _isUf(commaBits.last) && uf.isEmpty) {
          uf = commaBits.removeLast().toUpperCase();
        }

        if (uf.isNotEmpty) {
          // Tínhamos UF no final (ex.: "Maria Imaculada, Poços de Caldas - MG" ou
          // "Poços de Caldas - MG" ou "Rua X, 203, Bairro, Cidade - MG").
          if (commaBits.length == 1) {
            final slash = _citySlashUfRegex.firstMatch(commaBits.first);
            if (slash != null) {
              assignCityAndOptionalUf(commaBits.first);
            } else {
              city = commaBits.first;
            }
          } else if (commaBits.length == 2) {
            final secondAsNum = _tryParseHouseNumberToken(commaBits[1]);
            if (secondAsNum != null) {
              street = commaBits[0];
              number = secondAsNum.number;
              comp = secondAsNum.complement;
            } else {
              hood = commaBits[0];
              assignCityAndOptionalUf(commaBits[1]);
            }
          } else if (commaBits.length >= 3) {
            final secondAsNum = _tryParseHouseNumberToken(commaBits[1]);
            if (secondAsNum != null) {
              street = commaBits[0];
              number = secondAsNum.number;
              assignCityAndOptionalUf(commaBits.last);
              if (commaBits.length == 3) {
                comp = secondAsNum.complement;
              } else if (commaBits.length == 4) {
                hood = commaBits[2];
                comp = secondAsNum.complement;
              } else {
                hood = commaBits[commaBits.length - 2];
                final extraComp = commaBits.sublist(2, commaBits.length - 2).join(', ');
                comp = [
                  if (secondAsNum.complement.isNotEmpty) secondAsNum.complement,
                  if (extraComp.isNotEmpty) extraComp,
                ].join(', ');
              }
            } else {
              street = commaBits.first;
              hood = commaBits[commaBits.length - 2];
              assignCityAndOptionalUf(commaBits.last);
            }
          }
        } else {
          // Sem UF no final (ex.: "Av. Brasil, 10" com summary "Centro, Pouso Alegre - MG")
          final parsedStreet = _parseStreetBlock(singleBlock);
          street = parsedStreet.street;
          number = parsedStreet.number;
          comp = parsedStreet.complement;
        }
      }
    }

    // Enriquece apenas campos ausentes a partir do summary público, sem jamais apagar o que veio na linha.
    if (workingSummary.isNotEmpty && (hood.isEmpty || city.isEmpty || uf.isEmpty)) {
      final summaryParsed = _parseSummaryFallback(workingSummary);
      if (hood.isEmpty && summaryParsed.hood.isNotEmpty) {
        hood = summaryParsed.hood;
      }
      if (city.isEmpty && summaryParsed.city.isNotEmpty) {
        city = summaryParsed.city;
      }
      if (uf.isEmpty && summaryParsed.uf.isNotEmpty) {
        uf = summaryParsed.uf;
      }
    }

    final validCoords = latitude != null &&
        longitude != null &&
        !(latitude == 0 && longitude == 0);

    return StructuredServiceAddress(
      streetName: street.trim(),
      houseNumber: number.trim(),
      complement: comp.trim(),
      neighborhood: hood.trim(),
      city: city.trim(),
      uf: uf.trim().toUpperCase(),
      cep: extractedCep,
      referencePoint: extractedRef,
      latitude: validCoords ? latitude : null,
      longitude: validCoords ? longitude : null,
      precision: pinConfirmed ? DestinationPrecision.exact : precision,
      pinConfirmed: pinConfirmed,
    );
  }

  static bool _isUf(String token) {
    final t = token.trim().toUpperCase();
    return _ufTokenRegex.hasMatch(t) && _brazilianUfs.contains(t);
  }

  static ({String street, String number, String complement}) _parseStreetBlock(String raw) {
    final bits = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (bits.isEmpty) {
      return (street: '', number: '', complement: '');
    }
    if (bits.length == 1) {
      final single = bits.first;
      final trailingMatch = _trailingStreetNumberRegex.firstMatch(single);
      if (trailingMatch != null) {
        final rawNum = trailingMatch.group(2)!.trim();
        final normNum = _snRegex.hasMatch(rawNum) ? 'S/N' : rawNum;
        return (
          street: trailingMatch.group(1)!.trim(),
          number: normNum,
          complement: '',
        );
      }
      return (street: single, number: '', complement: '');
    }

    final street = bits.first;
    final parsedNum = _tryParseHouseNumberToken(bits[1]);
    if (parsedNum != null) {
      final extraComp = bits.length > 2 ? bits.sublist(2).join(', ') : '';
      final fullComp = [
        if (parsedNum.complement.isNotEmpty) parsedNum.complement,
        if (extraComp.isNotEmpty) extraComp,
      ].join(', ');
      return (
        street: street,
        number: parsedNum.number,
        complement: fullComp,
      );
    }

    return (
      street: street,
      number: '',
      complement: bits.sublist(1).join(', '),
    );
  }

  static ({String number, String complement})? _tryParseHouseNumberToken(String rawToken) {
    final token = rawToken.trim();
    if (token.isEmpty) return null;
    if (_snRegex.hasMatch(token)) {
      return (number: 'S/N', complement: '');
    }
    final snWithComp = RegExp(
      r'^(?:s\s*/?\s*n\.?|sem\s+n[uú]mero)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(token);
    if (snWithComp != null) {
      return (number: 'S/N', complement: snWithComp.group(1)!.trim());
    }
    final m = _numberWithOptionalCompRegex.firstMatch(token);
    if (m != null) {
      return (
        number: m.group(1)!.trim(),
        complement: (m.group(2) ?? '').trim(),
      );
    }
    return null;
  }

  static ({String hood, String city, String uf}) _parseSummaryFallback(String summary) {
    var hood = '';
    var city = '';
    var uf = '';

    final blocks = summary
        .split(RegExp(r'\s+[–—-]\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (blocks.isEmpty) return (hood: '', city: '', uf: '');

    if (blocks.length >= 3 && _isUf(blocks.last)) {
      hood = blocks[blocks.length - 3];
      city = blocks[blocks.length - 2];
      uf = blocks.last.toUpperCase();
      return (hood: hood, city: city, uf: uf);
    }

    if (blocks.length >= 2 && _isUf(blocks.last)) {
      uf = blocks.last.toUpperCase();
      final placeBits = blocks.first
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (placeBits.length >= 2) {
        hood = placeBits.first;
        city = placeBits.last;
      } else if (placeBits.length == 1) {
        city = placeBits.first;
      }
      return (hood: hood, city: city, uf: uf);
    }

    final commaBits = blocks.first
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (commaBits.length >= 2 && _isUf(commaBits.last)) {
      uf = commaBits.last.toUpperCase();
      city = commaBits[commaBits.length - 2];
      if (commaBits.length >= 3) hood = commaBits.first;
    } else if (commaBits.length >= 2) {
      hood = commaBits.first;
      final slash = _citySlashUfRegex.firstMatch(commaBits.last);
      if (slash != null) {
        city = slash.group(1)!.trim();
        uf = slash.group(2)!.toUpperCase();
      } else {
        city = commaBits.last;
      }
    } else if (commaBits.length == 1) {
      final slash = _citySlashUfRegex.firstMatch(commaBits.first);
      if (slash != null) {
        city = slash.group(1)!.trim();
        uf = slash.group(2)!.toUpperCase();
      } else {
        city = commaBits.first;
      }
    }
    return (hood: hood, city: city, uf: uf);
  }

  static String _normalizeCep(String? rawCep) {
    final digits = (rawCep ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return '';
    return '${digits.substring(0, 5)}-${digits.substring(5)}';
  }

  /// Dígitos puros do CEP (8 caracteres quando presente, ou vazio).
  String get cepDigits => cep.replaceAll(RegExp(r'\D'), '');

  /// Verdadeiro quando há coordenadas geográficas válidas (não nulas e diferentes de 0,0).
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  /// Logradouro + número exato (ex.: `"Travessa Pedro de Castro Souza, 200"`).
  String get streetWithNumber {
    final s = streetName.trim();
    final n = houseNumber.trim();
    if (s.isEmpty) return n;
    if (n.isEmpty) return s;
    return '$s, $n';
  }

  /// Cidade e UF formatadas (ex.: `"Poços de Caldas - MG"`).
  String get cityState {
    final c = city.trim();
    final u = uf.trim().toUpperCase();
    if (c.isNotEmpty && u.isNotEmpty) return '$c - $u';
    if (c.isNotEmpty) return c;
    return u;
  }

  /// Bairro, Cidade - UF (ex.: `"Country Club, Poços de Caldas - MG"`).
  String get districtCityState {
    final h = neighborhood.trim();
    final cs = cityState;
    if (h.isNotEmpty && cs.isNotEmpty) return '$h, $cs';
    if (h.isNotEmpty) return h;
    return cs;
  }

  /// Linha completa canônica do endereço:
  /// `"Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG"`.
  String get formattedFullLine {
    final firstParts = <String>[
      if (streetWithNumber.isNotEmpty) streetWithNumber,
      if (complement.trim().isNotEmpty) complement.trim(),
    ];
    final first = firstParts.join(', ');
    final second = districtCityState;
    if (first.isNotEmpty && second.isNotEmpty) return '$first - $second';
    if (first.isNotEmpty) return first;
    return second;
  }

  /// Enriquece APENAS metadados faltantes (como `cep` ou `neighborhood` vazio),
  /// preservando de forma imutável os campos informados pelo cliente (`houseNumber`,
  /// `streetName`, `neighborhood`, `city`, `uf`).
  StructuredServiceAddress enrichMissing({
    String? streetName,
    String? houseNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? uf,
    String? cep,
    String? referencePoint,
    double? latitude,
    double? longitude,
    DestinationPrecision? precision,
    bool? pinConfirmed,
  }) {
    final normIncomingCep = _normalizeCep(cep);
    return StructuredServiceAddress(
      streetName: this.streetName.isNotEmpty
          ? this.streetName
          : (streetName ?? '').trim(),
      houseNumber: this.houseNumber.isNotEmpty
          ? this.houseNumber
          : (houseNumber ?? '').trim(),
      complement: this.complement.isNotEmpty
          ? this.complement
          : (complement ?? '').trim(),
      neighborhood: this.neighborhood.isNotEmpty
          ? this.neighborhood
          : (neighborhood ?? '').trim(),
      city: this.city.isNotEmpty ? this.city : (city ?? '').trim(),
      uf: this.uf.isNotEmpty ? this.uf : (uf ?? '').trim().toUpperCase(),
      cep: this.cep.isNotEmpty ? this.cep : normIncomingCep,
      referencePoint: this.referencePoint.isNotEmpty
          ? this.referencePoint
          : (referencePoint ?? '').trim(),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      precision: precision ?? this.precision,
      pinConfirmed: pinConfirmed ?? this.pinConfirmed,
    );
  }

  StructuredServiceAddress copyWith({
    String? streetName,
    String? houseNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? uf,
    String? cep,
    String? referencePoint,
    double? latitude,
    double? longitude,
    DestinationPrecision? precision,
    bool? pinConfirmed,
  }) {
    return StructuredServiceAddress(
      streetName: streetName ?? this.streetName,
      houseNumber: houseNumber ?? this.houseNumber,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      uf: uf ?? this.uf,
      cep: cep != null ? (_normalizeCep(cep).isEmpty ? cep : _normalizeCep(cep)) : this.cep,
      referencePoint: referencePoint ?? this.referencePoint,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      precision: precision ?? this.precision,
      pinConfirmed: pinConfirmed ?? this.pinConfirmed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'streetName': streetName,
        'houseNumber': houseNumber,
        'complement': complement,
        'neighborhood': neighborhood,
        'city': city,
        'uf': uf,
        'cep': cep,
        'referencePoint': referencePoint,
        'latitude': latitude,
        'longitude': longitude,
        'precision': precision.wire,
        'pinConfirmed': pinConfirmed,
      };

  factory StructuredServiceAddress.fromJson(Map<String, dynamic> json) {
    return StructuredServiceAddress(
      streetName: (json['streetName'] as String?) ?? '',
      houseNumber: (json['houseNumber'] as String?) ?? '',
      complement: (json['complement'] as String?) ?? '',
      neighborhood: (json['neighborhood'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      uf: (json['uf'] as String?) ?? '',
      cep: (json['cep'] as String?) ?? '',
      referencePoint: (json['referencePoint'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      precision: DestinationPrecision.parse(json['precision'] as String?),
      pinConfirmed: (json['pinConfirmed'] as bool?) ?? false,
    );
  }

  @override
  String toString() => formattedFullLine;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is StructuredServiceAddress &&
            other.streetName == streetName &&
            other.houseNumber == houseNumber &&
            other.complement == complement &&
            other.neighborhood == neighborhood &&
            other.city == city &&
            other.uf == uf &&
            other.cep == cep &&
            other.referencePoint == referencePoint &&
            other.latitude == latitude &&
            other.longitude == longitude &&
            other.precision == precision &&
            other.pinConfirmed == pinConfirmed);
  }

  @override
  int get hashCode => Object.hash(
        streetName,
        houseNumber,
        complement,
        neighborhood,
        city,
        uf,
        cep,
        referencePoint,
        latitude,
        longitude,
        precision,
        pinConfirmed,
      );

  static const Set<String> _brazilianUfs = <String>{
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
    'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
  };
}
