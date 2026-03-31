import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:era_flutter/utils/app_common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../model/reminder_model.dart';
import '../model/user/cycle_info_model.dart';
import '../utils/app_constants.dart';

const REMINDER_MEDICINE_INDEX = 1;
const REMINDER_MEDITATION_INDEX = 2;
const REMINDER_DAILY_LOGGING_INDEX = 3;
const REMINDER_TRACKING_INDEX = 4;
const REMINDER_PERIOD_INDEX = 5;
const REMINDER_FERTILITY_INDEX = 6;
const REMINDER_OVULATION_INDEX = 7;
const REMINDER_SLEEP_INDEX = 8;
const REMINDER_DRINK_WATER_INDEX = 9;
const REMINDER_BODY_TEMPRATURE_INDEX = 10;
const REMINDER_LOG_WEIGHT_INDEX = 11;
// New indices for cycle stage notifications
const REMINDER_FERTILE_WINDOW_START_INDEX = 12;
const REMINDER_FERTILE_WINDOW_END_INDEX = 13;
const REMINDER_DAY_27_INDEX = 14;

const REMINDER_TYPE_DAILY = 1;
const REMINDER_TYPE_WEEKLY = 2;
const REMINDER_TYPE_MONTHLY = 3;

/// Helper function to get reminder title
Future<String> getReminderBody(ReminderModel reminder) async {
  String? savedMessage = await getReminderMessage(reminder.index!);
  if (savedMessage != null) {
    return savedMessage;
  }
  return "";
}

Future<String> getReminderTitleHeader(ReminderModel reminder) async {
  String? savedMessage = await getReminderTitle(reminder.index!);
  if (savedMessage != null) {
    return savedMessage;
  }
  return "";
}

//Helper function to schedule reminder for given index
Future<void> scheduleReminders({required int index}) async {
  List<ReminderModel> items =
      await getRemindersList(); // Wait for reminders to load

  // Find the reminder with the matching index
  ReminderModel? reminder = items.firstWhere(
    (item) => item.index == index,
    orElse: () => throw "no reminder found", // If not found, return null
  );

  // Cancel existing notification for this index before scheduling a new one
  await AwesomeNotifications().cancel(reminder.index!);

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: reminder.index!,
      channelKey: 'basic_channel',
      title: await getReminderTitleHeader(reminder),
      body: await getReminderBody(reminder),
      notificationLayout: NotificationLayout.Default,
    ),
    schedule: NotificationCalendar(
      hour: reminder.hours,
      minute: reminder.minutes,
      second: 0,
      month: reminder.month,
      year: reminder.year,
      day: reminder.day != null ? reminder.day : null,
      weekday: reminder.weekDay != null ? reminder.weekDay : null,
      repeats: true, // This makes it repeat automatically
    ),
  );
  printCurrentlyScheduledReminders();
}

// to check currently active reminders that will ring at given time
printCurrentlyScheduledReminders() async {
  List<NotificationModel> scheduledNotifications =
      await AwesomeNotifications().listScheduledNotifications();

  for (var notification in scheduledNotifications) {
    String? title = notification.content?.title;
    NotificationSchedule? schedule = notification.schedule;

    if (schedule is NotificationCalendar) {
      ('Line 86 Scheduled Notification: $title - Time: ${schedule.year}-${schedule.month}-${schedule.day} ${schedule.hour}:${schedule.minute}:${schedule.second}');
    } else {
      printEraAppLogs(
          'Line 88 Scheduled Notification: $title - No valid time found');
    }
  }
}

//return day name based on index
String getWeekdayName(int day) {
  return [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ][day];
}

// get list of reminders if not set intially will fetch all by default.
Future<List<ReminderModel>> getRemindersList() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Check if reminders already exist
  if (prefs.containsKey(KEY_REMINDER_DATA)) {
    String? remindersJson = prefs.getString(KEY_REMINDER_DATA);
    List<dynamic> jsonData = jsonDecode(remindersJson!);
    return jsonData.map((e) => ReminderModel.fromJson(e)).toList();
  }

  // If no data exists, use default list
  List<ReminderModel> reminderList = [
    ReminderModel(
        index: REMINDER_MEDITATION_INDEX,
        title: language.meditationReminders,
        subTitle: language.meditationRemindersText,
        isReminderOn: false,
        reminderType: REMINDER_TYPE_DAILY,
        hours: 0,
        minutes: 0,
        weekDay: null,
        day: null),
    ReminderModel(
        index: REMINDER_MEDICINE_INDEX,
        title: language.medicineReminders,
        subTitle: language.meditationRemindersText,
        isReminderOn: false,
        reminderType: REMINDER_TYPE_DAILY,
        hours: 0,
        minutes: 0,
        weekDay: null,
        day: null),
    ReminderModel(
        index: REMINDER_DAILY_LOGGING_INDEX,
        title: language.dailyLoggingReminders,
        subTitle: language.dailyLoggingRemindersText,
        isReminderOn: false,
        reminderType: REMINDER_TYPE_DAILY,
        hours: 00,
        minutes: null,
        weekDay: null),
    ReminderModel(
        index: REMINDER_TRACKING_INDEX,
        title: language.trackingReminders,
        subTitle: language.trackingRemindersText,
        isReminderOn: false,
        reminderType: REMINDER_TYPE_WEEKLY,
        hours: 00,
        minutes: 00,
        weekDay: null,
        day: null),
    new ReminderModel(
        index: REMINDER_PERIOD_INDEX,
        title: language.periodReminders,
        subTitle: language.periodRemindersText,
        isReminderOn: false,
        reminderType: REMINDER_TYPE_MONTHLY,
        hours: 00,
        minutes: 00,
        weekDay: null,
        day: null),
    ReminderModel(
        index: REMINDER_FERTILITY_INDEX,
        title: language.fertilityReminder,
        subTitle: language.fertilityReminderText,
        isReminderOn: false,
        reminderType: REMINDER_TYPE_MONTHLY,
        hours: 00,
        minutes: 00,
        weekDay: null,
        day: null),
    ReminderModel(
        index: REMINDER_OVULATION_INDEX,
        title: language.ovulationReminder,
        subTitle: language.ovulationReminderText,
        isReminderOn: false,
        reminderType: REMINDER_TYPE_MONTHLY,
        hours: 00,
        minutes: 00,
        weekDay: null,
        day: null),
    //todo add keys
    ReminderModel(
        index: REMINDER_SLEEP_INDEX,
        title: "Sleep Reminders",
        subTitle: "Track your sleep reminders",
        isReminderOn: false,
        reminderType: REMINDER_TYPE_DAILY,
        hours: 0,
        minutes: 0,
        weekDay: null,
        day: null),
    ReminderModel(
        index: REMINDER_DRINK_WATER_INDEX,
        title: "Drink water Reminders",
        subTitle: "Track your water intake",
        isReminderOn: false,
        reminderType: REMINDER_TYPE_DAILY,
        hours: 0,
        minutes: 0,
        weekDay: null,
        day: null),
    ReminderModel(
        index: REMINDER_LOG_WEIGHT_INDEX,
        title: "weight Reminders",
        subTitle: "Track your weight",
        isReminderOn: false,
        reminderType: REMINDER_TYPE_DAILY,
        hours: 0,
        minutes: 0,
        weekDay: null,
        day: null),
    ReminderModel(
        index: REMINDER_BODY_TEMPRATURE_INDEX,
        title: "Body temperature Reminders",
        subTitle: "Track your sleep reminders",
        isReminderOn: false,
        reminderType: REMINDER_TYPE_DAILY,
        hours: 0,
        minutes: 0,
        weekDay: null,
        day: null),
  ];

  // Save default reminders to SharedPreferences
  await prefs.setString(KEY_REMINDER_DATA,
      jsonEncode(reminderList.map((e) => e.toJson()).toList()));

  return reminderList;
}

// to update reminder date time and other data
Future<void> updateReminder({
  required int index,
  required int? day,
  required int? weekDay,
  required int? hours,
  required int? month,
  required int? year,
  required int? minutes,
  required bool isOn,
}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? remindersJson = prefs.getString(KEY_REMINDER_DATA);

  // Initialize reminders list
  List<ReminderModel> reminders = [];

  // If remindersJson is not null, decode it into a list of ReminderModel objects
  List<dynamic> jsonData = jsonDecode(remindersJson!);
  reminders = jsonData.map((e) => ReminderModel.fromJson(e)).toList();

  // Find the reminder with the specified index
  ReminderModel? foundReminder;
  for (var reminder in reminders) {
    if (reminder.index == index) {
      foundReminder = reminder;
      break;
    }
  }

  // If the reminder does not exist, create a new one
  if (foundReminder == null) {
    foundReminder = ReminderModel(
      index: index,
      day: day,
      weekDay: weekDay,
      hours: hours,
      minutes: minutes,
      month: month,
      year: year,
      isReminderOn: isOn,
      title: '',
    );
    reminders.add(foundReminder);
  } else {
    // If the reminder exists, update its properties
    foundReminder.day = day;
    foundReminder.weekDay = weekDay;
    foundReminder.hours = hours;
    foundReminder.minutes = minutes;
    foundReminder.month = month;
    foundReminder.year = year;
    foundReminder.isReminderOn = isOn;
  }

  // Save the updated list back to SharedPreferences
  await prefs.setString(
    KEY_REMINDER_DATA,
    jsonEncode(reminders.map((e) => e.toJson()).toList()),
  );
}

//get model object of particualr reminder for given index
Future<ReminderModel?> getReminderItem({required int? index}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? remindersJson = prefs.getString(KEY_REMINDER_DATA);

  List<dynamic> jsonData = jsonDecode(remindersJson!);
  List<ReminderModel> reminders =
      jsonData.map((e) => ReminderModel.fromJson(e)).toList();

  ReminderModel? foundReminder;

  for (var reminder in reminders) {
    if (reminder.index == index) {
      foundReminder = reminder; // Store the found reminder
      break; // Stop looping once found
    }
  }

  return foundReminder; // Return the found reminder or null if not found
}

//cancel awasome notification and update reminders to null as default value
Future<void> cancelReminder({required int index}) async {
  await AwesomeNotifications().cancel(index);
  //reset reminders to default null
  updateReminder(
      index: index,
      day: null,
      weekDay: null,
      hours: null,
      month: null,
      year: null,
      minutes: null,
      isOn: false);
}

//called from background fetch to reset reminders if set at given time but doesnt ring.
void rescheduleRemindersIfMissed() async {
//  Get list of currently scheduled notifications
  List<NotificationModel> scheduledNotifications =
      await AwesomeNotifications().listScheduledNotifications();

//  Extract IDs of already scheduled reminders
  Set<int> scheduledIds = scheduledNotifications
      .map((notification) => notification.content?.id)
      .whereType<int>()
      .toSet();

//  Fetch reminders list
  List<ReminderModel> reminderList = await getRemindersList();

  for (var reminder in reminderList) {
    if (!reminder.isReminderOn!) continue; // Skip if reminder is off

    int reminderId = reminder.index!; // Use index as unique ID

//  Check if this reminder is already scheduled
    if (scheduledIds.contains(reminderId)) {
      continue;
    }
//if not schedule then schedule it with same as normal process
    scheduleReminders(index: reminder.index!);
  }
}

//hrs & minutes to display in 2 digit format
String formatReminderTime(int? hours, int? minutes) {
  // Ensure hours and minutes are not null, otherwise default to 0
  hours ??= 0;
  minutes ??= 0;

  // Format hours and minutes to always have two digits
  String formattedHours = hours < 10 ? '0$hours' : '$hours';
  String formattedMinutes = minutes < 10 ? '0$minutes' : '$minutes';

  return '$formattedHours:$formattedMinutes';
}

//on user account logout or account deletion reset all pref value of remidners to null && cancel awasome notification
resetAllReminders() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? remindersJson = prefs.getString(KEY_REMINDER_DATA);

  List<dynamic> jsonData = jsonDecode(remindersJson!);
  List<ReminderModel> reminderList =
      jsonData.map((e) => ReminderModel.fromJson(e)).toList();
  for (var reminder in reminderList) {
    cancelReminder(index: reminder.index!);
    //reset value to null if its not from goal type if its from goal type ==1 only cancel reminder no need to clear data

    reminder.isReminderOn = false;
    reminder.reminderType = null;
    reminder.hours = null;
    reminder.minutes = null;
    reminder.weekDay = null;
    reminder.day = null;
    clearReminder(reminder.index!);
    //  Save updated list back to SharedPreferences
    String updatedJson =
        jsonEncode(reminderList.map((e) => e.toJson()).toList());
    await prefs.setString(KEY_REMINDER_DATA, updatedJson);
  }
}

//update reminder when date changes
updateRemindersForDateChange() async {
  updatePeriodReminderDate();
  updateOvualtionDateRemidner();
}

updateOvualtionDateRemidner() async {
  String predictedOvulationDate = await instance.getNextOvulationDate();
  DateTime nextOvulation = DateTime.parse(predictedOvulationDate);
  //ovulation reminder
  ReminderModel? ovulationReminder =
      await getReminderItem(index: REMINDER_OVULATION_INDEX);
  if (ovulationReminder != null) {
    if (ovulationReminder.hours != null && ovulationReminder.minutes != null) {
      int hrs = ovulationReminder.hours!;
      int min = ovulationReminder.minutes!;
      DateTime givenDate = DateTime(
          nextOvulation.year, nextOvulation.month, nextOvulation.day, hrs, min);
      if (isDatePassed(givenDate)) {
        if (ovulationReminder.isReminderOn != null &&
            ovulationReminder.isReminderOn!) {
          toast("Sorry this date is passed! reminder is skipped");
          cancelReminder(index: REMINDER_OVULATION_INDEX);
        } else {}
      } else {
        if (ovulationReminder.isReminderOn != null &&
            ovulationReminder.isReminderOn!) {
          updateReminder(
            index: REMINDER_OVULATION_INDEX,
            weekDay: null,
            month: nextOvulation.month,
            year: nextOvulation.year,
            hours: hrs,
            minutes: min,
            day: nextOvulation.day,
            isOn: true,
          ).whenComplete(() {
            scheduleReminders(index: REMINDER_OVULATION_INDEX);
          });
        }
      }
    }
  }
}

updatePeriodReminderDate() async {
  String predictedPeriodDate = await instance.getNextPredictedPeriodDate();
  DateTime nextPeriodDate = DateTime.parse(predictedPeriodDate);
  //period index reset
  ReminderModel? reminderItem =
      await getReminderItem(index: REMINDER_PERIOD_INDEX);
  if (reminderItem != null) {
    if (reminderItem.hours != null && reminderItem.minutes != null) {
      int hrs = reminderItem.hours!;
      int min = reminderItem.minutes!;
      DateTime givenDate = DateTime(nextPeriodDate.year, nextPeriodDate.month,
          nextPeriodDate.day, hrs, min);
      if (isDatePassed(givenDate)) {
        if (reminderItem.isReminderOn != null && reminderItem.isReminderOn!) {
          toast("Sorry this date is passed! you can not set reminder for this");
          cancelReminder(index: REMINDER_PERIOD_INDEX);
        } else {}
      } else {
        if (reminderItem.isReminderOn != null && reminderItem.isReminderOn!) {
          updateReminder(
            index: REMINDER_PERIOD_INDEX,
            weekDay: null,
            month: nextPeriodDate.month,
            year: nextPeriodDate.year,
            hours: hrs,
            // Keeping the same hours
            minutes: min,
            // Keeping the same minutes
            day: nextPeriodDate.day,
            isOn: true,
          ).whenComplete(() {
            scheduleReminders(index: REMINDER_PERIOD_INDEX);
          });
        }
      }
    }
  }
}

bool isDatePassed(DateTime date) {
  DateTime now = DateTime.now().add(Duration(minutes: 5));
  return date.isBefore(now);
}

Future<void> setReminderMessage(int index, String message) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('reminder_msg_$index', message);
}

Future<void> setReminderTitle(int index, String title) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('reminder_msg_title_$index', title);
}

Future<String?> getReminderMessage(int index) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('reminder_msg_$index');
}

Future<String?> getReminderTitle(int index) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('reminder_msg_title_$index');
}

Future<void> clearReminder(int index) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('reminder_msg_$index');
}

/// Parse date string to DateTime
/// Supports both "yyyy-MM-dd" and "dd-MM-yyyy" formats
DateTime? _parseDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) {
    return null;
  }
  
  try {
    if (dateString.contains('-')) {
      List<String> parts = dateString.split('-');
      if (parts.length == 3) {
        // Try dd-MM-yyyy first
        if (parts[0].length == 2) {
          return DateTime.parse('${parts[2]}-${parts[1]}-${parts[0]}');
        } else {
          // yyyy-MM-dd format
          return DateTime.parse(dateString);
        }
      }
    }
    // Try parsing as-is
    return DateTime.parse(dateString);
  } catch (e) {
    print('Error parsing date: $dateString - $e');
    return null;
  }
}

/// Schedule notification for a specific date and time
/// This creates a one-time notification (does not repeat)
Future<void> scheduleCycleStageNotification({
  required int notificationId,
  required DateTime notificationDate,
  required String title,
  required String body,
}) async {
  try {
    // Cancel any existing notification with this ID
    await AwesomeNotifications().cancel(notificationId);
    
    // Check if date has passed
    if (isDatePassed(notificationDate)) {
      print('⚠️ Notification date has passed: $notificationDate');
      return;
    }
    
    // Schedule the notification
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: notificationDate.year,
        month: notificationDate.month,
        day: notificationDate.day,
        hour: notificationDate.hour,
        minute: notificationDate.minute,
        second: 0,
        repeats: false, // One-time notification
      ),
    );
    
    print('✅ Scheduled notification: $title on ${notificationDate.toString()}');
  } catch (e) {
    print('❌ Error scheduling notification: $e');
  }
}

/// Schedule notifications for key menstrual cycle stages
/// This should be called when cycle info is updated
Future<void> scheduleCycleStageNotifications() async {
  try {
    // Get cycle info from userStore
    CycleInfoModel? cycleInfo = userStore.cycleInfo;
    
    if (cycleInfo == null) {
      print('⚠️ Cannot schedule cycle notifications: cycle info is null');
      return;
    }
    
    // Default notification time (9:00 AM)
    const defaultHour = 9;
    const defaultMinute = 0;
    
    // 1. Schedule notification for fertile window start
    if (cycleInfo.dateFertiStart != null && cycleInfo.dateFertiStart!.isNotEmpty) {
      DateTime? fertileStart = _parseDate(cycleInfo.dateFertiStart);
      if (fertileStart != null) {
        DateTime notificationDate = DateTime(
          fertileStart.year,
          fertileStart.month,
          fertileStart.day,
          defaultHour,
          defaultMinute,
        );
        
        await scheduleCycleStageNotification(
          notificationId: REMINDER_FERTILE_WINDOW_START_INDEX,
          notificationDate: notificationDate,
          title: language.fertileWindowStart,
          body: language.fertileWindowStartBody,
        );
      }
    }
    
    // 2. Schedule notification for fertile window end
    if (cycleInfo.dateFertireqEnd != null && cycleInfo.dateFertireqEnd!.isNotEmpty) {
      DateTime? fertileEnd = _parseDate(cycleInfo.dateFertireqEnd);
      if (fertileEnd != null) {
        DateTime notificationDate = DateTime(
          fertileEnd.year,
          fertileEnd.month,
          fertileEnd.day,
          defaultHour,
          defaultMinute,
        );
        
        await scheduleCycleStageNotification(
          notificationId: REMINDER_FERTILE_WINDOW_END_INDEX,
          notificationDate: notificationDate,
          title: language.fertileWindowEnd,
          body: language.fertileWindowEndBody,
        );
      }
    }
    
    // 3. Schedule notification for day 27 (next period expected)
    if (cycleInfo.dateRegle != null && cycleInfo.dateRegle!.isNotEmpty) {
      DateTime? periodStart = _parseDate(cycleInfo.dateRegle);
      if (periodStart != null) {
        // Day 27 = periodStart + 26 days (0-indexed)
        DateTime day27 = periodStart.add(const Duration(days: 26));
        DateTime notificationDate = DateTime(
          day27.year,
          day27.month,
          day27.day,
          defaultHour,
          defaultMinute,
        );
        
        await scheduleCycleStageNotification(
          notificationId: REMINDER_DAY_27_INDEX,
          notificationDate: notificationDate,
          title: language.nextPeriodExpected,
          body: language.nextPeriodExpectedBody,
        );
      }
    }
    
    print('✅ All cycle stage notifications scheduled successfully');
  } catch (e) {
    print('❌ Error scheduling cycle stage notifications: $e');
  }
}

/// Get all scheduled notifications with formatted information
/// Returns a list of maps containing notification details
Future<List<Map<String, dynamic>>> getAllScheduledNotifications() async {
  try {
    List<NotificationModel> scheduledNotifications =
        await AwesomeNotifications().listScheduledNotifications();
    
    List<Map<String, dynamic>> notificationsList = [];
    
    for (var notification in scheduledNotifications) {
      String? title = notification.content?.title ?? 'Sans titre';
      String? body = notification.content?.body ?? '';
      int? id = notification.content?.id;
      NotificationSchedule? schedule = notification.schedule;
      
      String scheduleInfo = 'Non programmée';
      DateTime? scheduledDate;
      
      if (schedule is NotificationCalendar) {
        int year = schedule.year ?? DateTime.now().year;
        int month = schedule.month ?? DateTime.now().month;
        int day = schedule.day ?? DateTime.now().day;
        int hour = schedule.hour ?? 0;
        int minute = schedule.minute ?? 0;
        
        scheduledDate = DateTime(year, month, day, hour, minute);
        
        String dateStr = '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';
        String timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        
        bool isRepeating = schedule.repeats;
        scheduleInfo = '$dateStr à $timeStr${isRepeating ? ' (répétitive)' : ''}';
      }
      
      bool isRepeating = false;
      if (schedule is NotificationCalendar) {
        isRepeating = schedule.repeats;
      }
      
      notificationsList.add({
        'id': id,
        'title': title,
        'body': body,
        'schedule': scheduleInfo,
        'scheduledDate': scheduledDate,
        'isRepeating': isRepeating,
      });
    }
    
    // Sort by scheduled date (earliest first)
    notificationsList.sort((a, b) {
      DateTime? dateA = a['scheduledDate'] as DateTime?;
      DateTime? dateB = b['scheduledDate'] as DateTime?;
      
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });
    
    return notificationsList;
  } catch (e) {
    print('❌ Error getting scheduled notifications: $e');
    return [];
  }
}
