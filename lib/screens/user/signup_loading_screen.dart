import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../extensions/extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../main.dart';
import '../../model/user/question_model.dart';
import '../../model/user/cycle_info_model.dart';
import '../../network/rest_api.dart';
import '../../utils/app_constants.dart';
import '../../utils/utils.dart';
import '../screens.dart';

class SignupLoadingScreen extends StatefulWidget {
  const SignupLoadingScreen({super.key});

  @override
  State<SignupLoadingScreen> createState() => _SignupLoadingScreenState();
}

class _SignupLoadingScreenState extends State<SignupLoadingScreen> {
  double _percent = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    logScreenView("Signup loading screen");
    _startProgressAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Start the progress animation from 0 to 100%
  void _startProgressAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _percent += 0.01; // Increment by 1% each 50ms = 100% in 5 seconds
          if (_percent >= 1.0) {
            _percent = 1.0;
            timer.cancel();
            _navigateToDashboard();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Update MenstrualCycleWidget Config with onboarding data
  Future<void> updateConfiguration() async {
    try {
      // Get phone number from user store
      String? phoneNumber = userStore.user?.phoneNumber;
      if (phoneNumber == null || phoneNumber.isEmpty) {
        log("No phone number found in user store, skipping updateConfiguration");
        return;
      }
      
      // Get phone-specific question data key
      String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (phoneForAPI.isEmpty) {
        log("Phone number is empty after cleaning, skipping updateConfiguration");
        return;
      }
      
      String questionDataKey = getQuestionDataKeyForPhone(phoneForAPI);
      Map<String, dynamic> map = getJSONAsync(questionDataKey);
      
      if (map.isEmpty) {
        log("No question data found for phone $phoneForAPI, skipping updateConfiguration");
        return;
      }
      
      QuestionsModel questionsModelData = QuestionsModel.fromJson(map);
      final instance = MenstrualCycleWidget.instance;
      
      if (instance == null) {
        log("MenstrualCycleWidget.instance is null, skipping updateConfiguration");
        return;
      }
      
      // Get last period date from step3
      DateTime? lastPeriodDate;
      if (questionsModelData.step3.selectedLastPeriodDate != null && 
          questionsModelData.step3.selectedLastPeriodDate!.isNotEmpty) {
        try {
          lastPeriodDate = DateTime.parse(questionsModelData.step3.selectedLastPeriodDate!);
        } catch (e) {
          log("Error parsing last period date: $e");
          lastPeriodDate = null;
        }
      } else {
        lastPeriodDate = null;
      }
      
      // Get cycle length and period duration from questions or defaults
      int cycleLength = questionsModelData.step4.selectedOption ?? DEFAULT_CYCLE_LENGTH;
      int periodLength = questionsModelData.step5.selectedOption ?? DEFAULT_PERIOD_LENGTH;
      
      if (cycleLength == 0) {
        cycleLength = DEFAULT_CYCLE_LENGTH;
      }
      if (periodLength == 0) {
        periodLength = DEFAULT_PERIOD_LENGTH;
      }
      
      // Update MenstrualCycleWidget configuration
      instance.updateConfiguration(
        cycleLength: cycleLength,
        periodDuration: periodLength,
        customerId: userStore.userId.toString(),
        lastPeriodDate: lastPeriodDate,
      );
      
      updateMenstrualWidgetLanguage();
      
      // Create and save CycleInfoModel so circular bead diagram can access it immediately
      if (lastPeriodDate != null) {
        String periodDateString = DateFormat('yyyy-MM-dd').format(lastPeriodDate);
        CycleInfoModel cycleInfo = CycleInfoModel(
          dateCreation: DateTime.now().toIso8601String(),
          dateFertiStart: null,
          dateFertireqEnd: null,
          dateRegle: periodDateString,
          dateProchaineReglesStart: null,
          dateProchaineReglesEnd: null,
        );
        
        // Save to phone-specific SharedPreferences
        await saveCycleInfoForPhone(phoneForAPI, cycleInfo);
        
        // Load into userStore so circular bead diagram can access it immediately
        await userStore.setCycleInfo(cycleInfo);
        
        // Also save to global key for backward compatibility
        await setValue(KEY_CYCLE_INFO, cycleInfo.toJson());
        
        log("✅ CycleInfoModel created and saved for phone: $phoneForAPI with period date: $periodDateString");
      }
      
      log("✅ MenstrualCycleWidget configuration updated successfully for phone: $phoneForAPI");
    } catch (e) {
      log("❌ Error in updateConfiguration: $e");
      // Don't throw - allow navigation to continue even if configuration fails
    }
  }

  /// Navigate to dashboard when progress reaches 100%
  Future<void> _navigateToDashboard() async {
    // Update configuration before navigating
    await updateConfiguration();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        DashboardScreen(currentIndex: 0).launch(context, isNewTask: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular Progress Indicator
              CircularPercentIndicator(
                radius: 80,
                lineWidth: 12,
                animation: false,
                percent: _percent,
                backgroundColor: Colors.grey.shade200,
                animationDuration: 10,
                progressColor: primaryColor,
                circularStrokeCap: CircularStrokeCap.round,
                center: Text(
                  "${(_percent * 100).toInt()}%",
                  style: boldTextStyle(
                    size: 24,
                    weight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              40.height,
              // Loading Text
              Text(
                language.configuringYourAccount,
                style: boldTextStyle(
                  size: 20,
                  weight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              16.height,
              Text(
                language.pleaseWait,
                style: primaryTextStyle(
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ).paddingAll(32),
        ),
      ),
    );
  }
}
