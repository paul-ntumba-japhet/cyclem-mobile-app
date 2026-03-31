class UserTransaction {
  final double montantPaye;
  final String numeroClient;
  final String dateTransaction;
  final String transactionId;
  final String serviceLivre;
  final String codeRecu;
  final String resDescription;
  final String reqSource;

  UserTransaction({
    required this.montantPaye,
    required this.numeroClient,
    required this.dateTransaction,
    required this.transactionId,
    required this.serviceLivre,
    required this.codeRecu,
    required this.resDescription,
    required this.reqSource,
  });

  factory UserTransaction.fromJson(Map<String, dynamic> json) {
    return UserTransaction(
      montantPaye: (json['montantPaye'] is num)
          ? (json['montantPaye'] as num).toDouble()
          : double.tryParse(json['montantPaye']?.toString() ?? '0') ?? 0.0,
      numeroClient: json['numeroClient']?.toString() ?? '',
      dateTransaction: json['dateTransaction']?.toString() ?? '',
      transactionId: json['transactionId']?.toString() ?? '',
      serviceLivre: json['serviceLivre']?.toString() ?? '',
      codeRecu: json['codeRecu']?.toString() ?? '',
      resDescription: json['resDescription']?.toString() ?? '',
      reqSource: json['reqSource']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'montantPaye': montantPaye,
      'numeroClient': numeroClient,
      'dateTransaction': dateTransaction,
      'transactionId': transactionId,
      'serviceLivre': serviceLivre,
      'codeRecu': codeRecu,
      'resDescription': resDescription,
      'reqSource': reqSource,
    };
  }
}

