/// Response model for:
/// POST /api/stripe/setup-intent/payment-method
class StripeSetupIntentPaymentMethodModel {
  final bool status;
  final StripeSetupIntentPaymentMethodData data;

  StripeSetupIntentPaymentMethodModel({
    required this.status,
    required this.data,
  });

  factory StripeSetupIntentPaymentMethodModel.fromJson(
      Map<String, dynamic> json) {
    return StripeSetupIntentPaymentMethodModel(
      status: json['status'] == true,
      data: StripeSetupIntentPaymentMethodData.fromJson(
        (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.toJson(),
    };
  }
}

class StripeSetupIntentPaymentMethodData {
  final String customerId;
  final String setupIntentId;
  final String clientSecret;
  final String ephemeralKeySecret;
  final String publishableKey;

  StripeSetupIntentPaymentMethodData({
    required this.customerId,
    required this.setupIntentId,
    required this.clientSecret,
    required this.ephemeralKeySecret,
    required this.publishableKey,
  });

  factory StripeSetupIntentPaymentMethodData.fromJson(
      Map<String, dynamic> json) {
    return StripeSetupIntentPaymentMethodData(
      customerId: json['customerId']?.toString() ?? '',
      setupIntentId: json['setupIntentId']?.toString() ?? '',
      clientSecret: json['clientSecret']?.toString() ?? '',
      ephemeralKeySecret: json['ephemeralKeySecret']?.toString() ?? '',
      publishableKey: json['publishableKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'setupIntentId': setupIntentId,
      'clientSecret': clientSecret,
      'ephemeralKeySecret': ephemeralKeySecret,
      'publishableKey': publishableKey,
    };
  }
}
