class UserProfileDataModel {
  String? numeroClient;
  String? nomClient;
  String? emailClient;
  String? dateTransaction;
  String? dateDernierRegles;
  String? dateDernierPayJour;
  String? dateDernierPayMois;
  String? statusClient;
  String? reqType;

  UserProfileDataModel({
    this.numeroClient,
    this.nomClient,
    this.emailClient,
    this.dateTransaction,
    this.dateDernierRegles,
    this.dateDernierPayJour,
    this.dateDernierPayMois,
    this.statusClient,
    this.reqType,
  });

  factory UserProfileDataModel.fromJson(Map<String, dynamic> json) {
    return UserProfileDataModel(
      numeroClient: json['numeroClient']?.toString(),
      nomClient: json['nomClient']?.toString(),
      emailClient: json['emailClient']?.toString(),
      dateTransaction: json['dateTransaction']?.toString(),
      dateDernierRegles: json['dateDernierRegles']?.toString(),
      dateDernierPayJour: json['dateDernierPayJour']?.toString(),
      dateDernierPayMois: json['dateDernierPayMois']?.toString(),
      statusClient: json['statusClient']?.toString(),
      reqType: json['reqType']?.toString(),
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