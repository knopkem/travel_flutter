import CoreLocation
import Flutter

class GeofenceManager: NSObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    private var registeredGeofences: [String: CLCircularRegion] = [:]
    private var methodChannel: FlutterMethodChannel?
    
    func setup(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.travel_flutter.geofencing",
            binaryMessenger: messenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call: call, result: result)
        }
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "registerGeofence":
            if let args = call.arguments as? [String: Any],
               let id = args["id"] as? String,
               let latitude = args["latitude"] as? Double,
               let longitude = args["longitude"] as? Double,
               let radius = args["radius"] as? Double {
                registerGeofence(id: id, latitude: latitude, longitude: longitude, radius: radius)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
            
        case "removeGeofence":
            if let args = call.arguments as? [String: Any],
               let id = args["id"] as? String {
                removeGeofence(id: id)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
            
        case "removeAllGeofences":
            removeAllGeofences()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func registerGeofence(id: String, latitude: Double, longitude: Double, radius: Double) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: id)
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        registeredGeofences[id] = region
        locationManager?.startMonitoring(for: region)
    }
    
    private func removeGeofence(id: String) {
        if let region = registeredGeofences[id] {
            locationManager?.stopMonitoring(for: region)
            registeredGeofences.removeValue(forKey: id)
        }
    }
    
    private func removeAllGeofences() {
        for (_, region) in registeredGeofences {
            locationManager?.stopMonitoring(for: region)
        }
        registeredGeofences.removeAll()
    }
    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            // Notify Flutter about region entry
            methodChannel?.invokeMethod("onGeofenceEnter", arguments: ["id": circularRegion.identifier])
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            // Notify Flutter about region exit
            methodChannel?.invokeMethod("onGeofenceExit", arguments: ["id": circularRegion.identifier])
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofence monitoring failed: \(error.localizedDescription)")
        if let region = region {
            methodChannel?.invokeMethod("onGeofenceError", arguments: [
                "id": region.identifier,
                "error": error.localizedDescription
            ])
        }
    }
}
