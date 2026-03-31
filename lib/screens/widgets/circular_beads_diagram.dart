import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
// Models for direct use of Cycle info data
import '../../model/user/cycle_info_model.dart';
import '../../network/rest_api.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/extensions.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/period_date_validation.dart';
import '../../service/phone_verification_service.dart';
import '../../extensions/new_colors.dart';
import '../../languageConfiguration/LanguageDataConstant.dart';
import '../../languageConfiguration/LanguageDefaultJson.dart';
import '../payment/checkout.dart';
import 'period_dates_graph.dart';

class CircularBeadsDiagram extends StatefulWidget {
  const CircularBeadsDiagram({super.key});

  @override
  State<CircularBeadsDiagram> createState() => _CircularBeadsDiagramState();
}

class _CircularBeadsDiagramState extends State<CircularBeadsDiagram> {
  static const int totalBeads = 32;
  // Increased diagram size to accommodate larger radius and ensure beads don't touch
  static const double diagramSize = 360;
  static const double beadSize = 28;
  // Increased radius to space out beads, ensuring they don't touch and have an outer margin
  static const double radius = 165;

  /// Get phone number from multiple sources with fallback (synchronous only)
  /// Tries: userStore.user?.phoneNumber -> SharedPreferences KEY_PHONE_NUMBER
  /// Returns null if no phone number is found
  /// Note: Cannot use getUserFromLocalStorage() here as it's async
  String? _getPhoneNumber() {
    // Try userStore first
    String? phoneNumber = userStore.user?.phoneNumber;
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    
    // Fallback to SharedPreferences (synchronous)
    try {
      String phoneFromPrefs = getStringAsync(KEY_PHONE_NUMBER);
      if (phoneFromPrefs.isNotEmpty) {
        String cleaned = phoneFromPrefs.replaceAll(RegExp(r'[^\d]'), '');
        if (cleaned.isNotEmpty) {
          return cleaned;
        }
      }
    } catch (e) {
      print('Error getting phone from SharedPreferences: $e');
    }
    
    return null;
  }

  /// Load cycle info using phone number with fallback
  CycleInfoModel? _loadCycleInfoWithFallback() {
    CycleInfoModel? cycleInfo = userStore.cycleInfo;
    
    // If not in userStore, try loading from phone-specific SharedPreferences
    if (cycleInfo == null) {
      String? phoneForAPI = _getPhoneNumber();
      if (phoneForAPI != null && phoneForAPI.isNotEmpty) {
        try {
          cycleInfo = loadCycleInfoForPhone(phoneForAPI);
          // Load into userStore for future use
          if (cycleInfo != null) {
            userStore.setCycleInfo(cycleInfo, isInitialization: true);
          }
        } catch (e) {
          print('Error loading cycle info for phone $phoneForAPI: $e');
        }
      } else {
        print('⚠️ Cannot load cycle info: phone number not available');
      }
    }
    
    return cycleInfo;
  }

  Color getBeadColor(int number) {
    if (number == 1) return Colors.red;
    if (number == 27) return Colors.brown;
    if ((number >= 2 && number <= 8) || (number >= 23 && number <= 32)) {
      return Colors.orange;
    }
    return Colors.white;
  }

  /// Display diagram message based on period date
  /// Returns a Button widget if period date is > 32 days ago, otherwise returns Text widget with menstrual cycle state
  Widget displayDiagramMessage(String? dateRegle) {
    // Show "submit date" button when period date is missing or expired (> 32 days)
    // so user can submit period date directly from home without going to payment
    final bool showSubmitDateButton = _shouldShowSubmitPeriodDateButton(dateRegle);
    if (showSubmitDateButton) {
      return ElevatedButton(
        onPressed: () {
          _handleActivateCollier();
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          language.activateYourCollier,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    if (dateRegle == null || dateRegle.isEmpty) {
      return Text(
        language.periodDateNotAvailable,
        style: const TextStyle(fontSize: 16),
      );
    }

    try {
      // Parse dateRegle (format: "dd-MM-yyyy" or "yyyy-MM-dd")
      DateTime? periodDate;
      if (dateRegle.contains('-')) {
        List<String> parts = dateRegle.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 2) {
            periodDate = DateTime.parse('${parts[2]}-${parts[1]}-${parts[0]}');
          } else {
            periodDate = DateTime.parse(dateRegle);
          }
        }
      } else {
        periodDate = DateTime.parse(dateRegle);
      }

      if (periodDate == null) {
        return Text(
          language.invalidDate,
          style: const TextStyle(fontSize: 16),
        );
      }

      // Otherwise, show menstrual cycle state message
      String message = menstrualCycleState(dateRegle);
      return Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    } catch (e) {
      print('Error in displayDiagramMessage: $e');
      return Text(
        language.calculationError,
        style: const TextStyle(fontSize: 16),
      );
    }
  }

  /// True when user should see the "Activez votre collier" button to submit period date from home:
  /// - period date never submitted (null/empty), or
  /// - period date is more than 32 days ago
  bool _shouldShowSubmitPeriodDateButton(String? dateRegle) {
    if (dateRegle == null || dateRegle.isEmpty) return true;
    return isPeriodDateInvalid();
  }

  /// Get border decoration for selected bead (today's bead)
  /// Returns a 2px black border if the bead number matches today's bead number
  BoxBorder? selectedBead(int number) {
    int todayBead = getTodayBeadNumber();
    // Handle case where todayBead > 32 by using modulo (wraps around)
    int normalizedTodayBead = todayBead > 0 ? ((todayBead - 1) % totalBeads) + 1 : 0;
    bool isSelected = number == normalizedTodayBead && normalizedTodayBead > 0;
    
    if (isSelected) {
      print('✅ Bead $number is selected (today bead: $todayBead, normalized: $normalizedTodayBead) - adding border');
      return Border.all(color: Colors.black, width: 3); // Increased to 3px for better visibility
    }
    return null;
  }

  /// Calculate menstrual cycle state based on period date
  /// Formula: todayBead = (today date - dateRegle) + 1
  /// Returns pregnancy risk level based on cycle day
  String menstrualCycleState(String? dateRegle) {
    if (dateRegle == null || dateRegle.isEmpty) {
      return language.periodDateNotAvailable;
    }
    
    try {
      // Parse dateRegle (format: "dd-MM-yyyy" or "yyyy-MM-dd")
      DateTime? periodDate;
      
      if (dateRegle.contains('-')) {
        List<String> parts = dateRegle.split('-');
        if (parts.length == 3) {
          // Try dd-MM-yyyy first
          if (parts[0].length == 2) {
            periodDate = DateTime.parse('${parts[2]}-${parts[1]}-${parts[0]}');
          } else {
            // yyyy-MM-dd format
            periodDate = DateTime.parse(dateRegle);
          }
        }
      } else {
        // Try parsing as-is
        periodDate = DateTime.parse(dateRegle);
      }
      
      if (periodDate == null) {
        return language.invalidDate;
      }
      
      // Get today's date (start of day for accurate calculation)
      DateTime today = DateTime.now();
      DateTime todayStart = DateTime(today.year, today.month, today.day);
      DateTime periodStart = DateTime(periodDate.year, periodDate.month, periodDate.day);
      
      // Calculate difference in days
      int daysDifference = todayStart.difference(periodStart).inDays;
      
      // Apply formula: (today date - dateRegle) + 1
      int todayBead = daysDifference + 1;
      
      // Check pregnancy risk based on cycle day
      // Days 9-22 are typically the fertile window (higher pregnancy risk)
      if (todayBead < 9 || todayBead > 22) {
        return language.lowPregnancyRisk;
      } else if (todayBead >= 9 && todayBead <= 22) {
        return language.highPregnancyRisk;
      } else {
        return language.lowPregnancyRisk;
      }
    } catch (e) {
      print('Error calculating menstrual cycle state: $e');
      return language.calculationError;
    }
  }

  /// Get current date and day name formatted
  /// Returns a formatted string with day name and date
  String getCurrentDateAndDay() {
    final now = DateTime.now();
    // Get current language locale for date formatting
    final locale = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
    // Format: "Day Name, DD/MM/YYYY" (e.g., "Monday, 15/01/2024" or "Lundi, 15/01/2024")
    return DateFormat('EEEE, dd/MM/yyyy', locale).format(now);
  }

  /// Check if period date is missing or expired (> 32 days ago)
  /// Returns true if period date should be considered invalid
  bool isPeriodDateInvalid() {
    CycleInfoModel? cycleInfo = _loadCycleInfoWithFallback();
    
    // If no cycle info or dateRegle is missing/empty, consider it invalid
    if (cycleInfo == null || cycleInfo.dateRegle == null || cycleInfo.dateRegle!.isEmpty) {
      return true;
    }
    
    try {
      // Parse dateRegle
      DateTime? periodDate;
      String dateRegle = cycleInfo.dateRegle!;
      
      if (dateRegle.contains('-')) {
        List<String> parts = dateRegle.split('-');
        if (parts.length == 3) {
          // Try dd-MM-yyyy first
          if (parts[0].length == 2) {
            periodDate = DateTime.parse('${parts[2]}-${parts[1]}-${parts[0]}');
          } else {
            // yyyy-MM-dd format
            periodDate = DateTime.parse(dateRegle);
          }
        }
      } else {
        // Try parsing as-is
        periodDate = DateTime.parse(dateRegle);
      }
      
      if (periodDate == null) {
        return true;
      }
      
      // Get today's date (start of day for accurate calculation)
      DateTime today = DateTime.now();
      DateTime todayStart = DateTime(today.year, today.month, today.day);
      DateTime periodStart = DateTime(periodDate.year, periodDate.month, periodDate.day);
      
      // Calculate difference in days
      int daysDifference = todayStart.difference(periodStart).inDays;
      
      // If period date is more than 32 days ago, it's expired
      if (daysDifference > 32) {
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking period date validity: $e');
      return true; // Consider invalid on error
    }
  }

  /// Calculate today's bead number based on cycle info dateRegle
  /// Formula: (present day - cycleinfo dateRegle) + 1
  /// Returns an integer >= 0 (can be > 32, will be managed later)
  int getTodayBeadNumber() {
    CycleInfoModel? cycleInfo = _loadCycleInfoWithFallback();
    
    // If no cycle info, return 0
    if (cycleInfo == null || cycleInfo.dateRegle == null || cycleInfo.dateRegle!.isEmpty) {
      return 0;
    }
    
    try {
      // Parse dateRegle (format: "dd-MM-yyyy" or "yyyy-MM-dd")
      DateTime? periodDate;
      String dateRegle = cycleInfo.dateRegle!;
      
      if (dateRegle.contains('-')) {
        List<String> parts = dateRegle.split('-');
        if (parts.length == 3) {
          // Try dd-MM-yyyy first
          if (parts[0].length == 2) {
            periodDate = DateTime.parse('${parts[2]}-${parts[1]}-${parts[0]}');
          } else {
            // yyyy-MM-dd format
            periodDate = DateTime.parse(dateRegle);
          }
        }
      } else {
        // Try parsing as-is
        periodDate = DateTime.parse(dateRegle);
      }
      
      if (periodDate == null) {
        return 0;
      }
      
      // Get today's date (start of day for accurate calculation)
      DateTime today = DateTime.now();
      DateTime todayStart = DateTime(today.year, today.month, today.day);
      DateTime periodStart = DateTime(periodDate.year, periodDate.month, periodDate.day);
      
      // Calculate difference in days
      int daysDifference = todayStart.difference(periodStart).inDays;
      
      // Apply formula: (present day - cycleinfo dateRegle) + 1
      int beadNumber = daysDifference + 1;
      
      // Allow any positive number (including > 32)
      // Negative numbers (future dates) return 0
      if (beadNumber < 1) {
        return 0;
      }
      
      // Return the calculated bead number (can be > 32)
      return beadNumber;
    } catch (e) {
      print('Error calculating today bead number: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: diagramSize,
          height: diagramSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Central message - using displayDiagramMessage function
              Observer(
                builder: (_) {
                  CycleInfoModel? cycleInfo = _loadCycleInfoWithFallback();
                  
                  if (cycleInfo == null) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          getCurrentDateAndDay(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(language.loading,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    );
                  }
                  
                  // Show date/day and message/button
                  // Access appStore.selectedLanguage to ensure Observer tracks language changes
                  appStore.selectedLanguage;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        getCurrentDateAndDay(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                  // Use displayDiagramMessage to show appropriate message or button
                      displayDiagramMessage(cycleInfo.dateRegle),
                    ],
                  );
                },
              ),

              // Beads - Observer ensures beads rebuild when cycleInfo changes
              Observer(
                builder: (_) {
                  // Access cycleInfo to trigger reactive rebuild when it changes
                  CycleInfoModel? cycleInfo = _loadCycleInfoWithFallback();
                  
                  final todayBead = getTodayBeadNumber();
                  print('🔵 Rebuilding beads - Today bead: $todayBead, CycleInfo: ${cycleInfo?.dateRegle}');
                  
                  // Build all beads inside Observer so they rebuild when cycleInfo changes
                  return Stack(
                    children: [
                      for (int i = 0; i < totalBeads; i++) _buildBead(i + 1),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Legend/Key for bead colors - only show if period date is valid
        if (!isPeriodDateInvalid()) _buildLegend(),

        // Period dates graph - only show if period date is valid
        if (!isPeriodDateInvalid()) const PeriodDatesGraph(),

      ],
    );
  }

  /// Handle "Activez votre collier" button click.
  /// Redirect to Stripe checkout only if getPaymentStatusApi() returns 300 and country code is not 243.
  /// For DRC users (country code 243): show date picker → validate → confirm → API.
  Future<void> _handleActivateCollier() async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final String? phone = userStore.user?.phoneNumber ?? getStringAsync(KEY_PHONE_NUMBER);

    if (phone != null && phone.isNotEmpty && !isDRCCountryCode(phone)) {
      try {
        final status = await getPaymentStatusApi(phone);
        if (mounted && status.code == '300') {
          StripeCheckout().launch(context);
        }
      } catch (_) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('${language.errorLabel}: ${language.failedToLoadTransactions}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    try {
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

      final confirmed = await _showDateConfirmationDialog(picked);
      if (confirmed != true || !mounted) return;

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

      const bool q1 = true;
      const bool q2 = true;
      const bool q3 = false;

      final periodDate = DateFormat('yyyy-MM-dd').format(picked);
      final success = await PhoneVerificationService.createSubscriptionWithPeriodDate(
        phoneNumber: fullPhoneNumber,
        periodDate: periodDate,
        question1Answer: q1,
        question2Answer: q2,
        question3Answer: q3,
      );

      if (!mounted) return;

      if (success) {
        final phoneForAPI = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
        await userStore.setPeriodDate(periodDate);
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

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(language.periodDateSavedSuccess),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {});
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(language.failedToSavePeriodDatePleaseTryAgain),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  /// Show confirmation dialog for selected period date (same style as pay/onboarding).
  Future<bool?> _showDateConfirmationDialog(DateTime selectedDay) async {
    final locale = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
    final formattedDate = DateFormat('dd MMMM yyyy', locale).format(selectedDay);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
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
                  style: boldTextStyle(color: primaryColor, size: 16),
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
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                language.cancel,
                style: primaryTextStyle(color: Colors.grey, size: 14),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
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

  /// Parse date string to DateTime
  /// Supports formats: "dd-MM-yyyy" or "yyyy-MM-dd"
  DateTime? parseDate(String? dateString) {
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
      } else {
        // Try parsing as-is
        return DateTime.parse(dateString);
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return null;
  }

  /// Format DateTime to readable string (dd/MM/yyyy)
  String formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Calculate dates for legend items based on dateRegle
  Map<String, String> calculateLegendDates(String? dateRegle) {
    Map<String, String> dates = {
      'periodDate': '',
      'lowRiskStart1': '',
      'lowRiskEnd1': '',
      'highRiskStart': '',
      'highRiskEnd': '',
      'lowRiskStart2': '',
      'lowRiskEnd2': '',
      'nextPeriodDate': '',
    };

    if (dateRegle == null || dateRegle.isEmpty) {
      return dates;
    }

    DateTime? periodDate = parseDate(dateRegle);
    if (periodDate == null) {
      return dates;
    }

    // Format period date (bead 1)
    dates['periodDate'] = formatDate(periodDate);

    // Low risk period 1: beads 2-8 (days 2-8 from period start)
    dates['lowRiskStart1'] = formatDate(periodDate.add(const Duration(days: 1)));
    dates['lowRiskEnd1'] = formatDate(periodDate.add(const Duration(days: 7)));

    // High risk period: beads 9-22 (days 9-22 from period start)
    dates['highRiskStart'] = formatDate(periodDate.add(const Duration(days: 8)));
    dates['highRiskEnd'] = formatDate(periodDate.add(const Duration(days: 21)));

    // Low risk period 2: beads 23-32 (days 23-32 from period start)
    dates['lowRiskStart2'] = formatDate(periodDate.add(const Duration(days: 22)));
    dates['lowRiskEnd2'] = formatDate(periodDate.add(const Duration(days: 31)));

    // Next period date: bead 27 (day 27 from period start)
    dates['nextPeriodDate'] = formatDate(periodDate.add(const Duration(days: 26)));

    return dates;
  }

  /// Build legend/key explaining bead colors
  Widget _buildLegend() {
    return Observer(
      builder: (_) {
        CycleInfoModel? cycleInfo = _loadCycleInfoWithFallback();
        
        final dates = calculateLegendDates(cycleInfo?.dateRegle);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language.legendMenstrualCycle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
              _buildLegendItem(Colors.red, language.periodDateLabel, dates['periodDate']),
          const SizedBox(height: 8),
              _buildLegendItem(
                Colors.orange,
                language.lowRiskPeriod,
                (dates['lowRiskStart1']?.isNotEmpty == true && dates['lowRiskEnd1']?.isNotEmpty == true &&
                 dates['lowRiskStart2']?.isNotEmpty == true && dates['lowRiskEnd2']?.isNotEmpty == true)
                    ? '${dates['lowRiskStart1']} - ${dates['lowRiskEnd1']} / ${dates['lowRiskStart2']} - ${dates['lowRiskEnd2']}'
                    : '',
              ),
          const SizedBox(height: 8),
              _buildLegendItem(
                Colors.white,
                language.highRiskPeriod,
                (dates['highRiskStart']?.isNotEmpty == true && dates['highRiskEnd']?.isNotEmpty == true)
                    ? '${dates['highRiskStart']} - ${dates['highRiskEnd']}'
                    : '',
              ),
          const SizedBox(height: 8),
              _buildLegendItem(Colors.brown, language.nextPeriodDateLabel, dates['nextPeriodDate']),
          const SizedBox(height: 16),
          // Ring moves automatically text with circle icon
          Observer(
            builder: (_) {
              // Access appStore.selectedLanguage to ensure Observer tracks language changes
              appStore.selectedLanguage;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circle icon with shadow and 3px black border
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text
                  Expanded(
                    child: Text(
                      language.ringMovesAutomatically,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
            ],
          ),
        );
      },
    );
  }

  /// Build a single legend item with colored circle, text, and optional date
  Widget _buildLegendItem(Color color, String label, String? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey[400]!,
              width: color == Colors.white ? 1 : 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ),
          ],
        ),
        if (date != null && date.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBead(int number) {
    final angle = (2 * pi / totalBeads) * (number - 1) - pi / 2;
    final x = radius * cos(angle);
    final y = radius * sin(angle);

    // Check if period date is invalid (missing or expired)
    bool isInvalid = isPeriodDateInvalid();
    
    // Get border for selected bead (today's bead) - only if period date is valid
    BoxBorder? border = isInvalid ? null : selectedBead(number);

    return Positioned(
      left: diagramSize / 2 + x - beadSize / 2,
      top: diagramSize / 2 + y - beadSize / 2,
      child: Container(
        width: beadSize,
        height: beadSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isInvalid ? Colors.grey[300] : getBeadColor(number), // Light gray if invalid
          shape: BoxShape.circle,
          border: border, // No border if invalid
          boxShadow: isInvalid ? null : [ // No shadow if invalid
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            number.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

