import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/screens/common/splash_screen.dart';
import 'package:era_flutter/service/notification_service.dart';
import 'package:era_flutter/service/reminder_service.dart';
import 'package:era_flutter/store/app_store.dart';
import 'package:era_flutter/store/userStore/user_store.dart';
import 'package:era_flutter/utils/permission.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminate_restart/terminate_restart.dart';

import '../../utils/app_config.dart';
import '../../utils/app_constants.dart';
import 'ads/facebook_ads_manager.dart';
import 'languageConfiguration/AppLocalizations.dart';
import 'languageConfiguration/BaseLanguage.dart';
import 'languageConfiguration/LanguageDataConstant.dart';
import 'languageConfiguration/LanguageDefaultJson.dart';
import 'languageConfiguration/ServerLanguageResponse.dart';
import 'utils/app_common.dart';

final navigatorKey = GlobalKey<NavigatorState>();
AppStore appStore = AppStore();
UserStore userStore = UserStore();
const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');
MenstrualCycleWidget instance = MenstrualCycleWidget.instance!;
const String portName = 'notification_send_port';
late SharedPreferences sharedPreferences;
late BaseLanguage language;

LanguageJsonData? selectedServerLanguageData;
List<LanguageJsonData>? defaultServerLanguageData = [];
List<String> backgroundEvents = [];
List<String> scheduleRemindersData = [];
NotificationService notificationService = NotificationService();
final List<String> days = [MON, TUE, WED, THU, FRI, SAT, SUN];
bool mIsEnterKey = false;
OneSignal oneSignal = OneSignal();
int CurrentAndroidVersion = 1;
int CurrentIOSVersion = 1;
bool isAndroidForceUpdate = false;
bool isIOSForceUpdate = false;
String? androidLiveUrl = "";
String? iOSLiveUrl = "";
String? chatgptKey;
// final GlobalKey<State> bottomBarKey = GlobalKey<State>();

/// This "Headless Task" is run when app is terminated.
/// This "Headless Task" is run when app is terminated.
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  var taskId = task.taskId;
  var timeout = task.timeout;
  if (timeout) {
    BackgroundFetch.finish(taskId);
    return;
  }

  var timestamp = DateTime.now();

  var prefs = await SharedPreferences.getInstance();

  var events = <String>[];

  var json = prefs.getString(EVENTS_KEY);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }

  // Add new event.
  events.insert(0, "$taskId@$timestamp [Headless]");
  // Persist fetch events in SharedPreferences
  prefs.setString(EVENTS_KEY, jsonEncode(events));
  rescheduleRemindersIfMissed();
  if (taskId == 'flutter_background_fetch') {
    BackgroundFetch.scheduleTask(TaskConfig(
        taskId: "com.transistorsoft.customtask",
        delay: 5000,
        periodic: false,
        forceAlarmManager: false,
        stopOnTerminate: false,
        enableHeadless: true));
  }
  BackgroundFetch.finish(taskId);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(message) async {
  await ensureFirebaseInitialized();
}

/// Initializes Firebase once and is safe to call on hot-restart.
/// Some devices / build variants may already auto-initialize the native default app;
/// in that case the plugin can throw `duplicate-app`, which we ignore.
Future<void> ensureFirebaseInitialized() async {
  try {
    if (Firebase.apps.isEmpty) {
      if (Platform.isIOS) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
}

Future<void> initializeFirebaseAnalytics() async {
  await ensureFirebaseInitialized();
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
}

/// Initialize MenstrualCycleWidget with keys from SharedPreferences or use placeholders
Future<void> initializeMenstrualCycleWidget() async {
  // Try to get stored keys from SharedPreferences
  String secretKey =
      getStringAsync(MENSTRUAL_CYCLE_SECRET_KEY, defaultValue: "");
  String ivKey = getStringAsync(MENSTRUAL_CYCLE_IV_KEY, defaultValue: "");

  // Use placeholders if keys are not stored yet
  if (secretKey.isEmpty ||
      ivKey.isEmpty ||
      secretKey == "ADD_SECRET_KEY_HERE" ||
      ivKey == "ADD_IV_KEY_HERE") {
    secretKey = "ADD_SECRET_KEY_HERE";
    ivKey = "ADD_IV_KEY_HERE";
    debugPrint(
        '⚠️ MenstrualCycleWidget: Using placeholder keys. Fetch keys from API to enable encryption.');
  }

  MenstrualCycleWidget.init(secretKey: secretKey, ivKey: ivKey);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = MyHttpOverrides();
  TerminateRestart.instance.initialize();
  sharedPreferences = await SharedPreferences.getInstance();

  // Initialize MenstrualCycleWidget with stored keys or placeholders
  await initializeMenstrualCycleWidget();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));

  await initializeFirebaseAnalytics();

  await FacebookAdsManager.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  appStore.setLanguage(DEFAULT_LANGUAGE);
  setLogInValue(isFromEducationScreen: false);
  defaultAppButtonShapeBorder =
      RoundedRectangleBorder(borderRadius: radius(defaultAppButtonRadius));
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Basic Notification Channel',
        defaultColor: primaryColor,
        playSound: true,
        importance: NotificationImportance.High,
        locked: true,
        enableVibration: true,
      ),
      NotificationChannel(
        channelKey: 'scheduled_channel',
        channelName: 'Scheduled Notifications',
        channelDescription: 'Scheduled Notification Channel',
        defaultColor: primaryColor,
        locked: true,
        importance: NotificationImportance.High,
        playSound: true,
        enableVibration: true,
      ),
    ],
  );
  initJsonFile();
  oneSignalData();
  getRemindersList();
  await Alarm.init();
  runApp(MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {
  static String tag = '/MyApp';

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static StreamSubscription<AlarmSettings>? subscription;
  bool isCurrentlyOnNoInternet = false;
  final pinLockMillis = 2000;
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    init();
  }

  void init() async {
    //configuration for background task to execute used for generating local notification
    Permissions.checkAlarmPermissions();
    initPlatformState();
  }

// Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // START to check background event & notification schedule  data for testing  no need in future
    var prefs = await SharedPreferences.getInstance();
    var json = prefs.getString(EVENTS_KEY);
    if (json != null) {
      setState(() {
        backgroundEvents = jsonDecode(json).cast<String>();
      });
    }
    var json1 = prefs.getString(CHECK_SCHEDULE_DATA);
    if (json1 != null) {
      setState(() {
        scheduleRemindersData = jsonDecode(json1).cast<String>();
      });
    }
// END
    // Configure BackgroundFetch.
    try {
      // Schedule a "one-shot" custom-task in 10000ms.
      // These are fairly reliable on Android (particularly with forceAlarmManager) but not iOS,
      // where device must be powered (and delay will be throttled by the OS).
      BackgroundFetch.scheduleTask(TaskConfig(
          taskId: "com.transistorsoft.customtask",
          delay: 10000,
          periodic: false,
          forceAlarmManager: true,
          stopOnTerminate: false,
          enableHeadless: true));
    } on Exception {}

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  Future pausedState() async {
    setValue(
        KEY_LAST_KNOWN_APP_LIFECYCLE_STATE, AppLifecycleState.paused.index);
  }

  Future<void> inActiveState() async {
    final prevState = getIntAsync(KEY_LAST_KNOWN_APP_LIFECYCLE_STATE);
    final prevStateIsNotPaused =
        AppLifecycleState.values[prevState] != AppLifecycleState.paused;

    // Track the time when the app goes into the inactive state
    if (prevStateIsNotPaused) {
      setValue(KEY_APP_BACKGROUND_TIME, DateTime.now().millisecondsSinceEpoch);
    }

    // Update the last known app lifecycle state
    setValue(
        KEY_LAST_KNOWN_APP_LIFECYCLE_STATE, AppLifecycleState.inactive.index);
  }

  Future<void> _resumed() async {
    // Reset the background time tracking
    removeKey(KEY_APP_BACKGROUND_TIME);
    // Update the last known app lifecycle state
    setValue(
        KEY_LAST_KNOWN_APP_LIFECYCLE_STATE, AppLifecycleState.resumed.index);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        pausedState();
        break;
      case AppLifecycleState.resumed:
        _resumed();
        break;
      case AppLifecycleState.inactive:
        inActiveState();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return MaterialApp(
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: analytics),
        ],
        title: APP_NAME,
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        scrollBehavior: SBehavior(),
        theme: appStore.lightTheme,
        darkTheme: appStore.darkTheme,
        themeMode: ThemeMode.light,
        home: SplashScreen(),
        supportedLocales: getSupportedLocales(),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          CountryLocalizations.delegate,
          AppLocalizations(),
        ],
        localeResolutionCallback: (locale, supportedLocales) => locale,
        locale: Locale(
            appStore.selectedLanguage.validate(value: defaultLanguageCode)),
      );
    });
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
