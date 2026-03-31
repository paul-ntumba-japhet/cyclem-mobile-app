/// Payment Plan Model
/// Represents a payment plan/amount option from the QuickShare API
/// Endpoint: GET /apicyclem/paiement/montants/{currency}
class PaymentPlanModel {
  final String montant;
  final String priceIdStripe;
  final String description;
  final String currency;

  PaymentPlanModel({
    required this.montant,
    required this.priceIdStripe,
    required this.description,
    required this.currency,
  });

  factory PaymentPlanModel.fromJson(Map<String, dynamic> json) {
    return PaymentPlanModel(
      montant: json['montant']?.toString() ?? '',
      priceIdStripe: json['priceIdStripe']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'montant': montant,
      'priceIdStripe': priceIdStripe,
      'description': description,
      'currency': currency,
    };
  }

  /// Get amount as double
  double get amountAsDouble {
    return double.tryParse(montant) ?? 0.0;
  }

  @override
  String toString() {
    return 'PaymentPlanModel(description: $description, montant: $montant, currency: $currency, priceIdStripe: $priceIdStripe)';
  }
}

