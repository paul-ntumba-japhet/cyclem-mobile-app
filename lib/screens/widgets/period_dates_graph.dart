import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../main.dart';
import '../../model/user/user_transaction_model.dart';
import '../../network/rest_api.dart';
import '../../extensions/shared_pref.dart';
import '../../utils/app_constants.dart';

/// Data model for chart
class PeriodChartData {
  final String month; // Month label for x-axis (e.g., "Jan 2026")
  final int day; // Day of month for y-axis (1-31)
  final int count;
  final DateTime date; // Full date for sorting

  PeriodChartData({
    required this.month,
    required this.day,
    required this.count,
    required this.date,
  });
}

class PeriodDatesGraph extends StatefulWidget {
  const PeriodDatesGraph({super.key});

  @override
  State<PeriodDatesGraph> createState() => _PeriodDatesGraphState();
}

class _PeriodDatesGraphState extends State<PeriodDatesGraph> {
  bool _isLoading = false;
  String? _errorMessage;
  List<PeriodChartData> _chartData = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  /// Get phone number from multiple sources with fallback (synchronous only)
  /// Tries: userStore.user?.phoneNumber -> SharedPreferences KEY_PHONE_NUMBER
  /// Returns null if no phone number is found
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
      print('Error getting phone from SharedPreferences in PeriodDatesGraph: $e');
    }
    
    return null;
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get phone number with fallback
      String? phoneNumber = _getPhoneNumber();
      if (phoneNumber == null || phoneNumber.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = language.phoneNumberNotAvailable;
        });
        print('⚠️ PeriodDatesGraph: Cannot fetch transactions - phone number not available');
        return;
      }

      print('📊 PeriodDatesGraph: Fetching transactions for phone: $phoneNumber');
      // Call the API to get transactions (codeRecu contains menstrual dates)
      List<UserTransaction> transactions = await getUserTransactionsApi(phoneNumber);
      
      print('📊 PeriodDatesGraph: Fetched ${transactions.length} transactions');
      // Filter transactions that have codeRecu (menstrual dates)
      List<UserTransaction> transactionsWithDates = transactions
          .where((t) => t.codeRecu.isNotEmpty)
          .toList();
      print('📊 PeriodDatesGraph: ${transactionsWithDates.length} transactions with codeRecu (menstrual dates)');

      setState(() {
        _isLoading = false;
        _chartData = _processTransactionData(transactions);
        print('📊 PeriodDatesGraph: Processed ${_chartData.length} months of data');
      });
    } catch (e) {
      print('Error fetching transactions: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = language.failedToLoadTransactions;
      });
    }
  }

  /// Extract codeRecu values from transactions and process them
  /// codeRecu corresponds to dateRegle (menstrual dates sent by user)
  /// X-axis: Months (bands), Y-axis: Days (1-35), Points at intersections
  List<PeriodChartData> _processTransactionData(List<UserTransaction> transactions) {
    // Extract codeRecu values (menstrual dates - dateRegle)
    List<String> periodDates = [];
    for (var transaction in transactions) {
      if (transaction.codeRecu.isNotEmpty) {
        periodDates.add(transaction.codeRecu);
      }
    }

    if (periodDates.isEmpty) {
      return [];
    }

    // Process each codeRecu date: extract day (y-axis) and month-year (x-axis)
    List<PeriodChartData> chartData = [];

    for (var dateStr in periodDates) {
      try {
        // Parse date (format: "dd-MM-yyyy" or "06-01-2026")
        DateTime? date;
        if (dateStr.contains('-')) {
          List<String> parts = dateStr.split('-');
          if (parts.length == 3) {
            // Try dd-MM-yyyy format first (most common)
            if (parts[0].length == 2) {
              // dd-MM-yyyy format
              int? day = int.tryParse(parts[0]);
              int? month = int.tryParse(parts[1]);
              int? year = int.tryParse(parts[2]);
              
              if (day != null && month != null && year != null && 
                  day >= 1 && day <= 31 && month >= 1 && month <= 12) {
                date = DateTime(year, month, day);
              } else {
                // Fallback to parsing
                date = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
              }
            } else {
              // Try other formats
              date = DateTime.tryParse(dateStr);
            }
          }
        } else {
          date = DateTime.tryParse(dateStr);
        }

        if (date != null && date.year >= 1900 && date.year <= 2100) {
          // X-axis: Month-year label (e.g., "Jan 2026")
          String monthLabel = DateFormat('MMM yyyy', 'fr_FR').format(date);
          
          // Y-axis: Day of month (1-31, can extend to 35 for display)
          int dayOfMonth = date.day;
          
          chartData.add(PeriodChartData(
            month: monthLabel, // X-axis: Month band
            day: dayOfMonth, // Y-axis: Day number (1-35)
            count: 1,
            date: DateTime(date.year, date.month, date.day),
          ));
          
          print('📊 Added period date: $dateStr -> Month: $monthLabel, Day: $dayOfMonth');
        } else {
          print('⚠️ Invalid date parsed from codeRecu: $dateStr -> $date');
        }
      } catch (e) {
        print('❌ Error parsing date $dateStr: $e');
      }
    }

    // Count duplicates (same date sent multiple times) - but for polygon, we might want all points
    // For now, keep unique dates only with count for future use
    Map<String, PeriodChartData> uniqueDates = {};
    for (var data in chartData) {
      String dateKey = data.date.toString().split(' ')[0]; // Use date as key (YYYY-MM-DD)
      if (!uniqueDates.containsKey(dateKey)) {
        uniqueDates[dateKey] = data;
      }
    }

    // Convert back to list and sort chronologically
    List<PeriodChartData> finalChartData = uniqueDates.values.toList();
    finalChartData.sort((a, b) => a.date.compareTo(b.date));

    print('📊 Processed ${finalChartData.length} unique menstrual dates for polygon chart');
    return finalChartData;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 32),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_chartData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            language.noPeriodDataAvailable,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      );
    }

    return Observer(
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.periodDatesSent,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _fetchTransactions,
                    tooltip: language.refreshTooltip,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 280,
                child: SfCartesianChart(
                  plotAreaBackgroundColor: Colors.transparent,
                  primaryXAxis: CategoryAxis(
                    title: AxisTitle(
                      text: 'Mois',
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    labelRotation: -45,
                    labelStyle: const TextStyle(fontSize: 10),
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(
                      text: language.dayLabel,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    minimum: 1,
                    maximum: 36,
                    interval: 1,
                    labelStyle: const TextStyle(fontSize: 10),
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x : jour point.y',
                    color: Colors.pink[400],
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  series: <CartesianSeries>[
                    LineSeries<PeriodChartData, String>(
                      dataSource: _chartData,
                      xValueMapper: (PeriodChartData data, _) => data.month,
                      yValueMapper: (PeriodChartData data, _) => data.day,
                      name: language.periodDatesSent,
                      color: Colors.pink[400],
                      width: 2,
                      markerSettings: const MarkerSettings(
                        isVisible: true,
                        height: 8,
                        width: 8,
                        shape: DataMarkerType.circle,
                        borderColor: Colors.pink,
                        borderWidth: 1,
                      ),
                      animationDuration: 1000,
                      enableTooltip: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

