
import 'package:era_flutter/extensions/extension_util/int_extensions.dart';
import 'package:era_flutter/extensions/extension_util/widget_extensions.dart';
import 'package:era_flutter/screens/screens.dart';
import 'package:era_flutter/utils/dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';

import '../../extensions/shared_pref.dart';
import '../../main.dart';
import '../../model/user/question_model.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';

class PleaseWaitScreen extends StatefulWidget {
  final int currentGoalType;

  const PleaseWaitScreen({super.key, required this.currentGoalType});

  @override
  State<PleaseWaitScreen> createState() => _PleaseWaitScreenState();
}

class _PleaseWaitScreenState extends State<PleaseWaitScreen> {
  QuestionsModel? questionsModelData;
  late Timer _dotsTimer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    updateUserGoalStatus();
    logScreenView("GoalType process screen");
    
    // Start 3 dots animation
    _dotsTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4; // 0, 1, 2, 3 (0 = no dots, 3 = three dots)
        });
      }
    });
  }
  
  @override
  void dispose() {
    _dotsTimer.cancel();
    super.dispose();
  }
  
  String _getDotsText() {
    return '.' * _dotCount;
  }

  updateUserGoalStatus() async {
    if (getStringAsync(USER_TYPE) == ANONYMOUS) {
      Map<String, dynamic> map = getJSONAsync(KEY_QUESTION_DATA);
      questionsModelData = QuestionsModel.fromJson(map);
    } else {
      questionsModelData = QuestionsModel(
        step1: step1,
        step2: step2,
        step2Phone: step2Phone,
        step3PersonalInfo: step3PersonalInfo,
        step4Question1: step4Question1,
        step4Question2: step4Question2,
        step4Question3: step4Question3,
        step3: step3,
        step4: step4,
        step5: step5,
        step6: step6,
        step7: step7,
      );
    }
    Map req = {
      "id": userStore.userId,
      "goal_type": widget.currentGoalType,
    };
    await updateUserStatusApi(req).then(
      (value) {
        // Save to phone-specific key only
        String? phoneNumber = userStore.user?.phoneNumber;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
          if (phoneForAPI.isNotEmpty) {
            saveQuestionDataForPhone(phoneForAPI, questionsModelData!);
          }
        }
        setValue(GOAL, widget.currentGoalType);
        userStore.setGoal(widget.currentGoalType);

        DashboardScreen(currentIndex: 0).launch(context, isNewTask: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
     canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ColorUtils.colorPrimary, Color(0xFF6a1b9a)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Loading Indicator
                SpinKitFadingCircle(
                  color: Colors.white,
                  size: 80.0,
                ),
                30.height,
                // Animated 3 dots
                Text(
                  _getDotsText(),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
