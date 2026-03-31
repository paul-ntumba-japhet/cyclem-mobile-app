/// Stripe Config Model
/// Represents the Stripe configuration response from the QuickShare API
/// Endpoint: GET /gateway-quickshare-api/stripe/config
class StripeConfigModel {
  final String publishableKey;

  StripeConfigModel({
    required this.publishableKey,
  });

  factory StripeConfigModel.fromJson(Map<String, dynamic> json) {
    return StripeConfigModel(
      publishableKey: json['publishableKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publishableKey': publishableKey,
    };
  }

  @override
  String toString() {
    return 'StripeConfigModel(publishableKey: ${publishableKey.length > 20 ? publishableKey.substring(0, 20) + "..." : publishableKey})';
  }
}

