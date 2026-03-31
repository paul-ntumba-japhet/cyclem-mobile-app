/// Stripe Customer Model
/// Represents the Stripe customer creation response from the QuickShare API
/// Endpoint: POST /gateway-quickshare-api/stripe/create-customer
class StripeCustomerModel {
  final String customer;

  StripeCustomerModel({
    required this.customer,
  });

  factory StripeCustomerModel.fromJson(Map<String, dynamic> json) {
    return StripeCustomerModel(
      customer: json['customer']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer': customer,
    };
  }

  @override
  String toString() {
    return 'StripeCustomerModel(customer: $customer)';
  }
}
