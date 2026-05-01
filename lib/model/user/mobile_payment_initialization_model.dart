/// Response model for:
/// POST /quickshare-api/connector/api/v1/852112327/payInSender
class MobilePaymentInitializationModel {
  final String responseCode;
  final String responseDesc;
  final String transactionId;

  MobilePaymentInitializationModel({
    required this.responseCode,
    required this.responseDesc,
    required this.transactionId,
  });

  factory MobilePaymentInitializationModel.fromJson(Map<String, dynamic> json) {
    return MobilePaymentInitializationModel(
      responseCode: json['responsecode']?.toString() ?? '',
      responseDesc: json['responsedesc']?.toString() ?? '',
      transactionId: json['transactionid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'responsecode': responseCode,
      'responsedesc': responseDesc,
      'transactionid': transactionId,
    };
  }
}
