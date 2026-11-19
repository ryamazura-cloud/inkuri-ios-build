import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:phrase_flow/apple_purchase_verifier.dart';
import 'package:phrase_flow/monetization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(ApplePurchaseVerifier.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'platform products keep the existing Android ID and use the Apple ID',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(Monetization().storeProductId, 'inkuri_unlimited');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(Monetization().storeProductId, 'incre_unlimited');
    },
  );

  for (final entitled in [true, false]) {
    test('uses the native verified entitlement result: $entitled', () async {
      messenger.setMockMethodCallHandler(ApplePurchaseVerifier.channel, (
        call,
      ) async {
        expect(call.method, 'hasVerifiedEntitlement');
        expect(call.arguments, {'productId': 'incre_unlimited'});
        return entitled;
      });
      expect(
        await const ApplePurchaseVerifier().verify('incre_unlimited'),
        entitled,
      );
    });
  }

  test('a native verification error cannot grant a purchase', () async {
    messenger.setMockMethodCallHandler(ApplePurchaseVerifier.channel, (
      _,
    ) async {
      throw PlatformException(code: 'UNVERIFIED');
    });
    await expectLater(
      const ApplePurchaseVerifier().verify('incre_unlimited'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('a missing native result cannot grant a purchase', () async {
    messenger.setMockMethodCallHandler(
      ApplePurchaseVerifier.channel,
      (_) async => null,
    );
    await expectLater(
      const ApplePurchaseVerifier().verify('incre_unlimited'),
      throwsFormatException,
    );
  });

  test(
    'iOS shows the agreed Japanese price even with sandbox USD metadata',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final monetization = Monetization()
        ..product = ProductDetails(
          id: 'incre_unlimited',
          title: 'Unlimited',
          description: '',
          price: r'$5.99',
          rawPrice: 5.99,
          currencyCode: 'USD',
        );
      expect(monetization.purchasePrice, '900円');
      expect(monetization.purchasePriceNote, contains('Appleの購入確認画面'));
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(monetization.purchasePrice, r'$5.99');
      expect(monetization.purchasePriceNote, isEmpty);
      monetization.dispose();
    },
  );

  for (final sandbox in [true, false]) {
    test(
      'native sandbox=$sandbox selects ads without granting ownership',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        messenger.setMockMethodCallHandler(ApplePurchaseVerifier.channel, (
          call,
        ) async {
          expect(call.method, 'isSandboxApp');
          return sandbox;
        });
        final monetization = Monetization(
          appleVerifier: const ApplePurchaseVerifier(),
        );
        await monetization.refreshAppleEnvironment();
        expect(monetization.usesTestAds, sandbox);
        if (sandbox) {
          for (final placement in ['home', 'history', 'completion']) {
            expect(
              monetization.bannerId(placement),
              'ca-app-pub-3940256099942544/2435281174',
            );
          }
          expect(
            monetization.rewardId,
            'ca-app-pub-3940256099942544/1712485313',
          );
        } else {
          expect(
            monetization.bannerId('home'),
            const String.fromEnvironment('INKURI_ADMOB_HOME_BANNER'),
          );
          expect(
            monetization.rewardId,
            const String.fromEnvironment('INKURI_ADMOB_REWARDED'),
          );
        }
        expect(monetization.unlimited, isFalse);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(monetization.usesTestAds, isFalse);
        monetization.dispose();
      },
    );
  }

  test(
    'a failed environment lookup keeps production ads and no entitlement',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(ApplePurchaseVerifier.channel, (
        _,
      ) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });
      final monetization = Monetization(
        appleVerifier: const ApplePurchaseVerifier(),
      );
      await monetization.refreshAppleEnvironment();
      expect(monetization.usesTestAds, isFalse);
      expect(monetization.unlimited, isFalse);
      monetization.dispose();
    },
  );
}
