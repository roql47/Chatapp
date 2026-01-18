import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

// 포인트 상품 정의
class PointProduct {
  final String id;
  final int points;
  final int bonusPoints;
  final String title;
  final bool isConsumable; // 소비성 여부 (포인트=true, 광고제거=false)

  const PointProduct({
    required this.id,
    required this.points,
    this.bonusPoints = 0,
    required this.title,
    this.isConsumable = true,
  });

  int get totalPoints => points + bonusPoints;
}

// 광고 제거 상품 ID
const String kAdRemovalProductId = 'ad_removal';

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
    // 광고 제거 상품 (비소비성)
    PointProduct(
      id: kAdRemovalProductId,
      points: 0,
      title: '광고 제거',
      isConsumable: false,
    ),
  ];

  static const Set<String> _productIds = {
    'points_100',
    'points_500',
    'points_1000',
    kAdRemovalProductId,
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
  Function()? onAdRemovalSuccess; // 광고 제거 성공 콜백

  // 초기화
  Future<void> initialize() async {
    // 스토어 사용 가능 여부 확인
    _isAvailable = await _inAppPurchase.isAvailable();
    
    if (!_isAvailable) {
      print('⚠️ 인앱결제 사용 불가');
      return;
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
    print('🔵 buyProduct 호출: $productId');
    print('🔵 스토어 사용 가능: $_isAvailable');
    print('🔵 로드된 상품: ${_products.map((p) => p.id).toList()}');
    
    if (!_isAvailable) {
      print('🔴 스토어 사용 불가');
      onPurchaseError?.call('스토어를 사용할 수 없습니다.');
      return false;
    }

    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
      print('🔵 상품 찾음: ${product.id}, 가격: ${product.price}');
    } catch (e) {
      print('🔴 상품을 찾을 수 없음: $productId');
      print('🔴 등록된 상품 ID: ${_products.map((p) => p.id).toList()}');
      onPurchaseError?.call('상품을 찾을 수 없습니다. 스토어에 상품이 등록되어 있는지 확인해주세요.');
      return false;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    // 상품 정보에서 소비성 여부 확인
    final pointProduct = getProductById(productId);
    final isConsumable = pointProduct?.isConsumable ?? true;
    print('🔵 소비성 여부: $isConsumable');

    try {
      _purchasePending = true;
      bool success;
      if (isConsumable) {
        // 포인트 상품 (소비성)
        print('🔵 소비성 상품 구매 시작...');
        success = await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      } else {
        // 광고 제거 상품 (비소비성)
        print('🔵 비소비성 상품 구매 시작...');
        success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
      print('🔵 구매 요청 결과: $success');
      return success;
    } catch (e) {
      _purchasePending = false;
      print('🔴 구매 시작 오류: $e');
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

    final productId = purchaseDetails.productID;
    
    // 광고 제거 상품 처리
    if (productId == kAdRemovalProductId) {
      print('🟢 광고 제거 구매 완료!');
      onAdRemovalSuccess?.call();
      return;
    }

    // 해당 상품의 포인트 찾기
    final product = products.firstWhere(
      (p) => p.id == productId,
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
