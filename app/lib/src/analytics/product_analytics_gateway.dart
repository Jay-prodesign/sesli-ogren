import '../domain/authenticated_learner.dart';
import 'product_analytics.dart';

class ProductAnalyticsGatewayException implements Exception {
  const ProductAnalyticsGatewayException(this.message);

  final String message;

  @override
  String toString() => 'ProductAnalyticsGatewayException: $message';
}

abstract interface class ProductAnalyticsGateway {
  Future<void> record({
    required AuthenticatedLearner learner,
    required ProductAnalyticsEnvelope envelope,
    String? serverMaterialId,
  });
}

class UnavailableProductAnalyticsGateway implements ProductAnalyticsGateway {
  const UnavailableProductAnalyticsGateway();

  @override
  Future<void> record({
    required AuthenticatedLearner learner,
    required ProductAnalyticsEnvelope envelope,
    String? serverMaterialId,
  }) {
    throw const ProductAnalyticsGatewayException('Product analytics gateway is unavailable.');
  }
}
