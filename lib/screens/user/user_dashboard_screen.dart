import 'dart:io';

import 'package:era_flutter/utils/app_images.dart';
import 'package:flutter/material.dart';
import 'package:menstrual_cycle_widget/database_helper/menstrual_cycle_db_helper.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';
import 'package:menstrual_cycle_widget/ui/menstrual_log_period_view.dart';
import 'package:menstrual_cycle_widget/ui/model/display_symptoms_data.dart';
import '../../extensions/extensions.dart';
import '../../main.dart';
import '../../model/user/dashboard_response.dart';
import '../../network/rest_api.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/dynamic_theme.dart';
import '../../utils/navigation_utils.dart';
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

  onSuccess() {
    appStore.setHomeScreenUpdated(true);
  }

  onError() {
    log("onError");
  }

  final List<Widget> tab = [
    HomeScreen(),
    InsightsScreen(),
    GraphsAndReportScreen(),
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
          child: Icon(Icons.add, size: 44, color: Colors.white),
          onPressed: () async {
            final isConnected = await isNetworkAvailable();
            if (isConnected) {
              if (mSymptomsCategory == []) {
                await AddSymptomsApiCall();
              }
            }

            navigateToMenstrualLogPeriodView(isConnected);
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: StylishBottomBar(
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
              icon: Image.asset(ic_calender, width: 24),
              selectedIcon: Image.asset(ic_calender,
                  color: ColorUtils.colorPrimary, width: 24),
              title: Text(
                language.analysis,
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
              icon: Image.asset(ic_analysis, width: 24),
              selectedIcon: Image.asset(ic_analysis,
                  color: ColorUtils.colorPrimary, width: 24),
              title: Text(
                language.selfCare,
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
              icon: Image.asset(ic_user_circle, width: 24),
              selectedIcon: Image.asset(ic_user_circle,
                  color: ColorUtils.colorPrimary, width: 24),
              title: Text(
                language.Account,
                style: boldTextStyle(
                  weight: FontWeight.w400,
                  size: textFontSize_12,
                  color: widget.currentIndex == 3
                      ? ColorUtils.colorPrimary
                      : textPrimaryColorGlobal,
                ),
              ),
            ),
          ],
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
      default:
        return tab[0];
    }
  }
}
