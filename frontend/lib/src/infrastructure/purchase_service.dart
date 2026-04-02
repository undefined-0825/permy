import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_proof.dart';

/// 課金状態（アプリ内管理用）
enum AppPurchaseStatus { free, pro, premium, pending, error }

/// 課金サービス（MVPシンプル実装）
/// - backend 検証連携あり（BillingProof 経由）
/// - 購入・復元・サブスク管理導線を提供
class PurchaseService {
  PurchaseService({
    required this.storage,
    InAppPurchase? iapInstance,
    this.platformOverride,
    this.queryProductDetailsOverride,
    this.buyNonConsumableOverride,
    this.restorePurchasesOverride,
    Stream<List<PurchaseDetails>>? purchaseStreamOverride,
  }) : _iap = iapInstance,
       _purchaseStreamOverride = purchaseStreamOverride;

  final FlutterSecureStorage storage;
  final InAppPurchase? _iap;
  final Stream<List<PurchaseDetails>>? _purchaseStreamOverride;

  /// テスト用の実行プラットフォーム上書き（"android" / "ios"）。
  final String? platformOverride;

  /// テスト用のストア呼び出し差し替え。
  final Future<ProductDetailsResponse> Function(Set<String> identifiers)?
  queryProductDetailsOverride;
  final Future<bool> Function({required PurchaseParam purchaseParam})?
  buyNonConsumableOverride;
  final Future<void> Function({String? applicationUserName})?
  restorePurchasesOverride;

  // Android Google Play 定期購入ID（SSOT）
  static const String _productIdAndroidPro = 'permy_pro_monthly';
  static const String _productIdAndroidPremium = 'permy_premium_monthly';
  // iOS App Store 定期購入ID（SSOT）
  static const String _productIdIosPro = 'com.sukimalab.permy.pro_monthly';
  static const String _productIdIosPremium =
      'com.sukimalab.permy.premium_monthly';

  static const String _storageKeyPurchaseStatus = 'purchase_status';

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<BillingProof> _billingProofController =
      StreamController<BillingProof>.broadcast();
  AppPurchaseStatus _currentStatus = AppPurchaseStatus.free;

  /// 初期化（アプリ起動時に呼ぶ）
  Future<void> initialize() async {
    // ストアから購入状態を読み込み
    await _loadPurchaseStatus();

    // 購入イベントのリスニング開始
    final purchaseUpdated =
        _purchaseStreamOverride ?? _iapClient.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: _onPurchaseDone,
      onError: _onPurchaseError,
    );
  }

  /// 終了処理
  void dispose() {
    _subscription?.cancel();
    _billingProofController.close();
  }

  /// 現在の購入状態を取得
  AppPurchaseStatus get currentStatus => _currentStatus;

  /// Pro版かどうか
  bool get isPro =>
      _currentStatus == AppPurchaseStatus.pro ||
      _currentStatus == AppPurchaseStatus.premium;

  String get currentPlan {
    if (_currentStatus == AppPurchaseStatus.premium) {
      return 'premium';
    }
    if (_currentStatus == AppPurchaseStatus.pro) {
      return 'pro';
    }
    return 'free';
  }

  /// backend検証用の課金証跡を通知するストリーム
  Stream<BillingProof> get billingProofStream => _billingProofController.stream;

  /// 購入可能かチェック
  Future<bool> isAvailable() async {
    return await _iapClient.isAvailable();
  }

  /// 商品情報を取得
  Future<List<ProductDetails>> getProducts({String plan = 'pro'}) async {
    final platform = _effectivePlatform();
    if (platform == 'unsupported') {
      throw Exception('現在の課金実装はiOS/Androidのみ対応です');
    }
    final productId = _productIdFor(platform: platform, plan: plan);
    final query = queryProductDetailsOverride ?? _iapClient.queryProductDetails;
    final response = await query({productId});

    if (response.error != null) {
      throw Exception('商品情報の取得に失敗しました: ${response.error}');
    }

    return response.productDetails;
  }

  /// 購入を開始
  Future<void> purchase({String plan = 'pro'}) async {
    final platform = _effectivePlatform();
    if (platform == 'unsupported') {
      throw Exception('現在の課金実装はiOS/Androidのみ対応です');
    }
    final products = await getProducts(plan: plan);
    if (products.isEmpty) {
      throw Exception('商品が見つかりません');
    }

    final product = products.first;
    final purchaseParam = PurchaseParam(productDetails: product);

    final buy = buyNonConsumableOverride ?? _iapClient.buyNonConsumable;
    await buy(purchaseParam: purchaseParam);
  }

  /// 購入を復元
  Future<void> restorePurchases() async {
    try {
      if (_effectivePlatform() == 'unsupported') {
        throw Exception('現在の課金実装はiOS/Androidのみ対応です');
      }
      final restore = restorePurchasesOverride ?? _iapClient.restorePurchases;
      await restore();
      // 復元結果は _onPurchaseUpdate で処理される
    } catch (e) {
      throw Exception('購入の復元に失敗しました: $e');
    }
  }

  /// サブスクリプション管理画面を開く（ストア設定へ遷移）
  Future<void> openSubscriptionManagement() async {
    // iOS: App Store Connect のサブスク管理画面へ
    // Android: Google Play のサブスク管理画面へ
    // in_app_purchase パッケージには直接的なAPIがないため、url_launcherで実装する
    // （SettingsScreenから呼び出す際に url_launcher を使用）
    throw UnimplementedError('url_launcher経由で実装');
  }

  /// 購入状態の更新イベント
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // 購入成功または復元成功
        final status = _statusFromProductId(purchase.productID);
        _currentStatus = status;
        _savePurchaseStatus(status);

        final productId = purchase.productID;
        final platform = _effectivePlatform() == 'ios' ? 'ios' : 'android';
        final purchaseToken =
            purchase.verificationData.serverVerificationData.isNotEmpty
            ? purchase.verificationData.serverVerificationData
            : purchase.verificationData.localVerificationData;

        if (purchaseToken.isNotEmpty) {
          _billingProofController.add(
            BillingProof(
              platform: platform,
              productId: productId,
              purchaseToken: purchaseToken,
            ),
          );
        }

        // 購入完了処理（ストアへの確認）
        if (purchase.pendingCompletePurchase) {
          _iapClient.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        // 購入エラー
        _currentStatus = AppPurchaseStatus.error;
      } else if (purchase.status == PurchaseStatus.pending) {
        // 購入保留中
        _currentStatus = AppPurchaseStatus.pending;
      }

      // 購入完了時の処理
      if (purchase.pendingCompletePurchase) {
        _iapClient.completePurchase(purchase);
      }
    }
  }

  void _onPurchaseDone() {
    // ストリーム終了時の処理（通常は発生しない）
  }

  void _onPurchaseError(Object error) {
    // 購入エラー時の処理
    _currentStatus = AppPurchaseStatus.error;
  }

  /// ローカルストレージから購入状態を読み込み
  Future<void> _loadPurchaseStatus() async {
    final statusString = await storage.read(key: _storageKeyPurchaseStatus);
    if (statusString == 'premium') {
      _currentStatus = AppPurchaseStatus.premium;
      return;
    }
    if (statusString == 'pro') {
      _currentStatus = AppPurchaseStatus.pro;
    } else {
      _currentStatus = AppPurchaseStatus.free;
    }
  }

  /// ローカルストレージに購入状態を保存
  Future<void> _savePurchaseStatus(AppPurchaseStatus status) async {
    final statusString = switch (status) {
      AppPurchaseStatus.premium => 'premium',
      AppPurchaseStatus.pro => 'pro',
      _ => 'free',
    };
    await storage.write(key: _storageKeyPurchaseStatus, value: statusString);
  }

  String _productIdFor({required String platform, required String plan}) {
    final normalizedPlan = plan == 'premium' ? 'premium' : 'pro';
    if (platform == 'ios') {
      return normalizedPlan == 'premium'
          ? _productIdIosPremium
          : _productIdIosPro;
    }
    return normalizedPlan == 'premium'
        ? _productIdAndroidPremium
        : _productIdAndroidPro;
  }

  AppPurchaseStatus _statusFromProductId(String productId) {
    if (productId.contains('premium')) {
      return AppPurchaseStatus.premium;
    }
    return AppPurchaseStatus.pro;
  }

  String _effectivePlatform() {
    final override = platformOverride?.trim().toLowerCase();
    if (override == 'ios' || override == 'android') {
      return override!;
    }
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unsupported';
  }

  InAppPurchase get _iapClient => _iap ?? InAppPurchase.instance;
}
