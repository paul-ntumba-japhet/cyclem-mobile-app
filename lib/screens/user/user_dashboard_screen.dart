import 'dart:io';

import 'package:era_flutter/utils/app_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_cycle_widget/database_helper/menstrual_cycle_db_helper.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';
import 'package:menstrual_cycle_widget/ui/menstrual_log_period_view.dart';
import 'package:menstrual_cycle_widget/ui/model/display_symptoms_data.dart';
import '../../extensions/extensions.dart';
import '../../main.dart';
import '../../model/user/cycle_info_model.dart';
import '../../model/user/dashboard_response.dart';
import '../../network/rest_api.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import '../../service/phone_verification_service.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/dynamic_theme.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/period_date_validation.dart';
import '../../extensions/shared_pref.dart';
import '../screens.dart';

class DashboardScreen extends StatefulWidget {
  static String tag = '/DashboardScreen';

  int currentIndex;

  DashboardScreen({required this.currentIndex});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<SymptomsCategory> mSymptomsCategory = [];
  bool isSuccess = false;
  bool _isLoadingDatePicker = false;

  onSuccess() {
    appStore.setHomeScreenUpdated(true);
  }

  onError() {
    log("onError");
  }

  final List<Widget> tab = [
    HomeScreen(),
    // InsightsScreen(), // Commented out - redirecting to IkChatbotScreen instead
    IkChatbotScreen(),
    GraphsAndReportScreen(),
    MenstrualCalendarScreen(),
    SettingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AddSymptomsApiCall();
  }

  Future<bool> onWillPop() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(language.confirmExit),
              content: Text(language.AreYouSureYouWantToExit),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(language.cancel),
                ),
                TextButton(
                  onPressed: () {
                    pop();
                    exit(0);
                  },
                  child: Text(language.exit),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> AddSymptomsApiCall() async {
    final isConnected = await isNetworkAvailable();
    if (!isConnected) {
      return null;
    } else {
      List<Symptoms> SymptomsList = await AddSubSymptoms();
      for (int i = 0; i < SymptomsList.length; i++) {
        List<SymptomsData> c = [];
        for (int index = 0;
            index < SymptomsList[i].subSymptoms!.length;
            index++) {
          c.add(SymptomsData(
              isSelected: false,
              symptomId: SymptomsList[i].subSymptoms![index].id,
              symptomName: SymptomsList[i].subSymptoms![index].title));
        }
        mSymptomsCategory.add(SymptomsCategory(
            categoryColor: SymptomsList[i].bgColor,
            categoryId: SymptomsList[i].id,
            categoryName: SymptomsList[i].title,
            isVisibleCategory: SymptomsList[i].subSymptoms != null &&
                    SymptomsList[i].subSymptoms!.isNotEmpty
                ? 1
                : 0,
            symptomsData: c));
      }
    }
  }

  updateConfiguration() async {
    final String? prevPeriodDay = instance.getPreviousPeriodDay();
    final DateTime? prevPeriodDt = prevPeriodDay != null && prevPeriodDay != ""
        ? DateTime.parse(prevPeriodDay)
        : null;
    final DateTime? lastPeriodDate = (prevPeriodDt == null ||
            prevPeriodDt.isAtSameMomentAs(DateTime(1971, 1, 1)))
        ? null
        : prevPeriodDt;
    int cycleLength = getIntAsync(CYCLE_LENGTH);
    int periodLength = getIntAsync(PERIOD_LENGTH);

    if (cycleLength == 0) {
      cycleLength = DEFAULT_CYCLE_LENGTH;
      setValue(CYCLE_LENGTH, cycleLength);
    }

    if (periodLength == 0) {
      periodLength = DEFAULT_PERIOD_LENGTH;
      setValue(PERIOD_LENGTH, periodLength);
    }

    instance.updateConfiguration(
      cycleLength: cycleLength,
      periodDuration: periodLength,
      customerId: userStore.userId.toString(),
      lastPeriodDate: lastPeriodDate,
    );

    updateMenstrualWidgetLanguage();
  }

  Future<void> navigateToMenstrualLogPeriodView(bool isConnected) async {
    await NavigationUtils.navigateWithPostPopAction(
      context: context,
      screen: MenstrualLogPeriodView(
        displaySymptomsData: DisplaySymptomsData(),
        isShowCustomSymptomsOnly: true,
        customSymptomsList: mSymptomsCategory,
        onError: onError,
        onSuccess: (int id) {
          logAnalyticsEvent(category: "daily_symptoms", action: "logged");
          setState(() {
            isSuccess = true;
          });
        },
        symptomsLogDate: DateTime.now(),
      ),
      postPopAction: () async {
        if (isSuccess) {
          onSuccess();
          updateConfiguration();
        }
      },
      showRewardedAd: (appStore.adsConfig?.adsconfigAccess ?? false) &&
          (appStore.showAdsBasedOnConfig?.saveDailyLogs ?? false),
    );
  }

  /// Handle + button tap: show date picker, validate, check payment status, and update period date
  Future<void> _handlePlusButtonDatePicker() async {
    if (!mounted || _isLoadingDatePicker) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    NavigatorState? dialogNavigator;

    // Helper function to safely close the dialog
    void closeDialog() {
      if (mounted && dialogNavigator != null) {
        try {
          if (dialogNavigator!.canPop()) {
            dialogNavigator!.pop();
          }
        } catch (e) {
          // Dialog already closed or context invalid, ignore
        }
      }
      if (mounted) {
        setState(() {
          _isLoadingDatePicker = false;
        });
      }
    }

    try {
      // Step 1: Show date picker
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final firstDate = today.subtract(const Duration(days: lastPeriodDateMaxDaysAgo));

      final picked = await showDatePicker(
        context: context,
        initialDate: today,
        firstDate: firstDate,
        lastDate: today,
        helpText: language.dateSelected,
      );

      if (picked == null || !mounted) return;

      // Step 2: Validate the selected date
      final validation = validateLastPeriodDate(picked);
      if (!validation.isValid) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(validation.errorMessage ?? periodDateValidationErrorTooOld),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Step 3: Get and format phone number
      String fullPhoneNumber = userStore.user?.phoneNumber ?? '';
      fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (!fullPhoneNumber.startsWith('+') && fullPhoneNumber.isNotEmpty) {
        fullPhoneNumber = '+$fullPhoneNumber';
      }

      if (fullPhoneNumber.isEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(language.phoneNotAvailablePleaseReconnect),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Step 4: Check payment status (with loading)
      setState(() {
        _isLoadingDatePicker = true;
      });

      // Show loading dialog and store the navigator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          dialogNavigator = Navigator.of(dialogContext);
          return PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      language.pleaseWait,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      PaymentFlowMetadata? paymentFlowMetadata;
      try {
        paymentFlowMetadata = await getPaymentFlowMetadata(
          phoneNumber: fullPhoneNumber,
          dateRegle: DateFormat('yyyy-MM-dd').format(picked),
        );
      } catch (e) {
        if (mounted) {
          closeDialog();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('${language.errorLabel}: ${language.failedToLoadTransactions}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) {
        closeDialog();
        return;
      }

      // Step 5: Handle different payment status codes
      if (paymentFlowMetadata.paymentStatus.code == '100') {
        // Active payment - call subscription API
        final periodDate = DateFormat('yyyy-MM-dd').format(picked);

        // Prepare question answers (default values)
        const bool q1 = true;
        const bool q2 = true;
        const bool q3 = false;

        // Call subscription API
        final success = await PhoneVerificationService.createSubscriptionWithPeriodDate(
          phoneNumber: fullPhoneNumber,
          periodDate: periodDate,
          question1Answer: q1,
          question2Answer: q2,
          question3Answer: q3,
        );

        if (!mounted) {
          closeDialog();
          return;
        }

        closeDialog();

        // Check if API returned status 200
        if (success) {
          // Subscription API returned status 200 - update period date
          final phoneForAPI = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
          await userStore.setPeriodDate(periodDate);

          // Update cycle info
          final existingCycleInfo = userStore.cycleInfo ?? loadCycleInfoForPhone(phoneForAPI);
          final updatedCycleInfo = CycleInfoModel(
            dateCreation: existingCycleInfo?.dateCreation,
            dateFertiStart: existingCycleInfo?.dateFertiStart,
            dateFertireqEnd: existingCycleInfo?.dateFertireqEnd,
            dateRegle: periodDate,
            dateProchaineReglesStart: existingCycleInfo?.dateProchaineReglesStart,
            dateProchaineReglesEnd: existingCycleInfo?.dateProchaineReglesEnd,
          );
          await userStore.setCycleInfo(updatedCycleInfo);
          await saveCycleInfoForPhone(phoneForAPI, updatedCycleInfo);
          await setValue(KEY_CYCLE_INFO, updatedCycleInfo.toJson());

          // Show success message
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(language.periodDateSavedSuccess),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Update configuration and refresh UI
          updateConfiguration();
          appStore.setHomeScreenUpdated(true);
        } else {
          // Subscription API did not return status 200
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(language.cycleStillActive),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        closeDialog();
        await shouldRedirectToPaymentFlow(
          context: context,
          phoneNumber: fullPhoneNumber,
          dateRegle: DateFormat('yyyy-MM-dd').format(picked),
          metadata: paymentFlowMetadata,
          onMobilePaymentRedirect: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(language.mustPayBeforeSubmittingDate),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          },
          onError: (message) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message.isNotEmpty ? message : language.anErrorHasOccurred),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          },
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog if it's still open
        closeDialog();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${language.errorLabel}: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) onWillPop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: false,
        body: _getBody(widget.currentIndex),
        // Render the appropriate body based on currentIndex
        floatingActionButton: FloatingActionButton(
          elevation: 0,
          heroTag: language.todayActivity,
          child: _isLoadingDatePicker
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.add, size: 44, color: Colors.white),
          onPressed: _isLoadingDatePicker
              ? null
              : () async {
                  await _handlePlusButtonDatePicker();
                },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Observer(
          builder: (context) {
            // Access appStore.selectedLanguage to ensure Observer tracks language changes
            appStore.selectedLanguage;
            return StylishBottomBar(
              backgroundColor: kPrimaryColor,
              hasNotch: true,
              notchStyle: NotchStyle.circle,
              elevation: 1,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              option: AnimatedBarOptions(iconStyle: IconStyle.Default),
              currentIndex: widget.currentIndex,
              fabLocation: StylishBarFabLocation.center,
              onTap: (index) async {
                if (index != widget.currentIndex) {
                  if (index == 1) {
                    bool isConnected = await isNetworkAvailable();
                    if (!isConnected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              language.noInternetConnectionCannotAccessThisPage),
                          backgroundColor: ColorUtils.colorPrimary,
                        ),
                      );
                      return;
                    }
                  }
                  setState(() {
                    widget.currentIndex = index;
                  });
                }
              },
              items: [
                BottomBarItem(
                  icon: Icon(Icons.home_outlined, size: 24, color: textPrimaryColorGlobal),
                  selectedIcon: Icon(Icons.home, size: 24, color: ColorUtils.colorPrimary),
                  title: Text(
                    language.homeLabel,
                    style: boldTextStyle(
                      weight: FontWeight.w400,
                      size: textFontSize_12,
                      color: widget.currentIndex == 0
                          ? ColorUtils.colorPrimary
                          : textPrimaryColorGlobal,
                    ),
                  ),
                ),
                BottomBarItem(
                  icon: Icon(Icons.chat_bubble_outline, size: 24, color: textPrimaryColorGlobal),
                  selectedIcon: Icon(Icons.chat_bubble, size: 24, color: ColorUtils.colorPrimary),
                  title: Text(
                    language.chatLabel,
                    style: boldTextStyle(
                      weight: FontWeight.w400,
                      size: textFontSize_12,
                      color: widget.currentIndex == 1
                          ? ColorUtils.colorPrimary
                          : textPrimaryColorGlobal,
                    ),
                  ),
                ),
                BottomBarItem(
                  icon: Image.asset(ic_clipboard, width: 24),
                  selectedIcon: Image.asset(ic_clipboard,
                      color: ColorUtils.colorPrimary, width: 24),
                  title: Text(
                    language.reports,
                    style: boldTextStyle(
                      weight: FontWeight.w400,
                      size: textFontSize_12,
                      color: widget.currentIndex == 2
                          ? ColorUtils.colorPrimary
                          : textPrimaryColorGlobal,
                    ),
                  ),
                ),
                BottomBarItem(
                  icon: Image.asset(ic_calendar_minimalistic, width: 24),
                  selectedIcon: Image.asset(ic_calendar_minimalistic,
                      color: ColorUtils.colorPrimary, width: 24),
                  title: Text(
                    language.calendarLabel,
                    style: boldTextStyle(
                      weight: FontWeight.w400,
                      size: textFontSize_12,
                      color: widget.currentIndex == 3
                          ? ColorUtils.colorPrimary
                          : textPrimaryColorGlobal,
                    ),
                  ),
                ),
                BottomBarItem(
                  icon: Image.asset(ic_user_circle, width: 24),
                  selectedIcon: Image.asset(ic_user_circle,
                      color: ColorUtils.colorPrimary, width: 24),
                  title: Text(
                    language.Account,
                    style: boldTextStyle(
                      weight: FontWeight.w400,
                      size: textFontSize_12,
                      color: widget.currentIndex == 4
                          ? ColorUtils.colorPrimary
                          : textPrimaryColorGlobal,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

// Helper method to return the appropriate body based on the currentIndex
  Widget _getBody(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return tab[0];
      case 1:
        return tab[1];
      case 2:
        return tab[2];
      case 3:
        return tab[3];
      case 4:
        return tab[4];
      default:
        return tab[0];
    }
  }
}
