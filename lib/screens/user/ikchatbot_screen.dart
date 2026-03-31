import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../extensions/extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_images.dart';
import '../../utils/app_constants.dart';
import '../../utils/dynamic_theme.dart';
import '../../utils/period_date_validation.dart';
import '../../model/user/chat_message_response_model.dart';
import '../../model/user/cycle_info_model.dart';
import '../../service/phone_verification_service.dart';

class IkChatbotScreen extends StatefulWidget {
  static String tag = '/IkChatbotScreen';

  const IkChatbotScreen({super.key});

  @override
  State<IkChatbotScreen> createState() => _IkChatbotScreenState();
}

class _IkChatbotScreenState extends State<IkChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  static const String _chatMessagesKeyPrefix = 'CHAT_MESSAGES_HISTORY';
  static const String _registrationPeriodRequiredKey = 'registration_period_required';
  static const String _refreshCycleRequiredKey = 'refresh_cycle_required';
  bool _requiresRegistrationPeriodDate = false;

  /// Storage key scoped to the logged-in user's phone number to avoid conflicts between users.
  String _getChatHistoryKey() {
    String? phone = userStore.user?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      phone = getStringAsync(KEY_PHONE_NUMBER);
    }
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return _chatMessagesKeyPrefix;
    }
    return '${_chatMessagesKeyPrefix}_$digitsOnly';
  }

  @override
  void initState() {
    super.initState();
    logScreenView("IK Chatbot screen");
    // Load saved messages from storage first
    _loadChatHistory().then((_) async {
      await _checkRegistrationPeriodDateRequirement();
      // Fetch initial welcome message from API only if no messages exist
      if (_messages.isEmpty && !_requiresRegistrationPeriodDate) {
        _fetchInitialWelcomeMessage();
      }
    });
  }

  Future<void> _checkRegistrationPeriodDateRequirement() async {
    // Use the same mechanism as home_screen:
    // 1) userStore.cycleInfo
    // 2) fallback to KEY_CYCLE_INFO global shared pref
    CycleInfoModel? cycleInfo = userStore.cycleInfo;
    if (cycleInfo == null) {
      try {
        Map<String, dynamic> cycleInfoJson = getJSONAsync(KEY_CYCLE_INFO);
        if (cycleInfoJson.isNotEmpty) {
          cycleInfo = CycleInfoModel.fromJson(cycleInfoJson);
          userStore.setCycleInfo(cycleInfo, isInitialization: true);
        }
      } catch (_) {}
    }

    final String rawDateRegle = cycleInfo?.dateRegle?.trim() ?? '';
    final String normalizedDateRegle = rawDateRegle.toUpperCase();
    final bool isBlockedPlaceholderDate = rawDateRegle == '2025-01-01';
    final bool isBlockedPlaceholderCode = normalizedDateRegle == 'S1';
    final bool hasSubmittedDate = rawDateRegle.isNotEmpty &&
        !isBlockedPlaceholderDate &&
        !isBlockedPlaceholderCode;

    if (!mounted) return;

    if (!hasSubmittedDate) {
      setState(() {
        _requiresRegistrationPeriodDate = true;
        final alreadyExists = _messages.any(
          (m) => !m.isUser && m.responseKey == _registrationPeriodRequiredKey,
        );
        if (!alreadyExists) {
          _messages.insert(
            0,
            ChatMessage(
              text:
                  'Welcome to the cycleM assistant. You must submit your last period date to use the chat features.',
              isUser: false,
              timestamp: DateTime.now(),
              smartReplies: const ['Submit your date'],
              responseKey: _registrationPeriodRequiredKey,
              requiresDateInput: false,
            ),
          );
        }
      });
      _saveChatHistory();
    } else {
      setState(() {
        _requiresRegistrationPeriodDate = false;
      });
    }
  }

  Future<void> _fetchInitialWelcomeMessage() async {
    // Get phone number from userStore
    String phoneNumber = userStore.user?.phoneNumber ?? getStringAsync(KEY_PHONE_NUMBER);
    if (phoneNumber.isEmpty) {
      // Fallback: show default welcome message with Yes/No smart replies
      setState(() {
        _messages.add(ChatMessage(
          text: language.defaultWelcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
          smartReplies: ['Oui', 'Non'], // Always show Yes/No smart replies
        ));
      });
      return;
    }

    try {
      // Ensure chat backend token exists
      await _ensureChatBackendToken();
      
      // Call sendChatMessageApi with "welcome" key
      final response = await sendChatMessageApi(
        userId: phoneNumber,
        lang: 'fr',
        phone: phoneNumber,
        currentKey: 'welcome',
        flowId: '',
        input: '',
      );
      
      if (!mounted) return;

      // Extract text and choices from response
      String welcomeMessage = response.text;
      
      print('📨 API Welcome Message: $welcomeMessage');
      
      if (welcomeMessage.isEmpty) {
        welcomeMessage = language.defaultWelcomeMessage;
      }
      
      // Extract smart replies from choices (take first 2 choice labels)
      final choiceLabels = response.choices.take(2).map((c) => c.label).toList();
      List<String> smartReplies = choiceLabels.isNotEmpty ? choiceLabels : ['Oui', 'Non'];
      
      print('🔘 Smart Replies from API: $smartReplies');
      
      // Check if date input is required
      final bool requiresDateInput = response.key == 'cycle_eligible' && response.type == 'INPUT';
      
      setState(() {
        _messages.add(ChatMessage(
          text: welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
          smartReplies: smartReplies.isNotEmpty ? smartReplies : ['Oui', 'Non'],
          choices: response.choices.isEmpty ? null : response.choices,
          responseKey: response.key,
          requiresDateInput: requiresDateInput,
        ));
      });
      
      print('✅ Welcome message added to list. Total messages: ${_messages.length}');
      // Save messages to storage after adding
      _saveChatHistory();
    } catch (e, stackTrace) {
      print('❌ Error fetching initial welcome message: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      
      // Fallback to default message on error with Yes/No smart replies
      setState(() {
        _messages.add(ChatMessage(
          text: language.defaultWelcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
          smartReplies: ['Oui', 'Non'], // Always show Yes/No smart replies
        ));
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_requiresRegistrationPeriodDate) {
      toast(
          'Please submit your last period date first to use the chat features.');
      return;
    }

    if (_messageController.text.trim().isEmpty) return;

    String userInput = _messageController.text.trim();
    
    // Check if the typed text matches any smart reply from the last bot message
    ChatMessage? lastBotMessage = _findLastBotMessage();
    if (lastBotMessage != null) {
      // Check if it matches a choice-based smart reply
      if (lastBotMessage.choices != null && lastBotMessage.choices!.isNotEmpty) {
        ChatChoice? matchedChoice = _findMatchingChoice(userInput, lastBotMessage.choices!);
        if (matchedChoice != null) {
          // Use the matched choice
          _messageController.clear();
          _sendChoiceReply(matchedChoice, lastBotMessage);
          return;
        }
      }
      
      // Check if it matches a legacy smart reply
      if (lastBotMessage.smartReplies != null && lastBotMessage.smartReplies!.isNotEmpty) {
        String? matchedReply = _findMatchingSmartReply(userInput, lastBotMessage.smartReplies!);
        if (matchedReply != null) {
          // Handle it the same way as clicking the smart reply button
          setState(() {
            _messages.insert(0, ChatMessage(
              text: matchedReply,
              isUser: true,
              timestamp: DateTime.now(),
            ));
          });
          _messageController.clear();
          _saveChatHistory();
          
          // Handle the reply based on its value
          String replyLower = matchedReply.toLowerCase().trim();
          if (replyLower == 'oui' || replyLower == 'yes') {
            _fetchCycleStartResponse();
          } else if (replyLower == 'non' || replyLower == 'no') {
            setState(() {
              _messages.insert(0, ChatMessage(
                text: language.chatbotClosingMessage,
                isUser: false,
                timestamp: DateTime.now(),
                smartReplies: null,
              ));
            });
            _saveChatHistory();
          } else {
            _fetchBotResponse(matchedReply);
          }
          return;
        }
      }
    }

    // No match found, send as regular message
    setState(() {
      _messages.insert(0, ChatMessage(
        text: userInput,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _messageController.clear();

    // Save messages after adding user message
    _saveChatHistory();

    // Call chatbot API
    _fetchBotResponse(userInput);
  }

  /// Find the last bot message (most recent message that is not from user)
  ChatMessage? _findLastBotMessage() {
    for (var message in _messages) {
      if (!message.isUser) {
        return message;
      }
    }
    return null;
  }

  /// Check if user input matches any smart reply (case-insensitive)
  /// Returns the matched smart reply text if found, null otherwise
  String? _findMatchingSmartReply(String userInput, List<String> smartReplies) {
    if (userInput.isEmpty) return null;
    
    String normalizedInput = userInput.toLowerCase().trim();
    
    // Check for exact matches first
    for (String smartReply in smartReplies) {
      String normalizedReply = smartReply.toLowerCase().trim();
      if (normalizedInput == normalizedReply) {
        return smartReply; // Return original case from smart reply
      }
    }
    
    // Check for common variations
    if (_isYesVariation(normalizedInput)) {
      for (String smartReply in smartReplies) {
        String normalizedReply = smartReply.toLowerCase().trim();
        if (normalizedReply == 'yes' || normalizedReply == 'oui') {
          return smartReply;
        }
      }
    }
    
    if (_isNoVariation(normalizedInput)) {
      for (String smartReply in smartReplies) {
        String normalizedReply = smartReply.toLowerCase().trim();
        if (normalizedReply == 'no' || normalizedReply == 'non') {
          return smartReply;
        }
      }
    }
    
    return null;
  }

  /// Check if user input matches any choice label (case-insensitive)
  /// Also checks if input is a number corresponding to a choice index (1-based)
  /// Returns the matched choice if found, null otherwise
  ChatChoice? _findMatchingChoice(String userInput, List<ChatChoice> choices) {
    if (userInput.isEmpty || choices.isEmpty) return null;
    
    String normalizedInput = userInput.toLowerCase().trim();
    
    // Check if input is a number (for numbered list selection)
    // Try to parse as integer (1-based indexing for user convenience)
    try {
      int? choiceNumber = int.tryParse(normalizedInput);
      if (choiceNumber != null && choiceNumber >= 1 && choiceNumber <= choices.length) {
        // User typed a number corresponding to a choice (1-based)
        // Return the choice at index (choiceNumber - 1)
        return choices[choiceNumber - 1];
      }
    } catch (e) {
      // Not a valid number, continue with other checks
    }
    
    // Check for exact label matches
    for (ChatChoice choice in choices) {
      String normalizedLabel = choice.label.toLowerCase().trim();
      if (normalizedInput == normalizedLabel) {
        return choice;
      }
    }
    
    // Check if label starts with a number (e.g., "1. Option", "2. Choice")
    // Extract number from label and compare
    for (ChatChoice choice in choices) {
      String normalizedLabel = choice.label.toLowerCase().trim();
      // Check if label starts with a number pattern like "1.", "1)", "1-", etc.
      RegExp numberPattern = RegExp(r'^(\d+)[\.\)\-\s]+');
      Match? labelMatch = numberPattern.firstMatch(normalizedLabel);
      if (labelMatch != null) {
        String labelNumber = labelMatch.group(1) ?? '';
        if (normalizedInput == labelNumber) {
          return choice;
        }
      }
    }
    
    // Check for common variations
    if (_isYesVariation(normalizedInput)) {
      for (ChatChoice choice in choices) {
        String normalizedLabel = choice.label.toLowerCase().trim();
        if (normalizedLabel == 'yes' || normalizedLabel == 'oui') {
          return choice;
        }
      }
    }
    
    if (_isNoVariation(normalizedInput)) {
      for (ChatChoice choice in choices) {
        String normalizedLabel = choice.label.toLowerCase().trim();
        if (normalizedLabel == 'no' || normalizedLabel == 'non') {
          return choice;
        }
      }
    }
    
    return null;
  }

  /// Check if input is a variation of "yes"
  bool _isYesVariation(String input) {
    List<String> yesVariations = ['yes', 'oui', 'y', 'yeah', 'yep', 'sure', 'ok', 'okay', 'd\'accord', 'daccord', 'd\'acc', 'dacc'];
    return yesVariations.contains(input);
  }

  /// Check if input is a variation of "no"
  bool _isNoVariation(String input) {
    List<String> noVariations = ['no', 'non', 'n', 'nope', 'nah', 'not', 'pas', 'ne pas'];
    return noVariations.contains(input);
  }

  /// Ensure chat backend token exists; call chatBackendApi if missing.
  /// Token will be automatically refreshed if API returns 401/403.
  Future<void> _ensureChatBackendToken() async {
    if (getStringAsync(KEY_CHAT_BACKEND_TOKEN).isEmpty) {
      await chatBackendApi();
    }
  }

  /// Call sendChatMessageApi with key "cycle_start" after user selected "Yes". On 200, show response text and two smart replies from choices (label).
  Future<void> _fetchCycleStartResponse() async {
    String phoneNumber = userStore.user?.phoneNumber ?? getStringAsync(KEY_PHONE_NUMBER);
    if (phoneNumber.isEmpty) {
      if (!mounted) return;
      setState(() {
        _messages.insert(0, ChatMessage(
          text: language.phoneNotFoundReconnect,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
      return;
    }

    if (!mounted) return;
    setState(() {
      _messages.insert(0, ChatMessage(
        text: '', // Empty text, only show loading animation
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
    });
    _saveChatHistory();

    try {
      await _ensureChatBackendToken();
      final response = await sendChatMessageApi(
        userId: phoneNumber,
        lang: 'fr',
        phone: phoneNumber,
        currentKey: 'cycle_start',
        flowId: '',
        input: '',
      );

      if (!mounted) return;
      setState(() {
        _messages.removeAt(0);
        final choiceLabels = response.choices.take(2).map((c) => c.label).toList();
        final bool requiresDateInput = response.key == 'cycle_eligible' && response.type == 'INPUT';
        _messages.insert(0, ChatMessage(
          text: response.text,
          isUser: false,
          timestamp: DateTime.now(),
          smartReplies: choiceLabels.isEmpty ? null : choiceLabels,
          choices: response.choices.isEmpty ? null : response.choices,
          responseKey: response.key,
          requiresDateInput: requiresDateInput,
        ));
      });
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _saveChatHistory();
    } catch (e) {
      print('Error fetch cycle_start: $e');
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
        _messages.insert(0, ChatMessage(
          text: language.serverErrorTryAgain,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
    }
  }

  /// Debug: print to console when user taps a choice smart reply (body params + response). Only in debug mode.
  void _debugChoiceTap({required ChatChoice choice, required Map<String, dynamic> bodyParams}) {
    if (!kDebugMode) return;
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔘 [Chat] User tapped choice smart reply');
    debugPrint('   choice: value="${choice.value}" label="${choice.label}" nextKey="${choice.nextKey}"');
    debugPrint('   Body parameters sent:');
    for (final e in bodyParams.entries) {
      debugPrint('     ${e.key}: ${e.value}');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  void _debugChoiceResponse(ChatMessageResponseModel response) {
    if (!kDebugMode) return;
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📥 [Chat] API response object:');
    debugPrint('   sessionId: ${response.sessionId}');
    debugPrint('   userId: ${response.userId}');
    debugPrint('   lang: ${response.lang}');
    debugPrint('   key: ${response.key}');
    debugPrint('   state: ${response.state}');
    debugPrint('   type: ${response.type}');
    debugPrint('   text: ${response.text}');
    debugPrint('   nextExpectedInput: ${response.nextExpectedInput}');
    debugPrint('   timestamp: ${response.timestamp}');
    debugPrint('   choices: [${response.choices.length}]');
    for (int i = 0; i < response.choices.length; i++) {
      final c = response.choices[i];
      debugPrint('     [$i] value="${c.value}" label="${c.label}" nextKey="${c.nextKey}"');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Send a choice (from API choices) and show next bot response.
  /// Uses the responseKey from the previous bot message instead of choice.nextKey.
  Future<void> _sendChoiceReply(ChatChoice choice, ChatMessage? previousBotMessage) async {
    if (_requiresRegistrationPeriodDate) {
      toast(
          'Please submit your last period date first to use the chat features.');
      return;
    }

    String phoneNumber = userStore.user?.phoneNumber ?? getStringAsync(KEY_PHONE_NUMBER);
    if (phoneNumber.isEmpty) {
      if (!mounted) return;
      setState(() {
        _messages.insert(0, ChatMessage(
          text: language.phoneNotFoundReconnect,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
      return;
    }

    setState(() {
      _messages.insert(0, ChatMessage(
        text: choice.label,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    setState(() {
      _messages.insert(0, ChatMessage(
        text: '', // Empty text, only show loading animation
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
    });
    _saveChatHistory();

    try {
      await _ensureChatBackendToken();

      // Always use choice.nextKey as the key value for the next request
      String keyToUse = choice.nextKey;
      
      final bodyParams = {
        'userId': phoneNumber,
        'lang': 'fr',
        'msisdn': phoneNumber,
        'key': keyToUse,
        'flowId': '',
        'input': '', // Always send empty string, never use choice.value
      };
      _debugChoiceTap(choice: choice, bodyParams: bodyParams);

      final response = await sendChatMessageApi(
        userId: phoneNumber,
        lang: 'fr',
        phone: phoneNumber,
        currentKey: keyToUse,
        flowId: '',
        input: '', // Always send empty string, never use choice.value
      );

      _debugChoiceResponse(response);

      if (!mounted) return;
      setState(() {
        _messages.removeAt(0);
        final choiceLabels = response.choices.take(2).map((c) => c.label).toList();
        // Check if this is a date input request (cycle_eligible with type INPUT)
        final bool requiresDateInput = response.key == 'cycle_eligible' && response.type == 'INPUT';
        _messages.insert(0, ChatMessage(
          text: response.text,
          isUser: false,
          timestamp: DateTime.now(),
          smartReplies: choiceLabels.isEmpty ? null : choiceLabels,
          choices: response.choices.isEmpty ? null : response.choices,
          responseKey: response.key, // Store the response key
          requiresDateInput: requiresDateInput, // Mark if date input is required
        ));
      });
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _saveChatHistory();
    } catch (e) {
      print('Error send choice: $e');
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
        _messages.insert(0, ChatMessage(
          text: language.serverErrorTryAgain,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
    }
  }

  Future<void> _fetchBotResponse(String userMessage) async {
    // Get phone number from userStore
    String? phoneNumber = userStore.user?.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      // Fallback: show error message
      setState(() {
        _messages.insert(0, ChatMessage(
          text: language.phoneNotFoundReconnect,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      return;
    }

    // Get language code (default to 'fr' if not available)
    // Try to get from shared preferences, default to 'fr'
    String languageCode = 'fr'; // Default to French
    try {
      // Check if language is stored in a different key
      // For now, defaulting to 'fr' as shown in the API example
    } catch (e) {
      // Use default
    }

    try {
      // Call the chat API
      final response = await getChatMessageApi(phoneNumber, languageCode);
      
      if (!mounted) return;

      String botMessage = response['message'] ?? '';
      
      if (botMessage.isEmpty) {
        botMessage = language.noServerResponse;
      }
      
      setState(() {
        _messages.insert(0, ChatMessage(
          text: botMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });

      // Auto-scroll to top
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      
      // Save messages after bot response
      _saveChatHistory();
    } catch (e) {
      print('Error fetching chat message: $e');
      if (!mounted) return;
      
      setState(() {
        _messages.insert(0, ChatMessage(
          text: language.serverErrorTryAgain,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: appBarWidget(
        language.ikChatbotTitle,
        context1: context,
        elevation: 1,
        titleTextStyle: boldTextStyle(
          size: textFontSize_18,
          isHeader: true,
          color: Colors.white,
        ),
        textColor: Colors.white,
        color: Color.fromRGBO(166, 8, 8, 1.0), // Primary color RGB(166, 8, 8)
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(chat_bot_background_image),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            language.startConversation,
                            style: secondaryTextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Only show message bubble if not loading or has text
            if (!message.isLoading || message.text.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Colors.orange
                      : Color.fromRGBO(166, 8, 8, 1.0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    if (message.text.isNotEmpty) SizedBox(height: 4),
                    if (message.text.isNotEmpty)
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            // Display loading animation for loading messages (3 dots)
            if (!message.isUser && message.isLoading)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(166, 8, 8, 1.0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            // Display date picker button if date input is required
            if (!message.isUser && message.requiresDateInput == true)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _showDatePicker(message),
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    'Sélectionner une date',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color.fromRGBO(166, 8, 8, 1.0),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Color.fromRGBO(166, 8, 8, 1.0), width: 1.5),
                    ),
                    elevation: 0,
                  ),
                ),
              )
            // Display choice-based smart replies (from sendChatMessageApi response)
            else if (!message.isUser && message.choices != null && message.choices!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.choices!.take(2).map((choice) {
                    return ElevatedButton(
                      onPressed: () => _sendChoiceReply(choice, message),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color.fromRGBO(166, 8, 8, 1.0),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Color.fromRGBO(166, 8, 8, 1.0), width: 1.5),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        choice.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              )
            // Display legacy smart reply buttons (Oui/Non etc.)
            else if (!message.isUser && message.smartReplies != null && message.smartReplies!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.smartReplies!.map((reply) {
                    return ElevatedButton(
                      onPressed: () {
                        if (reply.toLowerCase().trim() == 'submit your date') {
                          _showDatePicker(message);
                          return;
                        }
                        setState(() {
                          _messages.insert(0, ChatMessage(
                            text: reply,
                            isUser: true,
                            timestamp: DateTime.now(),
                          ));
                        });
                        String replyLower = reply.toLowerCase().trim();
                        if (replyLower == 'oui' || replyLower == 'yes') {
                          _fetchCycleStartResponse();
                        } else if (replyLower == 'non' || replyLower == 'no') {
                          setState(() {
                            _messages.insert(0, ChatMessage(
                              text: language.chatbotClosingMessage,
                              isUser: false,
                              timestamp: DateTime.now(),
                              smartReplies: null,
                            ));
                          });
                          _saveChatHistory();
                        } else {
                          _fetchBotResponse(reply);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color.fromRGBO(166, 8, 8, 1.0),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Color.fromRGBO(166, 8, 8, 1.0), width: 1.5),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        reply,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_requiresRegistrationPeriodDate,
                decoration: InputDecoration(
                  hintText: _requiresRegistrationPeriodDate
                      ? 'Submit your last period date to continue'
                      : language.typeYourMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: ColorUtils.colorPrimary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.white),
                onPressed: _requiresRegistrationPeriodDate ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Load chat history from SharedPreferences (scoped to current user's phone number).
  Future<void> _loadChatHistory() async {
    try {
      final key = _getChatHistoryKey();
      String messagesJson = getStringAsync(key);
      if (messagesJson.isNotEmpty) {
        List<dynamic> messagesList = jsonDecode(messagesJson);
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(
              messagesList.map((json) => ChatMessage.fromJson(json as Map<String, dynamic>)).toList(),
            );
          });
        }
        print('✅ Loaded ${_messages.length} messages from storage (key: $key)');
      } else {
        print('No saved chat history found for current user');
      }
    } catch (e) {
      print('❌ Error loading chat history: $e');
      if (mounted) {
        setState(() {
          _messages.clear();
        });
      }
    }
  }

  /// Save chat history to SharedPreferences (scoped to current user's phone number).
  Future<void> _saveChatHistory() async {
    try {
      final key = _getChatHistoryKey();
      List<Map<String, dynamic>> messagesJson = _messages.map((msg) => msg.toJson()).toList();
      String jsonString = jsonEncode(messagesJson);
      await setValue(key, jsonString);
      print('✅ Saved ${_messages.length} messages to storage (key: $key)');
    } catch (e) {
      print('❌ Error saving chat history: $e');
    }
  }

  /// Show date picker for period date selection when cycle_eligible response is received
  Future<void> _showDatePicker(ChatMessage message) async {
    if (message.responseKey != 'cycle_eligible' &&
        message.responseKey != _registrationPeriodRequiredKey) {
      return;
    }

    // Calculate date range: from 33 days ago to today
    final DateTime today = DateTime.now();
    final DateTime firstDate = today.subtract(Duration(days: 33));
    final DateTime lastDate = today;

    // Show date picker
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Sélectionner la date',
      cancelText: language.cancel,
      confirmText: language.next,
      locale: Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color.fromRGBO(166, 8, 8, 1.0),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return; // User cancelled

    // Validate the selected date
    final validationResult = validateLastPeriodDate(picked);
    if (!validationResult.isValid) {
      toast(validationResult.errorMessage ?? 'Date invalide');
      return;
    }

    // Format date as YYYY-MM-DD
    final String formattedDate = DateFormat('yyyy-MM-dd').format(picked);

    // Add user message showing selected date
    setState(() {
      _messages.insert(0, ChatMessage(
        text: formattedDate,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    // Show loading animation
    setState(() {
      _messages.insert(0, ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
    });
    _saveChatHistory();

    if (message.responseKey == _registrationPeriodRequiredKey) {
      await _submitRegistrationPeriodDate(formattedDate);
    } else {
      // Send API request with selected date
      await _sendDateInput(formattedDate, message.responseKey!);
    }
  }

  Future<void> _submitRegistrationPeriodDate(String formattedDate) async {
    final String fullPhoneNumber =
        userStore.user?.phoneNumber ?? getStringAsync(KEY_PHONE_NUMBER);
    final String phoneForApi = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (phoneForApi.isEmpty) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
        _messages.insert(0, ChatMessage(
          text: language.phoneNotFoundReconnect,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
      return;
    }

    try {
      const bool q1 = true;
      const bool q2 = true;
      const bool q3 = false;

      final success = await PhoneVerificationService.createSubscriptionWithPeriodDate(
        phoneNumber: fullPhoneNumber,
        periodDate: formattedDate,
        question1Answer: q1,
        question2Answer: q2,
        question3Answer: q3,
      );

      if (!mounted) return;
      if (!success) {
        setState(() {
          if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
          _messages.insert(0, ChatMessage(
            text: language.serverErrorTryAgain,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _saveChatHistory();
        return;
      }

      await userStore.setPeriodDate(formattedDate);
      final existingCycleInfo = loadCycleInfoForPhone(phoneForApi);
      final updatedCycleInfo = CycleInfoModel(
        dateCreation: existingCycleInfo?.dateCreation,
        dateFertiStart: existingCycleInfo?.dateFertiStart,
        dateFertireqEnd: existingCycleInfo?.dateFertireqEnd,
        dateRegle: formattedDate,
        dateProchaineReglesStart: existingCycleInfo?.dateProchaineReglesStart,
        dateProchaineReglesEnd: existingCycleInfo?.dateProchaineReglesEnd,
      );
      await userStore.setCycleInfo(updatedCycleInfo);
      await saveCycleInfoForPhone(phoneForApi, updatedCycleInfo);

      setState(() {
        _requiresRegistrationPeriodDate = false;
        if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
      });

      _messages.clear();
      await _saveChatHistory();
      await _fetchInitialWelcomeMessage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
        _messages.insert(0, ChatMessage(
          text: '${language.errorLabel}: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
    }
  }

  /// Send API request with selected date as input
  Future<void> _sendDateInput(String date, String key) async {
    String phoneNumber = userStore.user?.phoneNumber ?? getStringAsync(KEY_PHONE_NUMBER);
    if (phoneNumber.isEmpty) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
        _messages.insert(0, ChatMessage(
          text: language.phoneNotFoundReconnect,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
      return;
    }

    try {
      await _ensureChatBackendToken();

      final response = await sendChatMessageApi(
        userId: phoneNumber,
        lang: 'fr',
        phone: phoneNumber,
        currentKey: key, // cycle_eligible
        flowId: '',
        input: date, // Selected date in YYYY-MM-DD format
      );

      if (!mounted) return;
      setState(() {
        _messages.removeAt(0); // Remove loading animation
        final choiceLabels = response.choices.take(2).map((c) => c.label).toList();
        final bool requiresDateInput = response.key == 'cycle_eligible' && response.type == 'INPUT';
        _messages.insert(0, ChatMessage(
          text: response.text,
          isUser: false,
          timestamp: DateTime.now(),
          smartReplies: choiceLabels.isEmpty ? null : choiceLabels,
          choices: response.choices.isEmpty ? null : response.choices,
          responseKey: response.key,
          requiresDateInput: requiresDateInput,
        ));
      });
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _saveChatHistory();
    } catch (e) {
      print('Error sending date input: $e');
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.first.isLoading) _messages.removeAt(0);
        _messages.insert(0, ChatMessage(
          text: language.serverErrorTryAgain,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _saveChatHistory();
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? smartReplies;
  /// When set, smart reply buttons use choice.label; tap sends choice.nextKey/value.
  final List<ChatChoice>? choices;
  final bool isLoading;
  /// The response key from the API response (used when sending choice replies)
  final String? responseKey;
  /// True if this message requires date input (cycle_eligible with type INPUT)
  final bool? requiresDateInput;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.smartReplies,
    this.choices,
    this.isLoading = false,
    this.responseKey,
    this.requiresDateInput = false,
  });

  /// Convert ChatMessage to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'smartReplies': smartReplies,
      'choices': choices?.map((c) => c.toJson()).toList(),
      'isLoading': isLoading,
      'responseKey': responseKey,
      'requiresDateInput': requiresDateInput,
    };
  }

  /// Create ChatMessage from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<ChatChoice>? choicesList;
    if (json['choices'] != null && json['choices'] is List) {
      choicesList = (json['choices'] as List)
          .map((e) => ChatChoice.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return ChatMessage(
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      smartReplies: json['smartReplies'] != null
          ? List<String>.from(json['smartReplies'] as List)
          : null,
      choices: choicesList,
      isLoading: json['isLoading'] as bool? ?? false,
      responseKey: json['responseKey'] as String?,
      requiresDateInput: json['requiresDateInput'] as bool? ?? false,
    );
  }
}

