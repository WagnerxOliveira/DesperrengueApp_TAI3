import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Caminhos dos textos da licença SIL OFL 1.1 das fontes embarcadas.
@visibleForTesting
const Map<String, String> cinemaFontLicenseAssets = <String, String>{
  'Plus Jakarta Sans': 'assets/licenses/OFL_PlusJakartaSans.txt',
  'Inter': 'assets/licenses/OFL_Inter.txt',
};

bool _cinemaFontLicensesRegistered = false;

/// Registra as licenças OFL das fontes embarcadas (Plus Jakarta Sans e Inter)
/// no `LicenseRegistry`, para aparecerem em `showLicensePage`.
///
/// Idempotente: pode ser chamada várias vezes (só registra uma vez).
void registerCinemaFontLicenses() {
  if (_cinemaFontLicensesRegistered) return;
  _cinemaFontLicensesRegistered = true;
  LicenseRegistry.addLicense(() async* {
    for (final entry in cinemaFontLicenseAssets.entries) {
      String text;
      try {
        text = await rootBundle.loadString(entry.value);
      } catch (_) {
        continue;
      }
      yield LicenseEntryWithLineBreaks(<String>[entry.key], text);
    }
  });
}
