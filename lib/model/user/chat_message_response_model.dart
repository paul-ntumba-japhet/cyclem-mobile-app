/// Single choice item in chat message response.
/// Used for next chat steps (value, label, nextKey).
class ChatChoice {
  final String value;
  final String label;
  final String nextKey;

  ChatChoice({
    required this.value,
    required this.label,
    required this.nextKey,
  });

  factory ChatChoice.fromJson(Map<String, dynamic> json) {
    return ChatChoice(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      nextKey: json['nextKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
      'nextKey': nextKey,
    };
  }
}

/// Chat message response from POST /chat-backend/api/chat/message.
/// Use [text] and [choices] for next chat steps; [choices] can be an empty list.
class ChatMessageResponseModel {
  final String sessionId;
  final String userId;
  final String lang;
  final String key;
  final String state;
  final String type;
  final String text;
  final List<ChatChoice> choices;
  final bool nextExpectedInput;
  final String timestamp;

  ChatMessageResponseModel({
    required this.sessionId,
    required this.userId,
    required this.lang,
    required this.key,
    required this.state,
    required this.type,
    required this.text,
    required this.choices,
    required this.nextExpectedInput,
    required this.timestamp,
  });

  factory ChatMessageResponseModel.fromJson(Map<String, dynamic> json) {
    final choicesRaw = json['choices'];
    final List<ChatChoice> choicesList = [];
    if (choicesRaw is List) {
      for (final item in choicesRaw) {
        if (item is Map<String, dynamic>) {
          choicesList.add(ChatChoice.fromJson(item));
        } else if (item is Map) {
          choicesList.add(ChatChoice.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ChatMessageResponseModel(
      sessionId: json['sessionId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      lang: json['lang']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      choices: choicesList,
      nextExpectedInput: json['nextExpectedInput'] == true,
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'lang': lang,
      'key': key,
      'state': state,
      'type': type,
      'text': text,
      'choices': choices.map((c) => c.toJson()).toList(),
      'nextExpectedInput': nextExpectedInput,
      'timestamp': timestamp,
    };
  }
}
