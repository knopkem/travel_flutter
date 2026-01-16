import CoreLocation
import Flutter
import UserNotifications

class GeofenceManager: NSObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    private var registeredGeofences: [String: CLCircularRegion] = [:]
    private var methodChannel: FlutterMethodChannel?
    // Track regions that have already had enter events sent to prevent duplicates
    private var enteredRegions: Set<String> = []
    
    func setup(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.app/geofence",
            binaryMessenger: messenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call: call, result: result)
        }
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
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
        // Clear any existing state for this geofence to allow fresh "already inside" detection
        if registeredGeofences[id] != nil {
            locationManager?.stopMonitoring(for: registeredGeofences[id]!)
            registeredGeofences.removeValue(forKey: id)
        }
        enteredRegions.remove(id)  // Clear so didDetermineState can re-trigger if inside
        
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: id)
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        registeredGeofences[id] = region
        locationManager?.startMonitoring(for: region)
        
        // Log geofence registration
        let latStr = String(format: "%.4f", latitude)
        let lonStr = String(format: "%.4f", longitude)
        print("Registered geofence: \(id.prefix(8))... at \(latStr), \(lonStr)")
    }
    
    private func removeGeofence(id: String) {
        if let region = registeredGeofences[id] {
            locationManager?.stopMonitoring(for: region)
            registeredGeofences.removeValue(forKey: id)
            enteredRegions.remove(id)
        }
    }
    
    private func removeAllGeofences() {
        for (_, region) in registeredGeofences {
            locationManager?.stopMonitoring(for: region)
        }
        registeredGeofences.removeAll()
        enteredRegions.removeAll()
    }
    

    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            // Check if we've already sent an enter event for this region
            guard !enteredRegions.contains(circularRegion.identifier) else {
                print("ENTER (duplicate, skipping): \(circularRegion.identifier.prefix(8))...")
                return
            }
            enteredRegions.insert(circularRegion.identifier)
            
            // Log region entry
            print("ENTERED region: \(circularRegion.identifier.prefix(8))...")
            
            // Notify Flutter about region entry
            methodChannel?.invokeMethod("onGeofenceEnter", arguments: ["id": circularRegion.identifier])
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            // Clear the entered state so we can trigger again on next entry
            enteredRegions.remove(circularRegion.identifier)
            
            // Log region exit
            print("EXITED region: \(circularRegion.identifier.prefix(8))...")
            
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
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Started monitoring for region: \(region.identifier)")
        // Request state to get initial status
        locationManager?.requestState(for: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        var stateStr = "unknown"
        switch state {
        case .inside: 
            stateStr = "INSIDE"
            // If already inside when registering, trigger the enter event (but only if not already sent)
            if let circularRegion = region as? CLCircularRegion {
                guard !enteredRegions.contains(circularRegion.identifier) else {
                    print("Already INSIDE \(region.identifier.prefix(8))... (already notified)")
                    return
                }
                enteredRegions.insert(circularRegion.identifier)
                print("Already INSIDE \(region.identifier.prefix(8))..., triggering enter")
                methodChannel?.invokeMethod("onGeofenceEnter", arguments: ["id": circularRegion.identifier])
            }
        case .outside: stateStr = "outside"
        case .unknown: stateStr = "unknown"
        }
        if state != .inside {
            print("State for \(region.identifier.prefix(8))...: \(stateStr)")
        }
    }
}
