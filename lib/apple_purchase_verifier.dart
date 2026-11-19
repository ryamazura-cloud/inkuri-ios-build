import 'package:flutter/services.dart';

/// Uses StoreKit 2's locally verified, Apple-signed current entitlements.
/// No Play purchase tokens or Firebase App Check are used on iOS.
class ApplePurchaseVerifier {
  const ApplePurchaseVerifier();

  static const channel = MethodChannel('biz.wisemap.encre/storekit');

  /// Only selects test ads; this result never grants purchase rights.
  Future<bool> isSandboxApp() async =>
      await channel
          .invokeMethod<bool>('isSandboxApp')
          .timeout(const Duration(seconds: 10)) ??
      false;

  Future<bool> verify(String productId) async {
    final result = await channel.invokeMethod<bool>('hasVerifiedEntitlement', {
      'productId': productId,
    });
    if (result == null) {
      throw const FormatException('StoreKit did not return an entitlement');
    }
    return result;
  }
}
