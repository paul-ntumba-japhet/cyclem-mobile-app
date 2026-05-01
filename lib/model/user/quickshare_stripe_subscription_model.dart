class QuickshareStripeSubscriptionModel {
  final bool status;
  final QuickshareStripeSubscriptionData data;

  QuickshareStripeSubscriptionModel({
    required this.status,
    required this.data,
  });

  factory QuickshareStripeSubscriptionModel.fromJson(
      Map<String, dynamic> json) {
    return QuickshareStripeSubscriptionModel(
      status: json['status'] == true,
      data: QuickshareStripeSubscriptionData.fromJson(
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

class QuickshareStripeSubscriptionData {
  final String clientSecret;

  QuickshareStripeSubscriptionData({
    required this.clientSecret,
  });

  factory QuickshareStripeSubscriptionData.fromJson(Map<String, dynamic> json) {
    return QuickshareStripeSubscriptionData(
      clientSecret: json['clientSecret']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientSecret': clientSecret,
    };
  }
}
