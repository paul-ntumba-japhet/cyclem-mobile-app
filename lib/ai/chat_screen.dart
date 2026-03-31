import 'package:chat_gpt_sdk/chat_gpt_sdk.dart'
    show ChatCompleteText, Gpt4ChatModel, HttpSetup, OpenAI;
import 'package:era_flutter/ai/questionModel.dart';
import 'package:era_flutter/extensions/colors.dart';
import 'package:era_flutter/extensions/common.dart';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/int_extensions.dart';
import 'package:era_flutter/extensions/system_utils.dart';
import 'package:era_flutter/extensions/text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'dart:convert';

import '../extensions/new_colors.dart';
import '../extensions/shared_pref.dart';
import '../main.dart';
import 'chat_message_Image_widget.dart';

bool? isLoading = false;

class AiChatScreen extends StatefulWidget {
  static String tag = '/chatgpt';

  final bool isDirect;
 final String? questionAsk;
  final String? question;

  AiChatScreen({this.isDirect = false, this.questionAsk, this.question});

  @override
  _AiChatScreenState createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  ScrollController scrollController = ScrollController();

  TextEditingController msgController = TextEditingController();

  int adCount = 0;
  String selectedText = '';

  String lastError = "";
  String lastStatus = "";
  String question = '';
  bool isShowOption = false;
  bool showResponse = false;
  List<QuestionAnswerModel> questionAnswers = [];

  late OpenAI openAI;
  
  static const String _chatHistoryKey = 'AI_CHAT_HISTORY';
  static const String _lastChatActivityKey = 'AI_CHAT_LAST_ACTIVITY';
  static const Duration _inactivityThreshold = Duration(hours: 1);

  @override
  void initState() {
    super.initState();

    Future.value().then((_) async {
      openAI = OpenAI.instance.build(
          token: chatgptKey!,
          baseOption: HttpSetup(
              receiveTimeout: const Duration(seconds: 20),
              connectTimeout: const Duration(seconds: 20)),
          enableLog: true);

      // Load chat history
      await _loadChatHistory();
      
      // Check if we should show welcome message (after 1 hour of inactivity)
      bool shouldShowWelcome = await _shouldShowWelcomeMessage();
      
      if (shouldShowWelcome) {
        // Add welcome message at the beginning of the list (most recent)
        _addWelcomeMessage();
        await _saveChatHistory();
      }
      
      // Send auto message if provided (only if no welcome was just shown)
      if (widget.questionAsk != null && widget.questionAsk!.isNotEmpty && !shouldShowWelcome) {
        sendAutoFirstMsg(widget.questionAsk);
      }
      
      // Update last activity timestamp
      await _updateLastActivity();
    });
  }
  
  Future<void> _loadChatHistory() async {
    try {
      String? historyJson = getStringAsync(_chatHistoryKey, defaultValue: '');
      if (historyJson.isNotEmpty) {
        List<dynamic> historyList = jsonDecode(historyJson);
        questionAnswers = historyList.map((item) {
          return QuestionAnswerModel(
            question: item['question'],
            answer: StringBuffer(item['answer'] ?? ''),
            isLoading: false,
            smartCompose: item['smartCompose'] ?? '',
            smartReplies: item['smartReplies'] != null 
                ? List<String>.from(item['smartReplies']) 
                : null,
          );
        }).toList();
        setState(() {});
      }
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }
  
  Future<void> _saveChatHistory() async {
    try {
      List<Map<String, dynamic>> historyList = questionAnswers.map((qa) {
        return {
          'question': qa.question ?? '',
          'answer': qa.answer?.toString() ?? '',
          'smartCompose': qa.smartCompose ?? '',
          'smartReplies': qa.smartReplies,
        };
      }).toList();
      String historyJson = jsonEncode(historyList);
      await setValue(_chatHistoryKey, historyJson);
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }
  
  Future<bool> _shouldShowWelcomeMessage() async {
    try {
      String? lastActivityStr = getStringAsync(_lastChatActivityKey, defaultValue: '');
      if (lastActivityStr.isEmpty) {
        // No previous activity, show welcome
        return true;
      }
      
      DateTime lastActivity = DateTime.parse(lastActivityStr);
      DateTime now = DateTime.now();
      Duration timeSinceLastActivity = now.difference(lastActivity);
      
      // Show welcome if more than 1 hour has passed
      return timeSinceLastActivity >= _inactivityThreshold;
    } catch (e) {
      print('Error checking last activity: $e');
      return false;
    }
  }
  
  void _addWelcomeMessage() {
    String greeting = _getGreetingMessage();
    String welcomeText = '$greeting! 👋\n\nI\'m here to help you with questions about your menstrual cycle, fertility, health, and more. Feel free to ask me anything!';
    
    questionAnswers.insert(
      0,
      QuestionAnswerModel(
        question: '',
        answer: StringBuffer(welcomeText),
        isLoading: false,
        smartCompose: '',
        smartReplies: ['Yes', 'No'], // Always show Yes/No smart replies under welcome message
      ),
    );
    setState(() {});
  }
  
  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }
  
  Future<void> _updateLastActivity() async {
    await setValue(_lastChatActivityKey, DateTime.now().toIso8601String());
  }

  void sendMessage() async {
    showResponse = true;
    isLoading = true;
    hideKeyboard(context);
    if (selectedText.isNotEmpty) {
      question = selectedText + msgController.text;
      setState(() {});
    } else {
      question = msgController.text;
      setState(() {});
    }
    msgController.clear();
    /* for (var word in foundString) {
      if (question.contains(word)) {
        foundWords.add(word);
      }
    }*/
    questionAnswers.insert(
        0,
        QuestionAnswerModel(
            question: question,
            answer: StringBuffer(),
            isLoading: true,
            smartCompose: selectedText));

    setState(() {});

    final request = ChatCompleteText(
      messages: [
        {"role": "user", "content": "${question}"}
      ],
      maxToken: 300,
      model: Gpt4ChatModel(),
    );

    await _streamResponse(request);

    isLoading = false;

    questionAnswers[0].isLoading = false;
    showResponse = false;

    // Save chat history after message is sent
    await _saveChatHistory();
    await _updateLastActivity();

    setState(() {});
  }

  void statusListener(String status) {
    setState(() {
      lastStatus = "$status";
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void sendAutoFirstMsg(String? questions) async {
    isLoading = true;
    showResponse = true;
    questionAnswers.insert(
        0,
        QuestionAnswerModel(
            question: widget.question,
            answer: StringBuffer(),
            isLoading: true,
            smartCompose: ''));
    setState(() {});

    final request = await ChatCompleteText(
      messages: [
        {"role": "user", "content": questions}
      ],
      maxToken: 370,
      model: Gpt4ChatModel(),
    );

    await _streamResponse(request);
    isLoading = false;
    questionAnswers[0].isLoading = false;
    showResponse = false;
    
    // Save chat history after auto message is sent
    await _saveChatHistory();
    await _updateLastActivity();
    
    setState(() {});
  }

  Future<dynamic> _streamResponse(ChatCompleteText request) async {
    try {
      final stream = await openAI.onChatCompletion(request: request);
      stream?.choices.forEach((data) {
        questionAnswers.first.answer!.write(data.message?.content);
      });
    } catch (error) {
      isLoading = false;
      questionAnswers.first.answer!.write("Too many requests please try again");
      log("Error occurred: $error");
      setState(() {});
    }
  }

  @override
  void dispose() {
    msgController.dispose();
    // Save chat history before disposing
    _saveChatHistory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: mainColorLight,
            pinned: true,
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: mainColorText),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'CycleM Ai',
              style: boldTextStyle(
                color: mainColorText,
                size: 18,
                weight: FontWeight.w500,
              ),
            ),
            titleSpacing: 0,
            expandedHeight: 0,
            elevation: 0,
            surfaceTintColor: mainColorLight,
            forceElevated: true,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Stack(
                children: [
                  Container(
                    height: 40,
                    color: mainColorLight,
                  ),
                ],
              ),
              Transform.translate(
                offset: Offset(0, -30),
                child: Container(
                  width: context.width(),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        height: context.height(),
                        width: context.width(),
                        margin: EdgeInsets.only(
                            bottom: 66 + (isShowOption ? 50 : 0)),
                        padding: EdgeInsets.only(left: 16, right: 16),
                        child: SingleChildScrollView(
                          reverse:
                              true, // Keeps the latest message at the bottom
                          child: Column(
                            children: [
                              for (var data in questionAnswers)
                                Column(
                                  children: [
                                    ChatMessageWidget(
                                      answer: data.answer.toString().trim(),
                                      data: data,
                                      isLoading: data.isLoading ?? false,
                                      firstQuestion: widget.questionAsk ?? '',
                                      onSmartReplyTap: (reply) {
                                        // Send smart reply as a user message
                                        msgController.text = reply;
                                        sendMessage();
                                      },
                                    ),
                                    Divider(color: Colors.transparent),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      isLoading == true
                          ? Center(
                              child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Lottie.asset('assets/lottieloading.json',
                                    width: 100, height: 100),
                                8.height,
                                Text(
                                  language.pleaseWait,
                                  style: primaryTextStyle(size: 14),
                                )
                              ],
                            ))
                          : SizedBox.shrink()
                    ],
                  ),
                ),
              )
            ]),
          )
        ],
      ),
    );
  }
}
