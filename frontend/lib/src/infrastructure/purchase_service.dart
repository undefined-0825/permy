import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 課金状態（アプリ内管理用）
enum AppPurchaseStatus { free, pro, pending, error }

/// 課金サービス（MVPシンプル実装）
/// - ローカル状態管理のみ（backend連携なし）
/// - 購入・復元・サブスク管理導線を提供
class PurchaseService {
  PurchaseService({required this.storage, InAppPurchase? iapInstance})
    : _iap = iapInstance ?? InAppPurchase.instance;

  final FlutterSecureStorage storage;
  final InAppPurchase _iap;

  // 商品ID（ストア登録後に設定）
  // TODO: ストア登録時に実際の商品IDに置き換える
  static const String _productIdAndroid = 'pro_monthly';
  static const String _productIdIOS = 'com.sukimalab.permy.pro_monthly';

  static const String _storageKeyPurchaseStatus = 'purchase_status';

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  AppPurchaseStatus _currentStatus = AppPurchaseStatus.free;

  /// 初期化（アプリ起動時に呼ぶ）
  Future<void> initialize() async {
    // ストアから購入状態を読み込み
    await _loadPurchaseStatus();

    // 購入イベントのリスニング開始
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: _onPurchaseDone,
      onError: _onPurchaseError,
    );
  }

  /// 終了処理
  void dispose() {
    _subscription?.cancel();
  }

  /// 現在の購入状態を取得
  AppPurchaseStatus get currentStatus => _currentStatus;

  /// Pro版かどうか
  bool get isPro => _currentStatus == AppPurchaseStatus.pro;

  /// 購入可能かチェック
  Future<bool> isAvailable() async {
    return await _iap.isAvailable();
  }

  /// 商品情報を取得
  Future<List<ProductDetails>> getProducts() async {
    final productId = Platform.isAndroid ? _productIdAndroid : _productIdIOS;
    final response = await _iap.queryProductDetails({productId});

    if (response.error != null) {
      throw Exception('商品情報の取得に失敗しました: ${response.error}');
    }

    return response.productDetails;
  }

  /// 購入を開始
  Future<void> purchase() async {
    final products = await getProducts();
    if (products.isEmpty) {
      throw Exception('商品が見つかりません');
    }

    final product = products.first;
    final purchaseParam = PurchaseParam(productDetails: product);

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 購入を復元
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
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
        _currentStatus = AppPurchaseStatus.pro;
        _savePurchaseStatus(AppPurchaseStatus.pro);

        // 購入完了処理（ストアへの確認）
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
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
        _iap.completePurchase(purchase);
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
    if (statusString == 'pro') {
      _currentStatus = AppPurchaseStatus.pro;
    } else {
      _currentStatus = AppPurchaseStatus.free;
    }
  }

  /// ローカルストレージに購入状態を保存
  Future<void> _savePurchaseStatus(AppPurchaseStatus status) async {
    final statusString = status == AppPurchaseStatus.pro ? 'pro' : 'free';
    await storage.write(key: _storageKeyPurchaseStatus, value: statusString);
  }
}
