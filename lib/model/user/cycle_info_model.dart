class CycleInfoModel {
  String? dateCreation;
  String? dateFertiStart;
  String? dateFertireqEnd;
  String? dateRegle;
  String? dateProchaineReglesStart;
  String? dateProchaineReglesEnd;

  CycleInfoModel({
    this.dateCreation,
    this.dateFertiStart,
    this.dateFertireqEnd,
    this.dateRegle,
    this.dateProchaineReglesStart,
    this.dateProchaineReglesEnd,
  });

  factory CycleInfoModel.fromJson(Map<String, dynamic> json) {
    return CycleInfoModel(
      dateCreation: json['dateCreation']?.toString(),
      dateFertiStart: json['dateFertiStart']?.toString(),
      dateFertireqEnd: json['dateFertireqEnd']?.toString(),
      dateRegle: json['dateRegle']?.toString(),
      dateProchaineReglesStart: json['dateProchaineReglesStart']?.toString(),
      dateProchaineReglesEnd: json['dateProchaineReglesEnd']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateCreation': dateCreation,
      'dateFertiStart': dateFertiStart,
      'dateFertireqEnd': dateFertireqEnd,
      'dateRegle': dateRegle,
      'dateProchaineReglesStart': dateProchaineReglesStart,
      'dateProchaineReglesEnd': dateProchaineReglesEnd,
    };
  }
}


