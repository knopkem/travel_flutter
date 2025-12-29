import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var geofenceManager: GeofenceManager?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Setup geofence manager
        if let controller = window?.rootViewController as? FlutterViewController {
            geofenceManager = GeofenceManager()
            geofenceManager?.setup(with: controller.binaryMessenger)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
