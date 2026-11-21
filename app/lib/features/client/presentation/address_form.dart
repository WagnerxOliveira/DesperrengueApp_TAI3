import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/address_data.dart';
import '../../../core/models/geocode_models.dart';
import '../../../core/models/scheduling_models.dart';
import '../../../core/services/address_lookup.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../../core/services/precise_location_acquisition_service.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../shared/presentation/service_map_widgets.dart';
import 'widgets/kyc_onboarding_chrome.dart';

export '../../../core/models/address_data.dart';

/// Consulta o CEP (ViaCEP, com BrasilAPI de reserva). Devolve null se não achar.
Future<AddressData?> lookupCep(String cep) => AddressLookup().byCep(cep);

/// Formata automaticamente o CEP brasileiro no padrão `00000-000` (até 8 dígitos),
/// preservando a posição do cursor durante digitação, colagem ou remoção.
class CepInputFormatter extends TextInputFormatter {
  const CepInputFormatter();

  /// Formata uma string arbitrária em `00000-000` quando tiver mais de 5 dígitos.
  static String format(String input) {
    final digits = AddressLookup.onlyDigits(input);
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    if (clipped.length <= 5) return clipped;
    return '${clipped.substring(0, 5)}-${clipped.substring(5)}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);

    // Calcula quantos dígitos existiam antes do cursor na entrada nova.
    final rawCursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor =
        AddressLookup.onlyDigits(newValue.text.substring(0, rawCursor)).length;
    final clampedDigits = digitsBeforeCursor.clamp(0, 8);
    final targetOffset =
        clampedDigits > 5 ? clampedDigits + 1 : clampedDigits;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: targetOffset.clamp(0, formatted.length),
      ),
    );
  }
}

/// Formulário de endereço (CEP + GPS), compartilhado entre cadastro e edição.
///
/// * Ao digitar os 8 dígitos do CEP, rua/bairro/cidade/UF são preenchidos
///   sozinhos e o cursor vai direto para o NÚMERO.
/// * "Usar minha localização atual" captura o GPS, descobre o endereço e
///   preenche os campos (o número fica por conta do usuário).
class AddressForm extends StatefulWidget {
  const AddressForm({
    super.key,
    required this.onChanged,
    this.initial,
    @visibleForTesting this.lookup,
    @visibleForTesting this.geocoder,
    @visibleForTesting this.pinPicker,
  });

  final ValueChanged<AddressData> onChanged;
  final AddressData? initial;

  /// Injetáveis nos testes (padrão: serviços reais).
  final AddressLookup? lookup;
  final AddressGeocoder? geocoder;
  final PinPicker? pinPicker;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

/// Abre o mapa para o cliente marcar o ponto exato (padrão: [LocationPickerSheet.show]).
typedef PinPicker = Future<Object?> Function(
  BuildContext context, {
  required JobDestination? initial,
  required Future<void> Function(double lat, double lng) onConfirm,
  String? addressLine,
});

enum _Auto { idle, loading, done, notFound }

class _AddressFormState extends State<AddressForm> {
  late final AddressLookup _lookup = widget.lookup ?? AddressLookup();
  late final TextEditingController _cep;
  late final TextEditingController _street;
  late final TextEditingController _number;
  late final TextEditingController _complement;
  late final TextEditingController _neighborhood;
  late final TextEditingController _city;
  late final TextEditingController _uf;
  late final TextEditingController _reference;
  final _numberFocus = FocusNode();
  final _streetFocus = FocusNode();
  double? _lat;
  double? _lng;
  double? _gpsAccuracyMeters;
  LocationFixQuality? _gpsQuality;
  bool _loadingGps = false;
  String _gpsProgressLabel = 'Refinando sinal de GPS...';

  /// O cliente confirmou o ponto exato no mapa (ou veio do GPS).
  bool _pinConfirmed = false;

  /// O ponto atual veio do GPS (mais confiável que qualquer geocodificação).
  bool _gpsPin = false;
  bool _locatingPin = false;

  /// Evita que escrever nos campos por código invalide o ponto confirmado.
  bool _applying = false;
  _Auto _auto = _Auto.idle;

  /// Último CEP consultado (evita consultar de novo o mesmo valor).
  String _lastCep = '';

  List<TextEditingController> get _all =>
      [_cep, _street, _number, _complement, _neighborhood, _city, _uf, _reference];

  @override
  void initState() {
    super.initState();
    final a = widget.initial ?? const AddressData();
    _cep = TextEditingController(text: CepInputFormatter.format(a.cep));
    _street = TextEditingController(text: a.street);
    _number = TextEditingController(text: a.number);
    _complement = TextEditingController(text: a.complement);
    _neighborhood = TextEditingController(text: a.neighborhood);
    _city = TextEditingController(text: a.city);
    _uf = TextEditingController(text: a.uf);
    _reference = TextEditingController(text: a.reference);
    _lat = a.latitude;
    _lng = a.longitude;
    _lastCanPlace = _canPlacePin;
    // Endereço já preenchido (rascunho): não sobrescrever com nova consulta.
    if (a.street.isNotEmpty) _lastCep = AddressLookup.onlyDigits(a.cep);
    // O ponto só vale para o endereço em que foi marcado: mexeu na rua/cidade/CEP, descarta.
    // (Registrado ANTES do _emit para o pai receber as coordenadas já zeradas.)
    for (final c in [_cep, _street, _city, _uf]) {
      c.addListener(_invalidatePin);
    }
    _number.addListener(() {
      if (!_gpsPin) _invalidatePin();
    });
    for (final c in _all) {
      c.addListener(_emit);
    }
    _cep.addListener(_onCepChanged);
    for (final c in [_street, _number, _city]) {
      c.addListener(_refreshPinButton);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    _numberFocus.dispose();
    _streetFocus.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
        AddressData(
          cep: AddressLookup.onlyDigits(_cep.text),
          street: _street.text.trim(),
          number: _number.text.trim(),
          complement: _complement.text.trim(),
          neighborhood: _neighborhood.text.trim(),
          city: _city.text.trim(),
          uf: _uf.text.trim().toUpperCase(),
          reference: _reference.text.trim(),
          latitude: _lat,
          longitude: _lng,
        ),
      );

  bool _lastCanPlace = false;

  void _refreshPinButton() {
    final can = _canPlacePin;
    if (can != _lastCanPlace && mounted) {
      _lastCanPlace = can;
      setState(() {});
    }
  }

  void _invalidatePin() {
    if (_applying || (_lat == null && !_pinConfirmed)) return;
    _lat = null;
    _lng = null;
    _gpsPin = false;
    if (_pinConfirmed) {
      _pinConfirmed = false;
      if (mounted) setState(() {});
    }
  }

  void _onCepChanged() {
    final digits = AddressLookup.onlyDigits(_cep.text);
    if (digits.length == 8) {
      if (digits != _lastCep) _searchCep();
    } else {
      if (_auto != _Auto.idle && mounted) setState(() => _auto = _Auto.idle);
    }
  }

  /// Aplica o endereço encontrado nos campos (mantém o número digitado).
  ///
  /// [useCoords] = false para CEP: as coordenadas devolvidas por CEP são do centro do CEP/bairro
  /// (chegam a quilômetros do endereço real) e NÃO devem virar o pino do serviço.
  void _apply(AddressData a, {bool keepNumber = true, bool useCoords = true}) {
    _applying = true;
    try {
      _street.text = a.street;
      _neighborhood.text = a.neighborhood;
      _city.text = a.city;
      _uf.text = a.uf;
      if (!keepNumber) _number.text = '';
    } finally {
      _applying = false;
    }
    if (useCoords && a.latitude != null) {
      _lat = a.latitude;
      _lng = a.longitude;
    } else {
      _lat = null;
      _lng = null;
      _pinConfirmed = false;
      _gpsPin = false;
    }
    _emit();
  }

  Future<void> _searchCep() async {
    final digits = AddressLookup.onlyDigits(_cep.text);
    if (digits.length != 8) {
      AppSnackbar.show(
        context,
        'Digite os 8 números do CEP.',
        kind: AppSnackKind.error,
      );
      return;
    }
    _lastCep = digits;
    setState(() => _auto = _Auto.loading);
    final found = await _lookup.byCep(digits);
    if (!mounted || AddressLookup.onlyDigits(_cep.text) != digits) return;
    if (found == null) {
      setState(() => _auto = _Auto.notFound);
      return;
    }
    _apply(found, useCoords: false);
    setState(() => _auto = _Auto.done);
    // Cursor direto no que falta: número (ou rua, se o CEP for genérico).
    (found.street.isEmpty ? _streetFocus : _numberFocus).requestFocus();
  }

  Future<void> _useGps() async {
    setState(() {
      _loadingGps = true;
      _gpsProgressLabel = 'Refinando sinal de GPS...';
    });
    try {
      final fix = await PreciseLocationAcquisitionService.acquire(
        onProgress: (msg) {
          if (mounted && _loadingGps) {
            setState(() => _gpsProgressLabel = msg);
          }
        },
      );
      if (!mounted) return;

      switch (fix.status) {
        case LocationAcquisitionStatus.serviceDisabled:
          AppSnackbar.show(
            context,
            'Ative a localização (GPS) do aparelho e tente de novo.',
            kind: AppSnackKind.error,
          );
          return;
        case LocationAcquisitionStatus.permissionDenied:
        case LocationAcquisitionStatus.permissionDeniedForever:
          AppSnackbar.show(
            context,
            'Permissão de localização negada. Digite o CEP ou libere nas configurações.',
            kind: AppSnackKind.error,
          );
          return;
        case LocationAcquisitionStatus.reducedAccuracyOnly:
          AppSnackbar.show(
            context,
            'Seu aparelho liberou apenas localização aproximada. Ative "Localização precisa" nas permissões para evitar erro de rua.',
            kind: AppSnackKind.error,
          );
          await Geolocator.openAppSettings();
          return;
        case LocationAcquisitionStatus.unavailable:
          AppSnackbar.show(
            context,
            'Não foi possível obter a localização precisa agora. Digite o CEP.',
            kind: AppSnackKind.error,
          );
          return;
        case LocationAcquisitionStatus.ok:
          break;
      }

      final lat = fix.latitude!;
      final lng = fix.longitude!;
      final acc = fix.accuracyMeters;
      final quality = fix.quality ?? LocationFixQuality.moderate;

      if (mounted) {
        setState(() => _gpsProgressLabel = 'Identificando rua e bairro...');
      }

      final found = await _lookup.byCoordinates(lat, lng);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _lat = lat;
          _lng = lng;
          _gpsAccuracyMeters = acc;
          _gpsQuality = quality;
        });
        _emit();
        AppSnackbar.show(
          context,
          'Localização capturada, mas não achamos o endereço. Digite o CEP ou ajuste o pino no mapa.',
          kind: AppSnackKind.error,
        );
        return;
      }

      final cleanCep = AddressLookup.onlyDigits(found.cep);
      _lastCep = cleanCep; // evita nova consulta ao preencher o CEP abaixo
      _applying = true;
      try {
        _cep.text = CepInputFormatter.format(cleanCep);
      } finally {
        _applying = false;
      }
      _apply(found, useCoords: false);

      // Só confirma automaticamente o pino se o fix GNSS não for degradado (<= 65 m).
      final bool isReliablePin = quality != LocationFixQuality.coarse;
      _lat = lat;
      _lng = lng;
      _gpsAccuracyMeters = acc;
      _gpsQuality = quality;
      _pinConfirmed = isReliablePin;
      _gpsPin = isReliablePin;
      _emit();
      setState(() => _auto = _Auto.done);

      if (isReliablePin) {
        AppSnackbar.show(
          context,
          'Endereço preenchido! Confira no mapa e informe o número.',
          kind: AppSnackKind.success,
        );
        _numberFocus.requestFocus();
      } else {
        final meters = acc != null ? '±${acc.round()} m' : 'baixa precisão';
        AppSnackbar.show(
          context,
          'Sinal de GPS aproximado ($meters). Toque em "Ajustar no mapa" para confirmar sua rua exata.',
          kind: AppSnackKind.info,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Não foi possível obter a localização.',
          kind: AppSnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  bool get _canPlacePin =>
      _street.text.trim().isNotEmpty &&
      _number.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty;

  String get _fullLine {
    final n = _number.text.trim();
    final head = [_street.text.trim(), if (n.isNotEmpty) n].join(', ');
    final place = [_neighborhood.text.trim(), _city.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(', ');
    return [head, place, _uf.text.trim().toUpperCase()]
        .where((s) => s.isNotEmpty)
        .join(' - ');
  }

  /// Abre o mapa com o pino no endereço digitado (ou na coordenada GPS capturada)
  /// para o cliente ajustar exatamente na porta da casa.
  Future<void> _confirmPin({bool allowFromGpsOnly = false}) async {
    if (!_canPlacePin && !(allowFromGpsOnly && _lat != null && _lng != null)) {
      AppSnackbar.show(
        context,
        'Preencha rua, número e cidade para marcar o ponto no mapa.',
        kind: AppSnackKind.error,
      );
      return;
    }
    setState(() => _locatingPin = true);
    JobDestination? initial;
    try {
      if (_lat != null && _lng != null) {
        initial = JobDestination(
          lat: _lat!,
          lng: _lng!,
          precision: DestinationPrecision.street,
          radiusM: 0,
          source: 'client_pin',
        );
      } else {
        final hit = await (widget.geocoder ?? PreciseGeocoder()).geocode(
          _fullLine,
          cep: _cep.text,
        );
        if (hit != null) {
          initial = JobDestination(
            lat: hit.lat,
            lng: hit.lng,
            precision: hit.precision,
            radiusM: 0,
            source: 'client_geocode',
          );
        }
      }
    } catch (_) {
      // Sem internet/serviço: o mapa abre no centro padrão e o cliente arrasta.
    }
    if (!mounted) return;
    setState(() => _locatingPin = false);
    if (widget.pinPicker != null) {
      await widget.pinPicker!(
        context,
        initial: initial,
        addressLine: _fullLine,
        onConfirm: (lat, lng) async {
          if (!mounted) return;
          setState(() {
            _lat = lat;
            _lng = lng;
            _pinConfirmed = true;
            _gpsPin = false;
          });
          _emit();
        },
      );
      return;
    }
    await LocationPickerSheet.show(
      context,
      initial: initial,
      addressLine: _fullLine,
      onAddressResolved: (addr) {
        if (!mounted) return;
        _applying = true;
        try {
          if (addr.street.trim().isNotEmpty) _street.text = addr.street.trim();
          final resolvedNumber = addr.number.trim();
          if (resolvedNumber.isNotEmpty &&
              resolvedNumber.toUpperCase() != 'S/N') {
            _number.text = resolvedNumber;
          }
          if (addr.neighborhood.trim().isNotEmpty) {
            _neighborhood.text = addr.neighborhood.trim();
          }
          if (addr.city.trim().isNotEmpty) _city.text = addr.city.trim();
          if (addr.uf.trim().isNotEmpty) {
            _uf.text = addr.uf.trim().toUpperCase();
          }
          final cleanCep = AddressLookup.onlyDigits(addr.cep);
          if (cleanCep.length == 8) {
            _lastCep = cleanCep;
            _cep.text = CepInputFormatter.format(cleanCep);
          }
        } finally {
          _applying = false;
        }
        _emit();
      },
      onConfirm: (lat, lng) async {
        if (!mounted) return;
        setState(() {
          _lat = lat;
          _lng = lng;
          _gpsAccuracyMeters = null;
          _gpsQuality = LocationFixQuality.precise;
          _pinConfirmed = true;
          _gpsPin = false;
        });
        _emit();
      },
    );
  }

  Widget _buildInlineMiniMapPreview(BuildContext context) {
    if (_lat == null || _lng == null) return const SizedBox.shrink();
    final tk = context.tk;
    final point = LatLng(_lat!, _lng!);
    final acc = _gpsAccuracyMeters;
    final bool isCoarse = _gpsQuality == LocationFixQuality.coarse;
    final String badgeText;
    final AppTone badgeTone;
    if (isCoarse && acc != null) {
      badgeText = 'Sinal aproximado · ±${acc.round()} m';
      badgeTone = AppTone.warning;
    } else if (_gpsPin && acc != null) {
      badgeText = 'GPS preciso · ±${acc.round()} m';
      badgeTone = AppTone.success;
    } else {
      badgeText = 'Ponto confirmado';
      badgeTone = AppTone.success;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      child: AppCard(
        key: const ValueKey('inline-gps-mini-map'),
        variant: AppCardVariant.outlined,
        radius: 18,
        padding: EdgeInsets.zero,
        borderColor: (isCoarse ? tk.warning : tk.success)
            .withValues(alpha: tk.isDark ? 0.45 : 0.35),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: SizedBox(
            height: 164,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: FlutterMap(
                    key: ValueKey('mini-map-${_lat!.toStringAsFixed(5)}-${_lng!.toStringAsFixed(5)}'),
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: isCoarse ? 15.5 : 17.2,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      buildTileLayer(context),
                      if (acc != null && acc > 3 && acc <= 300)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: point,
                              radius: acc,
                              useRadiusInMeter: true,
                              color: (isCoarse ? tk.warning : tk.accent)
                                  .withValues(alpha: 0.16),
                              borderColor: (isCoarse ? tk.warning : tk.accent)
                                  .withValues(alpha: 0.65),
                              borderStrokeWidth: 1.5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 38,
                              color: isCoarse ? tk.warning : tk.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: AppSpace.s8,
                  left: AppSpace.s8,
                  right: AppSpace.s8,
                  child: Row(
                    children: [
                      Flexible(
                        child: AppStatusChip(
                          badgeText,
                          tone: badgeTone,
                          icon: isCoarse
                              ? Icons.gps_not_fixed_rounded
                              : Icons.gps_fixed_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: AppSpace.s8,
                  left: AppSpace.s8,
                  child: AppButton(
                    key: const ValueKey('btn-mini-map-adjust'),
                    label: 'Ajustar no mapa',
                    icon: Icons.edit_location_alt_outlined,
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    expand: false,
                    onPressed: _locatingPin
                        ? null
                        : () => _confirmPin(allowFromGpsOnly: true),
                  ),
                ),
                const MapAttribution(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGpsHeroCard(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.elevated,
      radius: 20,
      borderColor: tk.accentInk.withValues(alpha: tk.isDark ? 0.30 : 0.22),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      onTap: _loadingGps ? null : _useGps,
      semanticLabel: _loadingGps
          ? _gpsProgressLabel
          : 'Usar minha localização atual',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppGeometry.minTarget),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tk.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tk.accentInk.withValues(alpha: tk.isDark ? 0.26 : 0.16),
                  ),
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  size: 21,
                  color: tk.accentInk,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadingGps
                        ? _gpsProgressLabel
                        : 'Usar minha localização atual',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    'Preenche rua, bairro e cidade automaticamente pelo GPS',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            if (_loadingGps)
              const AppSkeleton(width: 24, height: 24, circle: true)
            else
              ExcludeSemantics(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tk.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: tk.border),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: tk.accentInk,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final tk = context.tk;
    return Row(
      children: [
        Expanded(child: Divider(height: 1, thickness: 1, color: tk.border)),
        Flexible(
          flex: 4,
          fit: FlexFit.loose,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
            child: Text(
              'ou digite seu CEP',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: tk.textMuted),
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, thickness: 1, color: tk.border)),
      ],
    );
  }

  Widget _pinSection(bool stackPairs) {
    final tk = context.tk;
    if (_pinConfirmed) {
      final infoRow = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tk.success.withValues(alpha: tk.isDark ? 0.22 : 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pin_drop_rounded,
                size: 20,
                color: tk.successInk,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Text(
              'Ponto exato confirmado no mapa.',
              style: AppType.bodySm.copyWith(
                color: tk.successInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );

      final adjustBtn = AppButton(
        key: const Key('pin-adjust'),
        label: 'Ajustar',
        variant: AppButtonVariant.tertiary,
        expand: stackPairs,
        compact: true,
        onPressed: _locatingPin ? null : _confirmPin,
      );

      return Padding(
        padding: const EdgeInsets.only(top: AppSpace.s16),
        child: AppCard(
          variant: AppCardVariant.tonal,
          color: tk.successSoft,
          borderColor: tk.successInk.withValues(alpha: tk.isDark ? 0.30 : 0.20),
          radius: AppGeometry.itemRadius,
          padding: const EdgeInsets.all(AppSpace.s12),
          child: stackPairs
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoRow,
                    const SizedBox(height: AppSpace.s8),
                    adjustBtn,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: infoRow),
                    const SizedBox(width: AppSpace.s8),
                    adjustBtn,
                  ],
                ),
        ),
      );
    }

    if (!_canPlacePin) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16),
      child: AppCard(
        variant: AppCardVariant.tonal,
        color: tk.surface,
        borderColor: tk.border,
        radius: AppGeometry.itemRadius,
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tk.accentSoft,
                      borderRadius:
                          BorderRadius.circular(AppGeometry.iconTileRadius),
                    ),
                    child: Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: tk.accentInk,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    'Marque a entrada exata para facilitar a chegada do profissional.',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            AppButton(
              key: const Key('pin-confirm'),
              variant: AppButtonVariant.secondary,
              loading: _locatingPin,
              icon: Icons.pin_drop_outlined,
              label: _locatingPin
                  ? 'Localizando o endereço...'
                  : 'Confirmar o ponto exato no mapa',
              onPressed: _locatingPin ? null : _confirmPin,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cepStatus() {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    final Widget content = switch (_auto) {
      _Auto.idle => const SizedBox.shrink(key: ValueKey('cep-idle')),
      _Auto.loading => _StatusLine(
          key: const ValueKey('cep-loading'),
          icon: null,
          text: 'Buscando endereço...',
          color: tk.textMuted,
        ),
      _Auto.done => _StatusLine(
          key: const ValueKey('cep-done'),
          icon: Icons.check_circle_rounded,
          text: 'Endereço preenchido. Informe o número.',
          color: tk.successInk,
        ),
      _Auto.notFound => _StatusLine(
          key: const ValueKey('cep-not-found'),
          icon: Icons.info_outline_rounded,
          text: 'CEP não encontrado. Preencha o endereço manualmente.',
          color: tk.dangerInk,
        ),
    };

    if (reduced) return content;
    return AnimatedSwitcher(
      duration: AppMotion.d(context, AppMotion.fade),
      switchInCurve: AppMotion.fadeCurve,
      switchOutCurve: AppMotion.fadeCurve,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final stackPairs = layout.isLargeText || layout.isCompact;

    final numberField = AppTextField(
      controller: _number,
      focusNode: _numberFocus,
      keyboardType: TextInputType.streetAddress,
      label: 'Número *',
    );
    final complementField = AppTextField(
      controller: _complement,
      label: 'Complemento',
    );
    final cityField = AppTextField(
      controller: _city,
      textCapitalization: TextCapitalization.words,
      label: 'Cidade *',
    );
    final ufField = AppTextField(
      controller: _uf,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [LengthLimitingTextInputFormatter(2)],
      label: 'UF',
    );

    final String statusChipLabel;
    final AppTone statusTone;
    if (_pinConfirmed) {
      statusChipLabel = 'Pronto';
      statusTone = AppTone.success;
    } else if (_canPlacePin) {
      statusChipLabel = 'Pronto';
      statusTone = AppTone.success;
    } else {
      statusChipLabel = 'Rápido';
      statusTone = AppTone.accent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGpsHeroCard(context),
        _buildInlineMiniMapPreview(context),
        const SizedBox(height: AppSpace.s16),
        _buildDivider(context),
        const SizedBox(height: AppSpace.s16),
        KycPorcelainSectionCard(
          title: 'Endereço do atendimento',
          icon: Icons.location_on_outlined,
          statusChipLabel: statusChipLabel,
          statusTone: statusTone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0: CEP
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _cep,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [CepInputFormatter()],
                      label: 'CEP',
                      hint: '00000-000',
                      prefixIcon: Icons.markunread_mailbox_outlined,
                      success: _auto == _Auto.done,
                      onSubmitted: (_) => _searchCep(),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  SizedBox(
                    height: AppGeometry.inputHeight,
                    child: Center(
                      child: SizedBox.square(
                        dimension: AppGeometry.minTarget,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tk.accentSoft,
                            borderRadius:
                                BorderRadius.circular(AppGeometry.fieldRadius),
                          ),
                          child: _auto == _Auto.loading
                              ? const Center(
                                  child: AppSkeleton(
                                    width: 22,
                                    height: 22,
                                    circle: true,
                                  ),
                                )
                              : AppIconButton(
                                  tooltip: 'Buscar CEP',
                                  icon: Icons.search_rounded,
                                  color: tk.accentInk,
                                  onPressed: _searchCep,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _cepStatus(),
              const SizedBox(height: AppSpace.s12),
              // 1: Rua / Avenida *
              AppTextField(
                controller: _street,
                focusNode: _streetFocus,
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.signpost_outlined,
                label: 'Rua / Avenida *',
              ),
              const SizedBox(height: AppSpace.s12),
              // 2: Número *  +  3: Complemento
              if (stackPairs) ...[
                numberField,
                const SizedBox(height: AppSpace.s12),
                complementField,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: numberField),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(child: complementField),
                  ],
                ),
              const SizedBox(height: AppSpace.s12),
              // 4: Bairro *
              AppTextField(
                controller: _neighborhood,
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.location_city_outlined,
                label: 'Bairro *',
              ),
              const SizedBox(height: AppSpace.s12),
              // 5: Cidade *  +  6: UF
              if (stackPairs) ...[
                cityField,
                const SizedBox(height: AppSpace.s12),
                ufField,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: cityField),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(child: ufField),
                  ],
                ),
              _pinSection(stackPairs),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        AppCard(
          variant: AppCardVariant.tonal,
          radius: 20,
          borderColor: tk.border.withValues(alpha: tk.isDark ? 0.75 : 0.85),
          padding: const EdgeInsets.all(AppSpace.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tk.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                        color: tk.accentInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Dicas para chegada (opcional)',
                        style: AppType.titleSm.copyWith(color: tk.text),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              // 7: Ponto de referência (opcional)
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: AppGeometry.inputHeight),
                child: AppTextField(
                  controller: _reference,
                  maxLines: 4,
                  minLines: 3,
                  label: 'Ponto de referência (opcional)',
                  hint:
                      'Ex: portão de madeira ao lado da padaria; avise o porteiro.',
                  helper:
                      'Instruções de acesso para facilitar a chegada do profissional.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData? icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.s8, left: AppSpace.s4),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: color)
            else
              const AppSkeleton(width: 16, height: 16, circle: true),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                text,
                style: AppType.bodySm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
