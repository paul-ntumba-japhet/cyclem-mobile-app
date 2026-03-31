/// Chat backend auth response from POST /chat-backend/api/auth/login
/// Response: { "token": "...", "tokenType": "Bearer" }
class ChatBackendAuthModel {
  final String token;
  final String tokenType;

  ChatBackendAuthModel({
    required this.token,
    required this.tokenType,
  });

  factory ChatBackendAuthModel.fromJson(Map<String, dynamic> json) {
    return ChatBackendAuthModel(
      token: json['token']?.toString() ?? '',
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
    );
  }

  /// Authorization header value for chat requests (e.g. "Bearer eyJ...")
  String get authorizationHeader => '$tokenType $token';

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'tokenType': tokenType,
    };
  }
}
