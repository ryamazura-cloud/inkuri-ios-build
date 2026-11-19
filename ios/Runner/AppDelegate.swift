import Flutter
import UIKit
import UserNotifications
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "biz.wisemap.encre/storekit",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "isSandboxApp" {
        Task { @MainActor in
          if #available(iOS 16.0, *) {
            if let verification = try? await AppTransaction.shared,
               case .verified(let transaction) = verification {
              result(transaction.environment == .sandbox || transaction.environment == .xcode)
              return
            }
          }
          result(Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt")
        }
        return
      }
      guard call.method == "hasVerifiedEntitlement" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let productID = args["productId"] as? String,
            productID == "incre_unlimited" else {
        result(FlutterError(code: "INVALID_PRODUCT", message: "Unknown product", details: nil))
        return
      }
      Task { @MainActor in
        var entitled = false
        for await verification in Transaction.currentEntitlements {
          switch verification {
          case .verified(let transaction):
            if transaction.productID == productID,
               transaction.productType == .nonConsumable,
               transaction.revocationDate == nil {
              entitled = true
            }
          case .unverified(let transaction, _):
            if transaction.productID == productID {
              result(FlutterError(code: "UNVERIFIED", message: "Purchase verification failed", details: nil))
              return
            }
          }
        }
        result(entitled)
      }
    }
  }
}
