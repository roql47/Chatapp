import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

// 포인트 상품 정의
class PointProduct {
  final String id;
  final int points;
  final int bonusPoints;
  final String title;

  const PointProduct({
    required this.id,
    required this.points,
    this.bonusPoints = 0,
    required this.title,
  });

  int get totalPoints => points + bonusPoints;
}

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // 상품 목록
  static const List<PointProduct> products = [
    PointProduct(
      id: 'points_100',
      points: 100,
      bonusPoints: 0,
      title: '100 포인트',
    ),
    PointProduct(
      id: 'points_500',
      points: 500,
      bonusPoints: 50,
      title: '500 포인트 + 50 보너스',
    ),
    PointProduct(
      id: 'points_1000',
      points: 1000,
      bonusPoints: 150,
      title: '1000 포인트 + 150 보너스',
    ),
  ];

  static const Set<String> _productIds = {
    'points_100',
    'points_500',
    'points_1000',
  };

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;

  List<ProductDetails> get availableProducts => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;

  // 콜백
  Function(int points, String productId)? onPurchaseSuccess;
  Function(String error)? onPurchaseError;

  // 초기화
  Future<void> initialize() async {
    // 스토어 사용 가능 여부 확인
    _isAvailable = await _inAppPurchase.isAvailable();
    
    if (!_isAvailable) {
      print('⚠️ 인앱결제 사용 불가');
      return;
    }

    // 플랫폼별 설정
    if (Platform.isIOS) {
      final iosPlatformAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    // 구매 스트림 구독
    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => print('구매 스트림 오류: $error'),
    );

    // 상품 정보 로드
    await _loadProducts();
  }

  // 상품 정보 로드
  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        print('찾을 수 없는 상품: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      print('로드된 상품: ${_products.length}개');
    } catch (e) {
      print('상품 로드 오류: $e');
    }
  }

  // 구매 처리
  Future<bool> buyProduct(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('스토어를 사용할 수 없습니다.');
      return false;
    }

    final ProductDetails? product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('상품을 찾을 수 없습니다.'),
    );

    if (product == null) {
      onPurchaseError?.call('상품을 찾을 수 없습니다.');
      return false;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      _purchasePending = true;
      final success = await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
      );
      return success;
    } catch (e) {
      _purchasePending = false;
      onPurchaseError?.call('구매 시작 실패: $e');
      return false;
    }
  }

  // 구매 업데이트 처리
  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        _purchasePending = false;

        if (purchaseDetails.status == PurchaseStatus.error) {
          _handleError(purchaseDetails.error);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _verifyAndDeliverProduct(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  // 구매 검증 및 포인트 지급
  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    // TODO: 서버에서 구매 검증
    // purchaseDetails.verificationData를 서버로 전송하여 검증

    // 해당 상품의 포인트 찾기
    final product = products.firstWhere(
      (p) => p.id == purchaseDetails.productID,
      orElse: () => const PointProduct(id: '', points: 0, title: ''),
    );

    if (product.id.isNotEmpty) {
      onPurchaseSuccess?.call(product.totalPoints, product.id);
    }
  }

  // 오류 처리
  void _handleError(IAPError? error) {
    final errorMessage = error?.message ?? '알 수 없는 오류가 발생했습니다.';
    print('구매 오류: $errorMessage');
    onPurchaseError?.call(errorMessage);
  }

  // 이전 구매 복원 (iOS)
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  // 정리
  void dispose() {
    _subscription?.cancel();
  }

  // 상품 ID로 PointProduct 찾기
  PointProduct? getProductById(String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  // 상품 ID로 ProductDetails 찾기 (가격 정보 포함)
  ProductDetails? getProductDetails(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }
}

// iOS 결제 대리자
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
