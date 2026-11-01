import Flutter
import UIKit
import CoreLocation

class LocationPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?
  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.allohalal.app/location", binaryMessenger: registrar.messenger())
    let instance = LocationPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCurrentLocation":
      requestAndGetLocation(result: result)
    case "isLocationServiceEnabled":
      let enabled = CLLocationManager.locationServicesEnabled()
      result(enabled)
    case "openLocationSettings", "openAppSettings":
      if let url = URL(string: UIApplication.openSettingsURLString),
         UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        result(true)
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestAndGetLocation(result: @escaping FlutterResult) {
    if !CLLocationManager.locationServicesEnabled() {
      result(["status": "LOCATION_DISABLED"])
      return
    }

    if locationManager == nil {
      locationManager = CLLocationManager()
      locationManager?.delegate = self
      locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = locationManager?.authorizationStatus ?? .notDetermined
    } else {
      status = CLLocationManager.authorizationStatus()
    }

    switch status {
    case .denied, .restricted:
      result(["status": "PERMISSION_DENIED"])
    case .notDetermined:
      pendingResult = result
      locationManager?.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      pendingResult = result
      locationManager?.requestLocation()
    @unknown default:
      result(nil)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }

    handleAuthStatus(status: status, manager: manager)
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    handleAuthStatus(status: status, manager: manager)
  }

  private func handleAuthStatus(status: CLAuthorizationStatus, manager: CLLocationManager) {
    if status == .authorizedWhenInUse || status == .authorizedAlways {
      manager.requestLocation()
    } else if status == .denied || status == .restricted {
      if let pending = pendingResult {
        pending(["status": "PERMISSION_DENIED"])
        pendingResult = nil
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else {
      if let pending = pendingResult {
        pending(nil)
        pendingResult = nil
      }
      return
    }

    if let pending = pendingResult {
      pending([
        "status": "SUCCESS",
        "latitude": location.coordinate.latitude,
        "longitude": location.coordinate.longitude
      ])
      pendingResult = nil
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let pending = pendingResult {
      pending(nil)
      pendingResult = nil
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let registrar = self.registrar(forPlugin: "LocationPlugin") {
      LocationPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocationPlugin") {
      LocationPlugin.register(with: registrar)
    }
  }
}
