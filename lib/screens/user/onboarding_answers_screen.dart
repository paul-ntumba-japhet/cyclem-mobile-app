import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/int_extensions.dart';
import 'package:era_flutter/extensions/new_colors.dart';
import 'package:era_flutter/model/user/question_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../extensions/colors.dart';
import '../../extensions/constants.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/text_styles.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../main.dart';
import '../../utils/app_constants.dart';

class OnboardingAnswersScreen extends StatefulWidget {
  const OnboardingAnswersScreen({super.key});

  @override
  State<OnboardingAnswersScreen> createState() => _OnboardingAnswersScreenState();
}

class _OnboardingAnswersScreenState extends State<OnboardingAnswersScreen> {
  QuestionsModel? questionsModelData;

  @override
  void initState() {
    super.initState();
    _loadOnboardingData();
  }

  void _loadOnboardingData() {
    try {
      Map<String, dynamic> map = getJSONAsync(KEY_QUESTION_DATA);
      if (map.isNotEmpty) {
        setState(() {
          questionsModelData = QuestionsModel.fromJson(map);
        });
      }
    } catch (e) {
      print('Error loading onboarding data: $e');
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return language.notProvided;
    }
    try {
      // Try parsing different date formats
      DateTime? date;
      List<String> formats = [
        'yyyy-MM-dd',
        'dd-MM-yyyy',
        'MM-dd-yyyy',
        'yyyy/MM/dd',
        'dd/MM/yyyy',
      ];
      
      for (String format in formats) {
        try {
          date = DateFormat(format).parse(dateString);
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (date != null) {
        return DateFormat('MMM dd, yyyy').format(date);
      }
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  String _getGoalTypeText(int? selectedOption) {
    if (selectedOption == null || selectedOption == -1) {
      return language.notSelected;
    }
    if (questionsModelData?.step2.options.isNotEmpty == true && 
        selectedOption < questionsModelData!.step2.options.length) {
      return questionsModelData!.step2.options[selectedOption].title ?? language.Unknown;
    }
    return language.Unknown;
  }

  String _getYesNoAnswer(bool? answer) {
    if (answer == null) {
      return language.notAnswered;
    }
    return answer ? language.yes : language.no;
  }

  String _getLutealPhaseText(int? selectedOption) {
    if (selectedOption == null || selectedOption == -1) {
      return language.notSelected;
    }
    if (questionsModelData?.step6.lutealLengthList != null &&
        selectedOption < questionsModelData!.step6.lutealLengthList!.length) {
      return questionsModelData!.step6.lutealLengthList![selectedOption].toString();
    }
    return '$selectedOption ${language.days}';
  }

  Widget _buildAnswerItem(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: secondaryTextStyle(size: 12, color: grayColor),
          ),
          4.height,
          Text(
            value,
            style: primaryTextStyle(size: 16, color: textPrimaryColorGlobal),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: boldTextStyle(size: 18, color: textPrimaryColorGlobal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (questionsModelData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(language.onboardingAnswers, style: boldTextStyle()),
          backgroundColor: mainColorLight,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: grayColor),
              16.height,
              Text(
                language.noOnboardingDataFound,
                style: secondaryTextStyle(size: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(language.onboardingAnswers, style: boldTextStyle()),
          backgroundColor: mainColorLight,
          elevation: 0,
        ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1: Using CycleM
            _buildSection(language.step1UsingEra),
            _buildAnswerItem(
              language.areYouUsingEraForYourself,
              questionsModelData!.step1.selectedOption != null &&
                      questionsModelData!.step1.selectedOption != -1 &&
                      questionsModelData!.step1.selectedOption! < questionsModelData!.step1.options.length
                  ? questionsModelData!.step1.options[questionsModelData!.step1.selectedOption!]
                  : language.notAnswered,
            ),

            // Step 2: Goal Type
            _buildSection(language.step2GoalType),
            _buildAnswerItem(
              language.whatIsYourGoal,
              _getGoalTypeText(questionsModelData!.step2.selectedOption),
            ),

            // Step 2 Phone: Phone Verification
            if (questionsModelData!.step2Phone.phoneNumber != null ||
                questionsModelData!.step2Phone.isVerified == true)
              _buildSection(language.step2PhoneVerification),
            if (questionsModelData!.step2Phone.phoneNumber != null ||
                questionsModelData!.step2Phone.isVerified == true)
              _buildAnswerItem(
                language.phoneNumber,
                questionsModelData!.step2Phone.phoneNumber != null
                    ? '${questionsModelData!.step2Phone.countryCode ?? ""} ${questionsModelData!.step2Phone.phoneNumber!.maskPhoneNumber()}'
                    : language.notProvided,
              ),
            if (questionsModelData!.step2Phone.phoneNumber != null ||
                questionsModelData!.step2Phone.isVerified == true)
              _buildAnswerItem(
                language.verificationStatus,
                questionsModelData!.step2Phone.isVerified == true ? language.verified : language.notVerified,
              ),

            // Step 3 Personal Info
            if (questionsModelData!.step3PersonalInfo.fullName != null ||
                questionsModelData!.step3PersonalInfo.email != null)
              _buildSection(language.step3PersonalInformation),
            if (questionsModelData!.step3PersonalInfo.fullName != null ||
                questionsModelData!.step3PersonalInfo.email != null)
              _buildAnswerItem(
                language.fullName,
                questionsModelData!.step3PersonalInfo.fullName ?? language.notProvided,
              ),
            if (questionsModelData!.step3PersonalInfo.fullName != null ||
                questionsModelData!.step3PersonalInfo.email != null)
              _buildAnswerItem(
                language.email,
                questionsModelData!.step3PersonalInfo.email ?? language.notProvided,
              ),

            // Step 4 Questions
            if (questionsModelData!.step4Question1.answer != null ||
                questionsModelData!.step4Question2.answer != null ||
                questionsModelData!.step4Question3.answer != null)
              _buildSection(language.step4HealthQuestions),
            if (questionsModelData!.step4Question1.answer != null)
              _buildAnswerItem(
                questionsModelData!.step4Question1.question ?? language.doYouHaveExistingHealthConditions,
                _getYesNoAnswer(questionsModelData!.step4Question1.answer),
              ),
            if (questionsModelData!.step4Question2.answer != null)
              _buildAnswerItem(
                questionsModelData!.step4Question2.question ?? language.areYouCurrentlyTakingMedications,
                _getYesNoAnswer(questionsModelData!.step4Question2.answer),
              ),
            if (questionsModelData!.step4Question3.answer != null)
              _buildAnswerItem(
                questionsModelData!.step4Question3.question ?? language.consultedDoctorAboutCycle,
                _getYesNoAnswer(questionsModelData!.step4Question3.answer),
              ),

            // Step 3: Last Period Date
            _buildSection(language.step3PeriodInformation),
            _buildAnswerItem(
              language.lastPeriodDate,
              _formatDate(questionsModelData!.step3.selectedLastPeriodDate),
            ),

            // Step 6: Luteal Phase (if answered)
            if (questionsModelData!.step6.selectedOption != null &&
                questionsModelData!.step6.selectedOption != -1)
              _buildAnswerItem(
                language.lutealPhase,
                _getLutealPhaseText(questionsModelData!.step6.selectedOption),
              ),

            40.height,
          ],
        ),
      ),
    );
  }
}

