import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/main.dart';
import 'package:era_flutter/screens/user/sign_in_screen.dart';
import 'package:era_flutter/screens/user/sign_up_screen.dart';
import 'package:era_flutter/utils/app_common.dart';
import 'package:era_flutter/utils/app_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../extensions/new_colors.dart';
import '../../extensions/shared_pref.dart';
import '../../languageConfiguration/LanguageDataConstant.dart';
import '../../languageConfiguration/LanguageDefaultJson.dart';
import '../../model/user/question_model.dart';
import '../../network/rest_api.dart';
import '../../utils/dynamic_theme.dart';
import '../doctor/doctor_login_screen.dart';
import '../../utils/app_images.dart';
import 'package:era_flutter/screens/user/widgets/phone_verification_widget.dart';
import 'package:era_flutter/screens/user/widgets/personal_info_widget.dart';
import 'package:era_flutter/screens/user/widgets/yes_no_question_widget.dart';
import 'package:era_flutter/service/phone_verification_service.dart';
import 'package:era_flutter/utils/period_date_validation.dart';

class QuestionsListScreen extends StatefulWidget {
  @override
  State<QuestionsListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionsListScreen> with SingleTickerProviderStateMixin {
  int currentStep = 1;
  bool _isPhoneVerified = false;

  DateTime? _selectedDay;
  DateTime? _focusedDay;
  // Map<DateTime, List<Event>> events = {};

  // Loading state management for subscription API
  bool _isLoadingSubscription = false;
  String _loadingMessage = "";
  bool _isPeriodDateLoading = false;
  late AnimationController _loadingAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  /// Save questionsModel to phone-specific key only (when phone is available)
  /// Never stores to global key - all user data is phone-specific
  Future<void> _saveQuestionsModel() async {
    // Only save to phone-specific key if phone number is available
    String? phoneNumber = questionsModel.step2Phone.phoneNumber;
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (phoneForAPI.isNotEmpty) {
        await saveQuestionDataForPhone(phoneForAPI, questionsModel);
        print('✅ QuestionsModel saved for phone: $phoneForAPI');
      } else {
        print('⚠️ Cannot save questionsModel: phone number is empty after cleaning');
      }
    } else {
      print('⚠️ Cannot save questionsModel: phone number not available');
    }
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    
    // Initialize animation controller
    _loadingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Restore previously selected date if available
    if (questionsModel.step3.selectedLastPeriodDate != null && 
        questionsModel.step3.selectedLastPeriodDate!.isNotEmpty) {
      try {
        _selectedDay = DateFormat('yyyy-MM-dd').parse(questionsModel.step3.selectedLastPeriodDate!);
        _focusedDay = _selectedDay;
      } catch (e) {
        // If parsing fails, use current date
        _selectedDay = DateTime.now();
        _focusedDay = _selectedDay;
      }
    }
    
    // Check if phone is already verified
    _isPhoneVerified = questionsModel.step2Phone.isVerified ?? false;
    logScreenView("Question List screen");
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }

  void _setLoadingSubscription(
    bool loading, {
    String message = "",
    bool isPeriodDate = false,
  }) {
    if (mounted) {
      setState(() {
        _isLoadingSubscription = loading;
        _loadingMessage = message;
        _isPeriodDateLoading = loading ? isPeriodDate : false;
      });
      if (!loading) {
        _loadingAnimationController.stop();
        _loadingAnimationController.reset();
      } else {
        _loadingAnimationController.repeat(reverse: true);
      }
    }
  }

  String buildTitle() {
    switch (currentStep) {
      case 1:
        return questionsModel.step1.title.toString();
      case 2:
        return questionsModel.step2.title.toString();
      case 3:
        return language.verifyYourPhoneNumber;
      case 4:
        return language.completeYourProfile;
      case 5:
        return questionsModel.step4Question1.question ?? "";
      case 6:
        return questionsModel.step4Question2.question ?? "";
      case 7:
        return questionsModel.step4Question3.question ?? "";
      case 8:
        return questionsModel.step3.title.toString();
      default:
        return questionsModel.step3.title.toString();
    }
  }

  bool validateStep2Phone() {
    if (currentStep == 3) {
      if (questionsModel.step2Phone.isVerified != true) {
        toast(language.pleaseVerifyPhoneToContinue);
        return false;
      }
    }
    return true;
  }

  bool validateStep3PersonalInfo() {
    if (currentStep == 4) {
      // Validate full name
      if (questionsModel.step3PersonalInfo.fullName == null || 
          questionsModel.step3PersonalInfo.fullName!.trim().isEmpty) {
        toast(language.pleaseEnterFullName);
        return false;
      }
      
      // Validate email
      if (questionsModel.step3PersonalInfo.email == null || 
          questionsModel.step3PersonalInfo.email!.trim().isEmpty) {
        toast(language.pleaseEnterYourEmailAddress);
        return false;
      }
      
      // Validate email format
      if (!questionsModel.step3PersonalInfo.email!.validateEmail()) {
        toast(language.pleaseEnterValidEmail);
        return false;
      }
      
      // Mark as completed and save
      questionsModel.step3PersonalInfo.isCompleted = true;
      _saveQuestionsModel();
    }
    return true;
  }

  bool validateStep4Question1() {
    if (currentStep == 5) {
      if (questionsModel.step4Question1.answer == null) {
        toast(language.pleaseSelectAnAnswer);
        return false;
      }
      questionsModel.step4Question1.isCompleted = true;
      _saveQuestionsModel();
    }
    return true;
  }

  bool validateStep4Question2() {
    if (currentStep == 6) {
      if (questionsModel.step4Question2.answer == null) {
        toast(language.pleaseSelectAnAnswer);
        return false;
      }
      questionsModel.step4Question2.isCompleted = true;
      _saveQuestionsModel();
    }
    return true;
  }

  Future<bool> validateStep4Question3() async {
    if (currentStep == 7) {
      if (questionsModel.step4Question3.answer == null) {
        toast(language.pleaseSelectAnAnswer);
        return false;
      }
      
      // Mark question as completed
      questionsModel.step4Question3.isCompleted = true;
      _saveQuestionsModel();
      
      // Call subscription API with questionnaire answers
      // Get required data from previous steps
      String? phoneNumber = questionsModel.step2Phone.phoneNumber;
      String? countryCode = questionsModel.step2Phone.countryCode ?? "+1";
      String? email = questionsModel.step3PersonalInfo.email;
      String? name = questionsModel.step3PersonalInfo.fullName;
      
      // Validate required data
      if (phoneNumber == null || phoneNumber.isEmpty) {
        toast(language.phoneNumberNotFoundVerifyFirst);
        return false;
      }
      
      if (email == null || email.isEmpty) {
        toast(language.emailNotFoundCompleteProfileFirst);
        return false;
      }
      
      if (name == null || name.isEmpty) {
        toast(language.nameNotFoundCompleteProfileFirst);
        return false;
      }
      
      // Format phone number with country code
      String fullPhoneNumber = '$countryCode$phoneNumber';
      fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (!fullPhoneNumber.startsWith('+')) {
        fullPhoneNumber = '+$fullPhoneNumber';
      }
      
      // Get question answers (convert null to false for safety, but this shouldn't happen)
      bool q1Answer = questionsModel.step4Question1.answer ?? false;
      bool q2Answer = questionsModel.step4Question2.answer ?? false;
      bool q3Answer = questionsModel.step4Question3.answer ?? false;
      
      // Show loading animation while calling subscription API
      _setLoadingSubscription(true, message: language.submittingAnswersPleaseWait, isPeriodDate: false);
      
      try {
        // Call subscription API
        bool subscriptionSuccess = await PhoneVerificationService.createSubscriptionWithAnswers(
          phoneNumber: fullPhoneNumber,
          email: email,
          name: name,
          question1Answer: q1Answer,
          question2Answer: q2Answer,
          question3Answer: q3Answer,
        );
        
        _setLoadingSubscription(false);
        
        if (!subscriptionSuccess) {
          // Subscription failed, don't proceed
          return false;
        }
        
        // Subscription successful (status 200 or 201), proceed to next step
        return true;
      } catch (e) {
        _setLoadingSubscription(false);
        toast("${language.errorCompletingSubscription}: ${e.toString()}");
        return false;
      }
    }
    // If not step 7, return true (no validation needed)
    return true;
  }

  Future<bool> validateStep3PeriodDate() async {
    if (currentStep == 8) {
      final validation = validateLastPeriodDate(_selectedDay);
      if (!validation.isValid) {
        toast(validation.errorMessage ?? language.pleaseSelectDateOfLastPeriod);
        return false;
      }

      // Format date for API
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay!);
      questionsModel.step3.selectedLastPeriodDate = formattedDate;
      _saveQuestionsModel();

      // Call subscription API with period date
      // Get required data from previous steps
      String? phoneNumber = questionsModel.step2Phone.phoneNumber;
      String? countryCode = questionsModel.step2Phone.countryCode ?? "+1";
      
      // Validate phone number exists
      if (phoneNumber == null || phoneNumber.isEmpty) {
        toast(language.phoneNumberNotFoundVerifyFirst);
        return false;
      }

      // Format phone number with country code
      String fullPhoneNumber = '$countryCode$phoneNumber';
      fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (!fullPhoneNumber.startsWith('+')) {
        fullPhoneNumber = '+$fullPhoneNumber';
      }

      // Get question answers
      bool q1Answer = questionsModel.step4Question1.answer ?? false;
      bool q2Answer = questionsModel.step4Question2.answer ?? false;
      bool q3Answer = questionsModel.step4Question3.answer ?? false;

      // Show loading animation while calling subscription API
      _setLoadingSubscription(true, message: language.savingPeriodDatePleaseWait, isPeriodDate: true);

      try {
        // Call subscription API with period date
        bool subscriptionSuccess = await PhoneVerificationService.createSubscriptionWithPeriodDate(
          phoneNumber: fullPhoneNumber,
          periodDate: formattedDate,
          question1Answer: q1Answer,
          question2Answer: q2Answer,
          question3Answer: q3Answer,
        );

        _setLoadingSubscription(false);

        if (!subscriptionSuccess) {
          // Subscription failed, don't proceed
          return false;
        }

        // Subscription successful (status 200 or 201), proceed to next step
        return true;
      } catch (e) {
        _setLoadingSubscription(false);
        toast("${language.errorCompletingSubscription}: ${e.toString()}");
        return false;
      }
    }
    // If not step 8, return true (no validation needed)
    return true;
  }

  bool validateStep7() {
    if (currentStep == 11) {
      if (questionsModel.step7.answerToQuestion2.isEmptyOrNull) {
        toast(language.pleaseSelectYourAge);
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && currentStep > 1) {
          setState(() => currentStep--);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          physics: NeverScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: mainColorLight,
              pinned: true,
              toolbarHeight: 80,
              automaticallyImplyLeading: false,
              leading: currentStep > 1
                  ? IconButton(
                      icon: Icon(CupertinoIcons.back, color: mainColorText),
                      onPressed: () {
                        if (currentStep == 1) {
                          finish(context);
                        } else {
                          currentStep--;
                          setState(() {});
                        }
                      })
                  : null,
              titleSpacing: currentStep == 1 ? null : 0,
              title: Text(
                buildTitle(),
                maxLines: 4,
                style: boldTextStyle(
                  color: mainColorText,
                  size: 18,
                  weight: FontWeight.w500,
                ),
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: progressIndicator(),
                )
              ],
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
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.top -
                          35,
                      child: Stack(
                        children: [
                          step1().visible(currentStep == 1),
                          step2().visible(currentStep == 2),
                          step2Phone().visible(currentStep == 3),
                          step3PersonalInfo().visible(currentStep == 4),
                          step4Question1().visible(currentStep == 5),
                          step4Question2().visible(currentStep == 6),
                          step4Question3().visible(currentStep == 7),
                          step3().visible(currentStep == 8),
                          _buildLoadingOverlay(),
                          Positioned(
                            bottom: 35,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                AppButton(
                                    disabledColor: ColorUtils.colorPrimary,
                                    text: language.continueText,
                                    width: context.width() * 0.88,
                                    onTap: () async {
                                      // Phone verification step (mandatory)
                                      if (currentStep == 3) {
                                        if (validateStep2Phone()) {
                                          currentStep++;
                                          setState(() {});
                                        }
                                      } else if (currentStep == 4) {
                                        // Personal info step (mandatory)
                                        if (validateStep3PersonalInfo()) {
                                          currentStep++;
                                          setState(() {});
                                        }
                                      } else if (currentStep == 5) {
                                        // Question 1 (mandatory)
                                        if (validateStep4Question1()) {
                                          currentStep++;
                                          setState(() {});
                                        }
                                      } else if (currentStep == 6) {
                                        // Question 2 (mandatory)
                                        if (validateStep4Question2()) {
                                          currentStep++;
                                          setState(() {});
                                        }
                                      } else if (currentStep == 7) {
                                        // Question 3 (mandatory) - calls subscription API
                                        bool isValid = await validateStep4Question3();
                                        if (isValid) {
                                          currentStep++;
                                          setState(() {});
                                        }
                                      } else if (currentStep == 8) {
                                        // Period date step (last step) - validate then complete onboarding
                                        bool isValid = await validateStep3PeriodDate();
                                        if (isValid) {
                                          userStore.setCycleLength(DEFAULT_CYCLE_LENGTH);
                                          userStore.setPeriodsLength(DEFAULT_PERIOD_LENGTH);
                                          setValue(IS_USER_COMPLETED_QUE, true);
                                          _saveQuestionsModel();
                                          SignUpScreen().launch(context);
                                        }
                                      } else {
                                        currentStep++;
                                        setState(() {});
                                      }
                                    }).visible((currentStep == 2) || (currentStep == 3 && _isPhoneVerified) || (currentStep == 4) || (currentStep >= 5 && currentStep <= 8)),
                                14.height,
                                skipButton(() {
                                  if (currentStep == 8) {
                                    userStore.setCycleLength(DEFAULT_CYCLE_LENGTH);
                                    userStore.setPeriodsLength(DEFAULT_PERIOD_LENGTH);
                                    setValue(IS_USER_COMPLETED_QUE, true);
                                    _saveQuestionsModel();
                                    SignUpScreen().launch(context);
                                  } else {
                                    currentStep++;
                                    setState(() {});
                                  }
                                }).visible(currentStep > 2 && currentStep != 3 && currentStep != 4 && currentStep != 5 && currentStep != 6 && currentStep != 7 && currentStep == 8),
                                14.height,
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 30,
                            left: 0,
                            right: 0,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Question text above button
                                  Text(
                                    language.alreadyHaveAnAccount.split('?').first + '?',
                                    style: boldTextStyle(
                                      size: 16,
                                      weight: FontWeight.w400,
                                      color: mainColorText,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  12.height,
                                  // Button with action text only
                                  AppButton(
                                    disabledColor: Colors.grey.shade300,
                                    text: language.alreadyHaveAnAccount.split('?').length > 1
                                        ? language.alreadyHaveAnAccount.split('?')[1].trim()
                                        : language.login,
                                    textStyle: boldTextStyle(
                                      color: Colors.white,
                                      weight: FontWeight.w500,
                                      size: 16,
                                    ),
                                    color: primaryColor,
                                    onTap: () {
                                      UserSignInScreen().launch(context);
                                    },
                                    width: context.width(),
                                  ),
                                ],
                              ),
                            ),
                          ).visible(currentStep <= 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Skip button
  Widget skipButton(Function onTap) {
    return Text(
      language.skip,
      style: secondaryTextStyle(size: textFontSize_16),
    ).onTap(() {
      if (currentStep == 8) {
        // Set default period date when skipped
        questionsModel.step3.selectedLastPeriodDate = '2025-01-01';
        _selectedDay = DateTime(2026, 1, 1);
        _focusedDay = _selectedDay;
      }
      _saveQuestionsModel();
      onTap();
    });
  }

  Widget step1() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: questionsModel.step1.options.length,
      physics: NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            if (index == 1) {
              DoctorLoginScreen().launch(context);
            } else {
              questionsModel.step1.selectedOption = index;
              currentStep = 2;
              setState(() {});
            }
          },
          child: Container(
            width: context.width(),
            height: 80,
            padding: EdgeInsets.symmetric(vertical: 18),
            margin: EdgeInsets.all(8),
            decoration: boxDecorationWithRoundedCorners(
              borderRadius: BorderRadius.circular(defaultRadius),
              backgroundColor: Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: mainBgLightGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    index == 0 ? ic_anchor : ic_doctor_image,
                    width: 25,
                    height: 25,
                    fit: BoxFit.cover,
                  ),
                ).paddingLeft(8),
                Expanded(
                  child: Text(
                    questionsModel.step1.options[index],
                    style: boldTextStyle(
                        size: 18,
                        weight: FontWeight.w400,
                        color: mainColorText),
                    textAlign: TextAlign.center, // Center text horizontally
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: primaryColor,
                    size: 20,
                  ),
                  onPressed: () {
                    if (index == 1) {
                      DoctorLoginScreen().launch(context);
                    } else {
                      questionsModel.step1.selectedOption = index;
                      currentStep = 2;
                      setState(() {});
                    }
                  },
                ).paddingRight(8),
              ],
            ),
          ),
        );
      },
    ).paddingAll(8);
  }

  Widget step2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        8.height,
        Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            questionsModel.step2.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
          ),
        ),
        10.height,
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: questionsModel.step2.options.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  questionsModel.step2.selectedOption = index;
                });
              },
              child: Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: boxDecorationWithRoundedCorners(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 1,
                    color: questionsModel.step2.selectedOption == index
                        ? mainColor
                        : gray,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(
                          questionsModel.step2.options[index].img.validate(),
                          height: 40,
                          width: 40,
                          fit: BoxFit.contain,
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  questionsModel.step2.selectedOption == index
                                      ? Colors.transparent
                                      : gray,
                            ),
                          ),
                          child: questionsModel.step2.selectedOption == index
                              ? Image.asset(ic_checkmark)
                              : null,
                        ),
                      ],
                    ),
                    8.height,
                    Text(
                      questionsModel.step2.options[index].title.validate(),
                      style: boldTextStyle(
                          size: 18,
                          weight: FontWeight.w400,
                          color: mainColorText),
                    ),
                    4.height,
                    Text(
                      questionsModel.step2.options[index].desc.validate(),
                      style: boldTextStyle(
                          size: 14,
                          weight: FontWeight.w400,
                          color: mainColorBodyText),
                      maxLines: 4,
                    ),
                  ],
                ),
              ).paddingOnly(bottom: 16),
            );
          },
        ),
      ],
    ).paddingAll(10);
  }

  Widget step2Phone() {
    return PhoneVerificationWidget(
      onVerified: () {
        // Phone verified, update local state and trigger rebuild
        if (mounted) {
          setState(() {
            _isPhoneVerified = questionsModel.step2Phone.isVerified ?? false;
          });
        }
      },
    );
  }

  Widget step3PersonalInfo() {
    return PersonalInfoWidget(
      onCompleted: () {
        // Personal info completed, trigger rebuild if needed
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget step4Question1() {
    return YesNoQuestionWidget(
      question: questionsModel.step4Question1.question ?? language.doYouHavePeriodAlmostEveryMonth,
      initialAnswer: questionsModel.step4Question1.answer,
      onAnswerSelected: (bool answer) {
        questionsModel.step4Question1.answer = answer;
        _saveQuestionsModel();
      },
      onCompleted: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget step4Question2() {
    return YesNoQuestionWidget(
      question: questionsModel.step4Question2.question ?? language.doYouHavePeriodWhenExpected,
      initialAnswer: questionsModel.step4Question2.answer,
      onAnswerSelected: (bool answer) {
        questionsModel.step4Question2.answer = answer;
        _saveQuestionsModel();
      },
      onCompleted: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget step4Question3() {
    return YesNoQuestionWidget(
      question: questionsModel.step4Question3.question ?? language.areYouBreastfeeding,
      initialAnswer: questionsModel.step4Question3.answer,
      onAnswerSelected: (bool answer) {
        questionsModel.step4Question3.answer = answer;
        _saveQuestionsModel();
      },
      onCompleted: () {
        if (mounted) {
          setState(() {});
        }
      },
      invertSelectionColor: true, // "Are you breastfeeding?" – No = green
    );
  }

  Widget _buildLoadingOverlay() {
    if (!_isLoadingSubscription) return SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: AnimatedBuilder(
            animation: _loadingAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing circle
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(0.1),
                              ),
                            ),
                            // Inner animated circle
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryColor,
                                ),
                              ),
                            ),
                            // Center icon (changes based on loading message context)
                            Icon(
                              _isPeriodDateLoading
                                  ? Icons.calendar_today
                                  : Icons.assignment_turned_in,
                              color: primaryColor,
                              size: 28,
                            ),
                          ],
                        ),
                        24.height,
                        Text(
                          _loadingMessage.isNotEmpty 
                              ? _loadingMessage 
                              : language.submittingAnswersPleaseWait,
                          style: boldTextStyle(
                            size: 16,
                            color: mainColorText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        8.height,
                        Text(
                          language.pleaseWait,
                          style: secondaryTextStyle(
                            size: 14,
                            color: gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget step3() {
    return Observer(
      builder: (context) {
        // Get current language locale for calendar
        final locale = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            8.height,
            Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                questionsModel.step3.desc.toString(),
                style: boldTextStyle(
                    color: mainColorText, weight: FontWeight.w400, size: 16),
              ),
            ),
            10.height,
            TableCalendar(
              firstDay: DateTime.now().subtract(Duration(days: 35)), // Allow some buffer for navigation
              lastDay: DateTime.now(), // Today is the last selectable day
              focusedDay: _focusedDay!,
              calendarFormat: CalendarFormat.month,
              locale: locale,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                // Deselect current date first
                setState(() {
                  _selectedDay = null;
                  _focusedDay = focusedDay;
                });
                
                // Show confirmation dialog with selected date
                _showDateConfirmationDialog(selectedDay);
              },
              enabledDayPredicate: (day) => isLastPeriodDateInAllowedRange(day),
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                titleTextStyle: boldTextStyle(),
                titleCentered: true,
                formatButtonVisible: false,
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                markersAlignment: Alignment.bottomCenter,
                todayDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ).paddingSymmetric(horizontal: 16);
      },
    );
  }

  /// Show confirmation dialog when a date is selected
  void _showDateConfirmationDialog(DateTime selectedDay) {
    // Get current language locale for date formatting
    final locale = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
    final formattedDate = DateFormat('dd MMMM yyyy', locale).format(selectedDay);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            language.dateSelected,
            style: boldTextStyle(color: mainColorText, size: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.youHaveSelected,
                style: primaryTextStyle(color: mainColorText, size: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  formattedDate,
                  style: boldTextStyle(
                    color: primaryColor,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                language.doYouWantToContinueWithThisDate,
                style: primaryTextStyle(color: mainColorText, size: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Deselect the date
                setState(() {
                  _selectedDay = null;
                });
              },
              child: Text(
                language.cancel,
                style: primaryTextStyle(color: Colors.grey, size: 14),
              ),
            ),
            // Next button
            ElevatedButton(
              onPressed: () {
                // Save the selected date
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = selectedDay;
                });
                questionsModel.step3.selectedLastPeriodDate = DateFormat('yyyy-MM-dd').format(selectedDay);
                _saveQuestionsModel();
                
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(language.next),
            ),
          ],
        );
      },
    );
  }

  Widget step4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            questionsModel.step3.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
            textAlign: TextAlign.start,
          ),
        ),
        SizedBox(
          height: context.height() * 0.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CupertinoPicker(
                squeeze: 0.8,
                selectionOverlay: SizedBox(),
                itemExtent: 34.0,
                onSelectedItemChanged: (int selectedItem) {
                  setState(() {
                    String selectedValue = questionsModel
                        .step4.cycleLengthList![selectedItem]
                        .toString();
                    if (selectedValue != "Select") {
                      questionsModel.step4.selectedOption =
                          int.parse(selectedValue);
                      userStore.setCycleLength(int.parse(selectedValue));
                    } else {
                      questionsModel.step4.selectedOption =
                          DEFAULT_CYCLE_LENGTH;
                      userStore.setCycleLength(DEFAULT_CYCLE_LENGTH);
                    }
                    _saveQuestionsModel();
                  });
                },
                children: getCycleLengthList().map((Object item) {
                  return Center(
                    child: Text(
                      item.toString(),
                      style: boldTextStyle(
                          size: textFontSize_28, weight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 25),
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 18),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget step5() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            questionsModel.step5.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
            textAlign: TextAlign.start,
          ),
        ),
        SizedBox(
          height: context.height() * 0.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CupertinoPicker(
                squeeze: 0.8,
                selectionOverlay: SizedBox(),
                itemExtent: 34.0,
                onSelectedItemChanged: (int selectedItem) {
                  setState(() {
                    String selectedValue = questionsModel
                        .step5.periodLengthList![selectedItem]
                        .toString();
                    if (selectedValue != "Select") {
                      questionsModel.step5.selectedOption =
                          int.parse(selectedValue);
                      userStore.setPeriodsLength(int.parse(selectedValue));
                    } else {
                      questionsModel.step5.selectedOption =
                          DEFAULT_PERIOD_LENGTH;
                      userStore.setPeriodsLength(DEFAULT_PERIOD_LENGTH);
                    }
                    _saveQuestionsModel();
                  });
                },
                children: getPeriodLengthList().map((Object item) {
                  return Center(
                    child: Text(
                      item.toString(),
                      style: boldTextStyle(size: textFontSize_28),
                    ),
                  );
                }).toList(),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 25),
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 18),
                ],
              ),
            ],
          ),
        ),
        16.height,
      ],
    );
  }

  Widget step7(BuildContext context, StateSetter setState) {
    final ageOptions = generateBirthYearOptions();

    if (questionsModel.step7.answerToQuestion2.isEmptyOrNull) {
      questionsModel.step7.answerToQuestion2 = ageOptions.first;
      _saveQuestionsModel();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionsModel.step7.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
            textAlign: TextAlign.start,
          ),
          24.height,
          Text(
            questionsModel.step7.question2.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 14),
          ),
          8.height,
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: CupertinoPicker(
              itemExtent: 40.0,
              onSelectedItemChanged: (int selectedIndex) {
                setState(() {
                  questionsModel.step7.answerToQuestion2 =
                      ageOptions[selectedIndex];
                });
                _saveQuestionsModel();
              },
              children: ageOptions.map((age) {
                return Center(
                  child: Text(
                    age,
                    style: boldTextStyle(
                        color: mainColorText,
                        weight: FontWeight.w500,
                        size: 22),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget progressIndicator() {
    return CircularPercentIndicator(
      radius: 28.0,
      lineWidth: 6.0,
      percent: (currentStep / 8) > 1 ? 1 : currentStep / 8,
      animation: true,
      center: Text(
        "${currentStep.toInt()} /8",
        style: boldTextStyle(size: textFontSize_14),
      ),
      backgroundColor: Colors.white,
      progressColor: primaryColor,
    );
  }
}
