import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'play_purchase_verifier.dart';
import 'apple_purchase_verifier.dart';

class Monetization extends ChangeNotifier {
  Monetization({this.verifier, this.appleVerifier});

  static const productId = 'inkuri_unlimited';
  static const appleProductId = 'incre_unlimited';
  String get storeProductId => _android ? productId : appleProductId;
  static const previewEnabled =
      kDebugMode && bool.fromEnvironment('INKURI_MONETIZATION_TEST');
  static const _storeSandbox = bool.fromEnvironment('INKURI_STORE_SANDBOX');
  static const _production =
      kReleaseMode && bool.fromEnvironment('INKURI_MONETIZATION_PRODUCTION');
  static const _appleProduction =
      kReleaseMode &&
      bool.fromEnvironment('INKURI_IOS_MONETIZATION_PRODUCTION');
  static const _verifiedUntilKey = 'inkuri.unlimited.verified_until.v1';

  final PlayPurchaseVerifier? verifier;
  final ApplePurchaseVerifier? appleVerifier;
  bool get isProduction => verifier != null || appleVerifier != null;

  bool unlimited = false;
  bool storeReady = false;
  bool adsReady = false;
  bool adPrivacyOptionsRequired = false;
  ProductDetails? product;
  String? purchaseMessage;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _disposed = false;
  bool _started = false;
  bool _adsInitialized = false;
  bool _checkingAds = false;
  bool _restoring = false;
  bool _openingPurchase = false;
  bool _sandboxApp = false;
  Future<void> _purchaseUpdates = Future.value();

  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  bool get usesTestAds => !isProduction || (!_android && _sandboxApp);
  String get purchasePrice => _android ? product?.price ?? '' : '900円';
  String get purchasePriceNote =>
      _android ? '' : '日本での価格は900円（買い切り）です。お支払い前にAppleの購入確認画面で確定価格をご確認ください。';

  Future<void> refreshAppleEnvironment() async {
    if (_android || appleVerifier == null) return;
    try {
      _sandboxApp = await appleVerifier!.isSandboxApp();
      debugPrint('Inkuri ads: ${_sandboxApp ? 'sandbox' : 'production'}');
    } catch (_) {
      // Unknown environments keep production units; purchase rights are untouched.
      debugPrint('Inkuri ads: environment_unavailable');
    }
  }

  String bannerId(String placement) {
    if (!usesTestAds) {
      return switch (placement) {
        'home' => const String.fromEnvironment('INKURI_ADMOB_HOME_BANNER'),
        'history' => const String.fromEnvironment(
          'INKURI_ADMOB_HISTORY_BANNER',
        ),
        'completion' => const String.fromEnvironment(
          'INKURI_ADMOB_RESULT_BANNER',
        ),
        _ => throw ArgumentError.value(placement, 'placement'),
      };
    }
    return _android
        ? 'ca-app-pub-3940256099942544/9214589741'
        : 'ca-app-pub-3940256099942544/2435281174';
  }

  String get rewardId => !usesTestAds
      ? const String.fromEnvironment('INKURI_ADMOB_REWARDED')
      : _android
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  static Monetization? configured() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    if (_production && defaultTargetPlatform == TargetPlatform.android) {
      return Monetization(
        verifier: PlayPurchaseVerifier(
          Uri.parse(const String.fromEnvironment('INKURI_PLAY_VERIFY_URL')),
        ),
      );
    }
    if (_appleProduction && defaultTargetPlatform == TargetPlatform.iOS) {
      return Monetization(appleVerifier: const ApplePurchaseVerifier());
    }
    return previewEnabled ? Monetization() : null;
  }

  Future<void> connect() async {
    if (_started || _disposed || (!previewEnabled && !isProduction)) return;
    _started = true;
    if (isProduction) {
      try {
        final expiration = await SharedPreferencesAsync().getInt(
          _verifiedUntilKey,
        );
        unlimited =
            verifier != null &&
            expiration != null &&
            expiration > DateTime.now().millisecondsSinceEpoch;
        _refresh();
      } catch (_) {
        // The store can still restore a purchase when the local cache is unavailable.
      }
      if (verifier != null) {
        try {
          await FirebaseAppCheck.instance.activate();
        } catch (_) {
          _message('購入確認サービスに接続できませんでした。');
        }
      }
    }
    await refreshAppleEnvironment();
    if (_storeSandbox || isProduction) await _connectStore();
    await _refreshAds();
  }

  Future<void> _refreshAds() async {
    if (unlimited || _disposed || _checkingAds) return;
    _checkingAds = true;
    try {
      if (isProduction) {
        final consent = ConsentInformation.instance;
        final updated = Completer<bool>();
        consent.requestConsentInfoUpdate(
          ConsentRequestParameters(),
          () => updated.complete(true),
          (_) => updated.complete(false),
        );
        if (await updated.future.timeout(const Duration(seconds: 15)) &&
            !_disposed &&
            !unlimited) {
          final closed = Completer<void>();
          await ConsentForm.loadAndShowConsentFormIfRequired(
            (_) => closed.complete(),
          );
          await closed.future;
        }
        adPrivacyOptionsRequired =
            await consent.getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
        if (!await consent.canRequestAds()) {
          adsReady = false;
          _refresh();
          return;
        }
      }
      await _enableAds();
    } catch (_) {
      // A failed SDK initialization leaves the practice flow available.
    } finally {
      _checkingAds = false;
    }
  }

  Future<void> _enableAds() async {
    if (_disposed || unlimited) return;
    if (!_adsInitialized) {
      await MobileAds.instance.initialize();
      _adsInitialized = true;
    }
    adsReady = !_disposed && !unlimited;
    _refresh();
  }

  Future<void> showAdPrivacyOptions() async {
    try {
      final closed = Completer<void>();
      await ConsentForm.showPrivacyOptionsForm((_) => closed.complete());
      await closed.future;
      if (await ConsentInformation.instance.canRequestAds()) {
        await _enableAds();
      } else {
        adsReady = false;
        _refresh();
      }
    } catch (_) {
      // The settings screen remains usable if the consent form cannot open.
    }
  }

  Future<void> _connectStore() async {
    final store = InAppPurchase.instance;
    _subscription = store.purchaseStream.listen((purchases) {
      _purchaseUpdates = _purchaseUpdates
          .then((_) => _acceptPurchases(purchases))
          .catchError((Object _) => _message('購入情報を確認できませんでした。'));
    }, onError: (Object _) => _message('購入情報を確認できませんでした。'));
    try {
      if (await store.isAvailable()) {
        final response = await store.queryProductDetails({storeProductId});
        product = response.productDetails.firstOrNull;
        storeReady = true;
        if (appleVerifier != null) {
          await _checkAppleOwnership();
        } else {
          await restore();
        }
      }
    } catch (_) {
      _message('購入情報を確認できませんでした。');
    } finally {
      _refresh();
    }
  }

  Future<void> _acceptPurchases(List<PurchaseDetails> purchases) async {
    if (_disposed) return;
    if (verifier != null && purchases.isEmpty && unlimited) {
      await _saveEntitlement(false);
    }
    for (final purchase in purchases) {
      if (purchase.productID != storeProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            if (verifier case final checker?) {
              final entitled = await checker.verify(
                purchase.verificationData.serverVerificationData,
              );
              await _saveEntitlement(entitled);
              if (!entitled) {
                _message('有効な購入を確認できませんでした。');
                break;
              }
            } else if (appleVerifier case final checker?) {
              final entitled = await checker.verify(storeProductId);
              await _saveEntitlement(entitled);
              if (!entitled) {
                _message('有効な購入を確認できませんでした。');
                break;
              }
            } else {
              unlimited = true;
            }
            _message('無制限プランを利用できます。');
            if ((appleVerifier != null || !isProduction) &&
                purchase.pendingCompletePurchase) {
              await InAppPurchase.instance.completePurchase(purchase);
            }
          } catch (_) {
            _message('購入を確認できませんでした。「購入を復元」で再試行できます。');
          }
        case PurchaseStatus.pending:
          _message('お支払いの確認を待っています。');
        case PurchaseStatus.error:
          _message('購入を完了できませんでした。');
        case PurchaseStatus.canceled:
          _message('購入をキャンセルしました。');
      }
    }
  }

  Future<void> _saveEntitlement(bool value) async {
    final wasUnlimited = unlimited;
    unlimited = value;
    _refresh();
    // iOS always reads Apple's signed entitlements, including its offline cache.
    // An editable preferences value must not unlock an Apple purchase.
    if (appleVerifier != null) {
      if (!value && wasUnlimited) unawaited(_refreshAds());
      return;
    }
    final prefs = SharedPreferencesAsync();
    if (value) {
      await prefs.setInt(
        _verifiedUntilKey,
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_verifiedUntilKey);
      if (wasUnlimited) unawaited(_refreshAds());
    }
  }

  Future<void> buy() async {
    final item = product;
    if (item == null || unlimited || _openingPurchase) return;
    _openingPurchase = true;
    try {
      await verifier?.appCheckToken();
      if (_disposed || unlimited) return;
      final opened = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: item),
      );
      if (!opened) _message('購入画面を開けませんでした。');
    } catch (_) {
      _message('購入画面を開けませんでした。');
    } finally {
      _openingPurchase = false;
    }
  }

  Future<void> restore() async {
    if (_restoring || _disposed) return;
    _restoring = true;
    try {
      await InAppPurchase.instance.restorePurchases();
      await _purchaseUpdates;
      if (appleVerifier != null) await _checkAppleOwnership();
    } catch (_) {
      _message('購入を復元できませんでした。');
    } finally {
      _restoring = false;
    }
  }

  Future<void> recheckOwnership() async {
    if (_started && isProduction && storeReady && !_disposed) {
      if (appleVerifier != null) {
        try {
          await _checkAppleOwnership();
        } catch (_) {
          _message('購入情報を確認できませんでした。「購入を復元」で再試行できます。');
        }
      } else {
        await restore();
      }
    }
  }

  Future<void> _checkAppleOwnership() async {
    final checker = appleVerifier;
    if (checker != null) {
      await _saveEntitlement(await checker.verify(storeProductId));
    }
  }

  Future<bool> watchReward() async {
    if (unlimited || !adsReady) return false;
    final loaded = Completer<RewardedAd?>();
    var expired = false;
    try {
      await RewardedAd.load(
        adUnitId: rewardId,
        request: const AdRequest(nonPersonalizedAds: true),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (expired) {
              ad.dispose();
            } else {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (error) {
            debugPrint('Inkuri ads: reward_failed code=${error.code}');
            if (!expired) loaded.complete(null);
          },
        ),
      );
      final ad = await loaded.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          expired = true;
          return null;
        },
      );
      if (ad == null) return false;
      if (unlimited || _disposed || !adsReady) {
        await ad.dispose();
        return false;
      }
      var earned = false;
      final dismissed = Completer<bool>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) => dismissed.complete(earned),
        onAdFailedToShowFullScreenContent: (_, _) => dismissed.complete(false),
      );
      try {
        await ad.show(onUserEarnedReward: (_, _) => earned = true);
        return await dismissed.future;
      } finally {
        await ad.dispose();
      }
    } catch (_) {
      return false;
    }
  }

  void _message(String value) {
    purchaseMessage = value;
    _refresh();
  }

  void _refresh() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class PracticeBanner extends StatefulWidget {
  const PracticeBanner({
    super.key,
    required this.adUnitId,
    required this.width,
  });

  final String adUnitId;
  final int width;

  @override
  State<PracticeBanner> createState() => _PracticeBannerState();
}

class _PracticeBannerState extends State<PracticeBanner> {
  BannerAd? _ad;
  AdSize? _size;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.getInlineAdaptiveBannerAdSize(widget.width, 60),
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          debugPrint('Inkuri ads: banner_loaded');
          final size = await (ad as BannerAd).getPlatformAdSize();
          if (mounted && identical(ad, _ad) && size != null) {
            setState(() => _size = size);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Inkuri ads: banner_failed code=${error.code}');
          if (identical(_ad, ad)) _ad = null;
          ad.dispose();
        },
      ),
    );
    unawaited(_ad!.load().catchError((Object _) {}));
  }

  @override
  void dispose() {
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final ad = _ad;
    if (size == null || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
