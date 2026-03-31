class SubscriptionInfoModel {
  final String numeroClient;
  final String nomClient;
  final String emailClient;
  final String dateTransaction;
  final String dateDernierRegles;
  final String dateDernierPayJour;
  final String dateDernierPayMois;
  final String statusClient;
  final String reqType;

  SubscriptionInfoModel({
    required this.numeroClient,
    required this.nomClient,
    required this.emailClient,
    required this.dateTransaction,
    required this.dateDernierRegles,
    required this.dateDernierPayJour,
    required this.dateDernierPayMois,
    required this.statusClient,
    required this.reqType,
  });

  factory SubscriptionInfoModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfoModel(
      numeroClient: json['numeroClient']?.toString() ?? '',
      nomClient: json['nomClient']?.toString() ?? '',
      emailClient: json['emailClient']?.toString() ?? '',
      dateTransaction: json['dateTransaction']?.toString() ?? '',
      dateDernierRegles: json['dateDernierRegles']?.toString() ?? '',
      dateDernierPayJour: json['dateDernierPayJour']?.toString() ?? '',
      dateDernierPayMois: json['dateDernierPayMois']?.toString() ?? '',
      statusClient: json['statusClient']?.toString() ?? '',
      reqType: json['reqType']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numeroClient': numeroClient,
      'nomClient': nomClient,
      'emailClient': emailClient,
      'dateTransaction': dateTransaction,
      'dateDernierRegles': dateDernierRegles,
      'dateDernierPayJour': dateDernierPayJour,
      'dateDernierPayMois': dateDernierPayMois,
      'statusClient': statusClient,
      'reqType': reqType,
    };
  }
}

