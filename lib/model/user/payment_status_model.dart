/// Payment Status Model
/// Represents the payment status response from the QuickShare API
/// Endpoint: GET /apicyclem/paiement/ids/{phoneNumber}
class PaymentStatusModel {
  final String message;
  final String code;

  PaymentStatusModel({
    required this.message,
    required this.code,
  });

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    return PaymentStatusModel(
      message: json['message']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'code': code,
    };
  }

  /// Check if payment is active
  /// Returns true if code is not "300" (Paiement inactif)
  bool get isActive {
    return code != '300';
  }

  /// Check if payment is inactive
  /// Returns true if code is "300" (Paiement inactif)
  bool get isInactive {
    return code == '300';
  }

  @override
  String toString() {
    return 'PaymentStatusModel(message: $message, code: $code, isActive: $isActive)';
  }
}

