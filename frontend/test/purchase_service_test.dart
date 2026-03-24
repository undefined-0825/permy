import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:sample_app/src/infrastructure/purchase_service.dart';

ProductDetails _product(String id) {
  return ProductDetails(
    id: id,
    title: 'Plus',
    description: 'Permy Plus',
    price: '¥2,980',
    rawPrice: 2980,
    currencyCode: 'JPY',
  );
}

void main() {
  group('PurchaseService', () {
    test('iOS では iOS 商品IDで商品取得する', () async {
      Set<String>? queriedIds;

      final service = PurchaseService(
        storage: const FlutterSecureStorage(),
        platformOverride: 'ios',
        queryProductDetailsOverride: (ids) async {
          queriedIds = ids;
          return ProductDetailsResponse(
            productDetails: <ProductDetails>[
              _product('com.sukimalab.permy.pro_monthly'),
            ],
            notFoundIDs: const <String>[],
          );
        },
      );

      final products = await service.getProducts();

      expect(queriedIds, {'com.sukimalab.permy.pro_monthly'});
      expect(products.single.id, 'com.sukimalab.permy.pro_monthly');
    });

    test('iOS でも purchase が動作し backend 検証用データに繋がる', () async {
      String? purchasedProductId;

      final service = PurchaseService(
        storage: const FlutterSecureStorage(),
        platformOverride: 'ios',
        queryProductDetailsOverride: (ids) async {
          return ProductDetailsResponse(
            productDetails: <ProductDetails>[
              _product('com.sukimalab.permy.pro_monthly'),
            ],
            notFoundIDs: const <String>[],
          );
        },
        buyNonConsumableOverride: ({required purchaseParam}) async {
          purchasedProductId = purchaseParam.productDetails.id;
          return true;
        },
      );

      await service.purchase();

      expect(purchasedProductId, 'com.sukimalab.permy.pro_monthly');
    });

    test('Android は従来の商品IDを維持する', () async {
      Set<String>? queriedIds;

      final service = PurchaseService(
        storage: const FlutterSecureStorage(),
        platformOverride: 'android',
        queryProductDetailsOverride: (ids) async {
          queriedIds = ids;
          return ProductDetailsResponse(
            productDetails: <ProductDetails>[_product('permy_pro_monthly')],
            notFoundIDs: const <String>[],
          );
        },
      );

      final products = await service.getProducts();

      expect(queriedIds, {'permy_pro_monthly'});
      expect(products.single.id, 'permy_pro_monthly');
    });
  });
}
