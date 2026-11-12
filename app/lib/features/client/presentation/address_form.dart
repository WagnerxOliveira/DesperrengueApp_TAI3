import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/models/address_data.dart';
import '../../../core/models/geocode_models.dart';
import '../../../core/models/scheduling_models.dart';
import '../../../core/services/address_lookup.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../shared/presentation/service_map_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/ui/app_tokens.dart';

export '../../../core/models/address_data.dart';

/// Consulta o CEP (ViaCEP, com BrasilAPI de reserva). Devolve null se não achar.
Future<AddressData?> lookupCep(String cep) => AddressLookup().byCep(cep);

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
  bool _loadingGps = false;

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

  List<TextEditingController> get _all => [_cep, _street, _number, _complement, _neighborhood, _city, _uf, _reference];

  @override
  void initState() {
    super.initState();
    final a = widget.initial ?? const AddressData();
    _cep = TextEditingController(text: a.cep);
    _street = TextEditingController(text: a.street);
    _number = TextEditingController(text: a.number);
    _complement = TextEditingController(text: a.complement);
    _neighborhood = TextEditingController(text: a.neighborhood);
    _city = TextEditingController(text: a.city);
    _uf = TextEditingController(text: a.uf);
    _reference = TextEditingController(text: a.reference);
    _lat = a.latitude;
    _lng = a.longitude;
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

  void _emit() => widget.onChanged(AddressData(
        cep: _cep.text,
        street: _street.text.trim(),
        number: _number.text.trim(),
        complement: _complement.text.trim(),
        neighborhood: _neighborhood.text.trim(),
        city: _city.text.trim(),
        uf: _uf.text.trim().toUpperCase(),
        reference: _reference.text.trim(),
        latitude: _lat,
        longitude: _lng,
      ));

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
      showSnack(context, 'Digite os 8 números do CEP.', error: true);
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
    setState(() => _loadingGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showSnack(context, 'Ative a localização (GPS) do aparelho e tente de novo.', error: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showSnack(context, 'Permissão de localização negada. Digite o CEP para continuar.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      final found = await _lookup.byCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (found == null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _emit();
        showSnack(context, 'Localização capturada, mas não achamos o endereço. Digite o CEP.', error: true);
        return;
      }
      _lastCep = found.cep; // evita nova consulta ao preencher o CEP abaixo
      _applying = true;
      try {
        _cep.text = found.cep;
      } finally {
        _applying = false;
      }
      _apply(found, useCoords: false);
      // O GPS do aparelho é o ponto mais fiel que existe: vale como pino confirmado.
      _lat = pos.latitude;
      _lng = pos.longitude;
      _pinConfirmed = true;
      _gpsPin = true;
      _emit();
      setState(() => _auto = _Auto.done);
      showSnack(context, 'Endereço preenchido! Confira e informe o número.');
      _numberFocus.requestFocus();
    } catch (_) {
      if (mounted) showSnack(context, 'Não foi possível obter a localização.', error: true);
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  bool get _canPlacePin =>
      _street.text.trim().isNotEmpty && _number.text.trim().isNotEmpty && _city.text.trim().isNotEmpty;

  String get _fullLine {
    final n = _number.text.trim();
    final head = [_street.text.trim(), if (n.isNotEmpty) n].join(', ');
    final place = [_neighborhood.text.trim(), _city.text.trim()].where((s) => s.isNotEmpty).join(', ');
    return [head, place, _uf.text.trim().toUpperCase()]
        .where((s) => s.isNotEmpty)
        .join(' - ');
  }

  /// Abre o mapa com o pino no endereço digitado para o cliente ajustar na porta da casa.
  Future<void> _confirmPin() async {
    if (!_canPlacePin) {
      showSnack(context, 'Preencha rua, número e cidade para marcar o ponto no mapa.', error: true);
      return;
    }
    setState(() => _locatingPin = true);
    JobDestination? initial;
    try {
      if (_lat != null && _lng != null) {
        initial = JobDestination(
            lat: _lat!, lng: _lng!, precision: DestinationPrecision.street, radiusM: 0, source: 'client_pin');
      } else {
        final hit = await (widget.geocoder ?? PreciseGeocoder()).geocode(_fullLine, cep: _cep.text);
        if (hit != null) {
          initial = JobDestination(
              lat: hit.lat, lng: hit.lng, precision: hit.precision, radiusM: 0, source: 'client_geocode');
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
          if (resolvedNumber.isNotEmpty && resolvedNumber.toUpperCase() != 'S/N') {
            _number.text = resolvedNumber;
          }
          if (addr.neighborhood.trim().isNotEmpty) _neighborhood.text = addr.neighborhood.trim();
          if (addr.city.trim().isNotEmpty) _city.text = addr.city.trim();
          if (addr.uf.trim().isNotEmpty) _uf.text = addr.uf.trim().toUpperCase();
          final cleanCep = AddressLookup.onlyDigits(addr.cep);
          if (cleanCep.length == 8) {
            _lastCep = cleanCep;
            _cep.text = cleanCep;
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
          _pinConfirmed = true;
          _gpsPin = false;
        });
        _emit();
      },
    );
  }

  Widget _pinSection(Color accent) {
    if (_pinConfirmed) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(
              child: _StatusLine(
                icon: Icons.pin_drop_rounded,
                text: 'Ponto exato confirmado no mapa.',
                color: context.tk.success,
              ),
            ),
            TextButton(key: const Key('pin-adjust'), onPressed: _locatingPin ? null : _confirmPin, child: const Text('Ajustar')),
          ],
        ),
      );
    }
    if (!_canPlacePin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        key: const Key('pin-confirm'),
        onPressed: _locatingPin ? null : _confirmPin,
        icon: _locatingPin
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.pin_drop_outlined, color: accent),
        label: Text(
          _locatingPin ? 'Localizando o endereço...' : 'Confirmar o ponto exato no mapa',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _cepStatus() {
    switch (_auto) {
      case _Auto.idle:
        return const SizedBox.shrink();
      case _Auto.loading:
        return _StatusLine(icon: null, text: 'Buscando endereço...', color: context.tk.textMuted);
      case _Auto.done:
        return _StatusLine(icon: Icons.check_circle_rounded, text: 'Endereço preenchido. Informe o número.', color: context.tk.success);
      case _Auto.notFound:
        return _StatusLine(
          icon: Icons.info_outline_rounded,
          text: 'CEP não encontrado. Preencha o endereço manualmente.',
          color: context.tk.danger,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Acesso rápido'),
        OutlinedButton.icon(
          onPressed: _loadingGps ? null : _useGps,
          icon: _loadingGps
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location_rounded),
          label: Text(
            _loadingGps ? 'Buscando seu endereço...' : 'Usar minha localização atual',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 18),
        Center(child: Text('Ou digite o CEP e o resto é por nossa conta', style: TextStyle(color: context.tk.textMuted))),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _cep,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                decoration: const InputDecoration(labelText: 'CEP', hintText: '00000000'),
                onSubmitted: (_) => _searchCep(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              width: 56,
              child: IconButton.filledTonal(
                onPressed: _auto == _Auto.loading ? null : _searchCep,
                style: IconButton.styleFrom(backgroundColor: accent.withValues(alpha: 0.12), foregroundColor: accent),
                icon: _auto == _Auto.loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search_rounded),
              ),
            ),
          ],
        ),
        _cepStatus(),
        const SizedBox(height: 12),
        TextField(
          controller: _street,
          focusNode: _streetFocus,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Rua / Avenida *'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _number,
                focusNode: _numberFocus,
                keyboardType: TextInputType.streetAddress,
                decoration: const InputDecoration(labelText: 'Número *'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _complement, decoration: const InputDecoration(labelText: 'Complemento')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _neighborhood,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Bairro *'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Cidade *'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _uf,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(2)],
                decoration: const InputDecoration(labelText: 'UF'),
              ),
            ),
          ],
        ),
        _pinSection(accent),
        const SizedBox(height: 12),
        TextField(
          controller: _reference,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ponto de referência / instruções de acesso (opcional)',
            hintText: 'Ex: portão de madeira ao lado da padaria; avise o porteiro.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.text, required this.color});

  final IconData? icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, size: 16, color: color)
            else
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
