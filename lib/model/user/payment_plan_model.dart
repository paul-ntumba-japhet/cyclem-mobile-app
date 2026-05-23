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

  /// UI slot: 0 = trial, 1 = monthly, 2 = annual (Stripe USD: ~8.999 / 13).
  int get displayTypeIndex {
    final amount = amountAsDouble;
    if (amount == 0) return 0;
    if (amount >= 10) return 2;
    return 1;
  }

  @override
  String toString() {
    return 'PaymentPlanModel(description: $description, montant: $montant, currency: $currency, priceIdStripe: $priceIdStripe)';
  }
}

/// Orders plans for checkout: trial (0$), monthly (~8.999$), annual (13$).
List<PaymentPlanModel> orderPaymentPlansForDisplay(List<PaymentPlanModel> plans) {
  final ordered = List<PaymentPlanModel>.from(plans);
  ordered.sort((a, b) {
    final byAmount = a.amountAsDouble.compareTo(b.amountAsDouble);
    if (byAmount != 0) return byAmount;
    return a.displayTypeIndex.compareTo(b.displayTypeIndex);
  });
  return ordered;
}

