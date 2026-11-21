import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let nativeGeocoder = CLGeocoder()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let geoChannel = FlutterMethodChannel(
      name: "br.com.desperrengue.app/native_geocoder",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    geoChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      if call.method == "reverseGeocode",
         let args = call.arguments as? [String: Any],
         let lat = args["lat"] as? Double,
         let lng = args["lng"] as? Double {
        let location = CLLocation(latitude: lat, longitude: lng)
        self.nativeGeocoder.cancelGeocode()
        self.nativeGeocoder.reverseGeocodeLocation(
          location,
          preferredLocale: Locale(identifier: "pt_BR")
        ) { placemarks, error in
          if error != nil {
            result(nil)
            return
          }
          guard let placemark = placemarks?.first else {
            result(nil)
            return
          }
          let street = (placemark.thoroughfare ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          let number = (placemark.subThoroughfare ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          let neighborhood = (placemark.subLocality ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          let city = (placemark.locality ?? placemark.subAdministrativeArea ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          let state = (placemark.administrativeArea ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          let postalCode = (placemark.postalCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          if street.isEmpty && city.isEmpty {
            result(nil)
            return
          }
          result([
            "street": street,
            "number": number,
            "neighborhood": neighborhood,
            "city": city,
            "state": state,
            "postalCode": postalCode,
            "latitude": placemark.location?.coordinate.latitude ?? lat,
            "longitude": placemark.location?.coordinate.longitude ?? lng,
            "source": "ios_clgeocoder"
          ])
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
