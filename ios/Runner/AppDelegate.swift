import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("AppDelegate: Flutter 플러그인 등록 시작")
    GeneratedPluginRegistrant.register(with: self)
    print("AppDelegate: Flutter 플러그인 등록 완료")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
