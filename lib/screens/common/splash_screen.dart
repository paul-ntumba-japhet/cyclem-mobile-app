import 'dart:convert';
import 'package:era_flutter/languageConfiguration/LanguageDataConstant.dart';
import 'package:era_flutter/languageConfiguration/ServerLanguageResponse.dart';
import 'package:era_flutter/model/user/user_models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:menstrual_cycle_widget/utils/enumeration.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:store_checker/store_checker.dart';
import '../../../extensions/extension_util/context_extensions.dart';
import '../../../extensions/extension_util/string_extensions.dart';
import '../../components/user/warning_dialog.dart';
import '../../extensions/extensions.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_images.dart';
import '../../utils/biometric_utils.dart';
import '../doctor/doctor_dashboard_screen.dart';
import '../user/questions_list_screen.dart';
import '../user/user_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  static const String tag = '/SplashScreen';

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  PackageInfo? _packageInfo;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  Future<void> initializeApp() async {
    // Set Package Info
    await loadPackageInfo();

    // Get version number
    String versionNo = await getStringAsync(CURRENT_LAN_VERSION,
        defaultValue: LanguageVersion);

    // Handle language and theme configuration
    if (await isNetworkAvailable()) {
      await getLanguageList(versionNo).then((value) async {
        appStore.setLoading(false);
        CurrentAndroidVersion = value.details!.androidVersionCode!;
        CurrentIOSVersion = value.details!.iosVersion!;
        isAndroidForceUpdate = value.details!.androidForceUpdate!;
        isIOSForceUpdate = value.details!.iosForceUpdate!;
        androidLiveUrl = value.details!.playstoreUrl ?? "";
        iOSLiveUrl = value.details!.appstoreUrl ?? "";
        if (value.status == true) {
          setValue(CURRENT_LAN_VERSION, value.currentVersionNo.toString());
          setValue(CURRENT_LAN_VERSION, value.currentVersionNo ?? LanguageVersion);
          if (value.data!.length > 0) {
            appStore.setThemeColor(value.themeColor!);
            appStore.updateTheme(hexToColor(value.themeColor!));
            setValue("themeColor", value.themeColor!);
            defaultServerLanguageData = value.data;
            performLanguageOperation(defaultServerLanguageData);
            setValue(LanguageJsonDataRes, value.toJson());
            bool isSetLanguage =
                getBoolAsync(IS_SELECTED_LANGUAGE_CHANGE, defaultValue: false);
            if (!isSetLanguage) {
              for (int i = 0; i < value.data!.length; i++) {
                if (value.data![i].isDefaultLanguage == 1) {
                  setValue(SELECTED_LANGUAGE_CODE, value.data![i].languageCode);
                  setValue(SELECTED_LANGUAGE_COUNTRY_CODE,
                      value.data![i].countryCode);
                  appStore.setLanguage(value.data![i].languageCode!,
                      context: context);
                }
              }
            }
          } else {
            defaultServerLanguageData = [];
            setValue(LanguageJsonDataRes, "");
          }
        } else {
          String jsonData =
              getStringAsync(LanguageJsonDataRes, defaultValue: "");
          if (jsonData.isNotEmpty) {
            ServerLanguageResponse languageSettings =
                ServerLanguageResponse.fromJson(json.decode(jsonData.trim()));
            if (languageSettings.data != null &&
                languageSettings.data!.isNotEmpty) {
              defaultServerLanguageData = languageSettings.data;
              performLanguageOperation(defaultServerLanguageData);
            }
          }
          String themeColor = getStringAsync("themeColor");
          if (themeColor.isNotEmpty) {
            appStore.setThemeColor(themeColor);
            appStore.updateTheme(hexToColor(themeColor));
          }
        }
        await setAppSettingData(value.appSettings);
        await testMenstrualCycleKeysFetch(); // Temporary test
      });
    } else {
      String jsonData = getStringAsync(LanguageJsonDataRes, defaultValue: "");
      if (jsonData.isNotEmpty) {
        ServerLanguageResponse languageSettings =
            ServerLanguageResponse.fromJson(json.decode(jsonData.trim()));
        if (languageSettings.data != null &&
            languageSettings.data!.isNotEmpty) {
          defaultServerLanguageData = languageSettings.data;
          performLanguageOperation(defaultServerLanguageData);
        }
      }
      String themeColor = getStringAsync("themeColor");
      if (themeColor.isNotEmpty) {
        appStore.setThemeColor(themeColor);
        appStore.updateTheme(hexToColor(themeColor));
      }
    }

    // Set Language and update configuration
    String langCode = getStringAsync(SELECTED_LANGUAGE_CODE);
    if (langCode == "en") {
      instance.updateLanguageConfiguration(defaultLanguage: Languages.english);
    } else if (langCode == "hi") {
      instance.updateLanguageConfiguration(defaultLanguage: Languages.hindi);
    } else if (langCode == "ar") {
      instance.updateLanguageConfiguration(defaultLanguage: Languages.arabic);
      if (defaultServerLanguageData != null && defaultServerLanguageData!.isNotEmpty) {
        LanguageJsonData data = defaultServerLanguageData!.firstWhere(
          (language) => language.languageCode == 'ar',
          orElse: () => defaultServerLanguageData![0],
        );
        await updateAppLanguageConfiguration(data: data, context: context);
      }
    }

    // Check for Dialog or Navigate
    if (!_isNavigating) {
      // Add guard check
      _isNavigating = true;
      if (getBoolAsync(IS_SHOW_WARNING_DIALOG, defaultValue: true)) {
        showWarningDialog();
      } else {
        await navigateBasedOnUserState();
      }
    }
  }

  Future<void> loadPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
    setValue(APP_VERSION, _packageInfo!.buildNumber);
    String APPSOURCE = await updateStoreCheckerData();
    debugPrint("App Source - ${APPSOURCE}");
    setValue(APP_SOURCE, APPSOURCE);
  }

  Future<String> updateStoreCheckerData() async {
    Source installationSource;
    try {
      installationSource = await StoreChecker.getSource;
    } on PlatformException {
      installationSource = Source.UNKNOWN;
    }

    // Set source text state
    switch (installationSource) {
      case Source.IS_INSTALLED_FROM_PLAY_STORE:
        return PLAY_STORE;
      case Source.IS_INSTALLED_FROM_PLAY_PACKAGE_INSTALLER:
        return GOOGLE_PACKAGE_INSTALLER;
      case Source.IS_INSTALLED_FROM_RU_STORE:
        return RUSTORE;
      case Source.IS_INSTALLED_FROM_LOCAL_SOURCE:
        return LOCAL_SOURCE;
      case Source.IS_INSTALLED_FROM_AMAZON_APP_STORE:
        return AMAZON_STORE;
      case Source.IS_INSTALLED_FROM_HUAWEI_APP_GALLERY:
        return HUAWEI_APP_GALLERY;
      case Source.IS_INSTALLED_FROM_SAMSUNG_GALAXY_STORE:
        return SAMSUNG_GALAXY_STORE;
      case Source.IS_INSTALLED_FROM_SAMSUNG_SMART_SWITCH_MOBILE:
        return SAMSUNG_SMART_SWITCH_MOBILE;
      case Source.IS_INSTALLED_FROM_XIAOMI_GET_APPS:
        return XIAOMI_GET_APPS;
      case Source.IS_INSTALLED_FROM_OPPO_APP_MARKET:
        return OPPO_APP_MARKET;
      case Source.IS_INSTALLED_FROM_VIVO_APP_STORE:
        return VIVO_APP_STORE;
      case Source.IS_INSTALLED_FROM_OTHER_SOURCE:
        return OTHER_SOURCE;
      case Source.IS_INSTALLED_FROM_APP_STORE:
        return APP_STORE;
      case Source.IS_INSTALLED_FROM_TEST_FLIGHT:
        return TEST_FLIGHT;
      case Source.UNKNOWN:
        return UNKNOWN_SOURCE;
    }
  }

  void showWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WarningDialog(),
    );
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

    if (userStore.userId.toString().isEmptyOrNull) return;

    instance.updateConfiguration(
      cycleLength: cycleLength,
      periodDuration: periodLength,
      customerId: userStore.userId.toString(),
      lastPeriodDate: lastPeriodDate,
    );

    updateMenstrualWidgetLanguage();
  }

  Future<void> navigateBasedOnUserState() async {
    final isLoggedIn = getBoolAsync(IS_LOGIN);
    if (isLoggedIn) {
      final isAuthenticated = await _authenticateUserIfRequired();
      if (!isAuthenticated) return;
      final userType = await getStringAsync(USER_TYPE);
      if (userType == APP_USER || userType == ANONYMOUS) {
        UserModel? userData = await getUserFromLocalStorage();
        userStore.setUserModelData(userData!);
        updateConfiguration();
        DashboardScreen(currentIndex: 0).launch(context, isNewTask: true);
      } else if (userType == Doctor) {
        DoctorDashboardScreen().launch(context, isNewTask: true);
      } else {
        QuestionsListScreen().launch(context, isNewTask: true);
      }
    } else {
      QuestionsListScreen().launch(context, isNewTask: true);
    }
  }

  Future<bool> _authenticateUserIfRequired() async {
    if (getBoolAsync(IS_PASS_LOCK_SET) ||
        getBoolAsync(IS_FINGERPRINT_LOCK_SET)) {
      return await authenticateUser(context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              ic_app_logo,
              width: context.width() * 0.5,
              height: context.height() * 0.5,
            ).expand(),
            if (_packageInfo != null) ...[
              Text(
                'V ${_packageInfo!.version.validate()}.${_packageInfo!.buildNumber.validate()}',
                style: secondaryTextStyle(
                    size: textFontSize_16, color: Colors.black),
              ),
              10.height,
              Text(
                "@ ${DateTime.now().year} Made by ♥ CycleM",
                style: primaryTextStyle(color: Colors.grey),
              ),
              20.height,
            ] else
              SizedBox.shrink()
          ],
        ),
      ),
    );
  }
}
