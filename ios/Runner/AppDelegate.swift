import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
        
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
    VoIPManager.shared.configureVoIP()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
      
    let messenger = engineBridge.applicationRegistrar.messenger()
    VoIPManager.shared.backgroundMessenger = messenger
    
    // From https://pub.dev/packages/flutter_local_notifications#-ios-setup
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
  }
}
