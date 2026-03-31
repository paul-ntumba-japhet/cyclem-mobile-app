import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../model/user/cycle_info_model.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/dynamic_theme.dart';

class MenstrualCalendarScreen extends StatefulWidget {
  const MenstrualCalendarScreen({super.key});

  @override
  State<MenstrualCalendarScreen> createState() => _MenstrualCalendarScreenState();
}

class _MenstrualCalendarScreenState extends State<MenstrualCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDate;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    logScreenView("Menstrual Calendar screen");
    
    // Debug: Print cycle info on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cycleInfo = _getCycleInfo();
      if (cycleInfo != null) {
        print('📋 Cycle Info loaded:');
        print('   dateRegle: ${cycleInfo.dateRegle}');
        print('   dateFertiStart: ${cycleInfo.dateFertiStart}');
        print('   dateFertireqEnd: ${cycleInfo.dateFertireqEnd}');
        print('   dateProchaineReglesStart: ${cycleInfo.dateProchaineReglesStart}');
        print('   dateProchaineReglesEnd: ${cycleInfo.dateProchaineReglesEnd}');
        
        // Test parsing
        DateTime? testFirstDay = _parseDate(cycleInfo.dateRegle);
        if (testFirstDay != null) {
          print('   ✅ dateRegle parsed: ${testFirstDay.toString().split(' ')[0]}');
        } else {
          print('   ❌ dateRegle failed to parse: ${cycleInfo.dateRegle}');
        }
      } else {
        print('⚠️ Cycle Info is null');
      }
    });
  }

  /// Load cycle info from SharedPreferences if not in userStore
  CycleInfoModel? _getCycleInfo() {
    CycleInfoModel? cycleInfo = userStore.cycleInfo;
    
    // Fallback to SharedPreferences if not in userStore
    if (cycleInfo == null) {
      try {
        Map<String, dynamic> cycleInfoJson = getJSONAsync(KEY_CYCLE_INFO);
        if (cycleInfoJson.isNotEmpty) {
          cycleInfo = CycleInfoModel.fromJson(cycleInfoJson);
          // Load into userStore for future use
          userStore.setCycleInfo(cycleInfo, isInitialization: true);
        }
      } catch (e) {
        print('Error loading cycle info from SharedPreferences: $e');
      }
    }
    
    return cycleInfo;
  }

  /// Parse date string to DateTime and normalize to start of day
  DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      DateTime? parsedDate;
      
      // Try different date formats in order of likelihood
      // Start with dd-MM-yyyy and dd/MM/yyyy first (most common in this app)
      List<String> formats = [
        'dd-MM-yyyy',      // 31-01-2026
        'dd/MM/yyyy',      // 31/01/2026
        'MM-dd-yyyy',      // 01-31-2026
        'MM/dd/yyyy',      // 01/31/2026
        'yyyy-MM-dd',      // 2026-01-31
        'yyyy/MM/dd',      // 2026/01/31
      ];
      
      for (String format in formats) {
        try {
          parsedDate = DateFormat(format).parse(dateString);
          
          // Validate the parsed date makes sense
          // Check if year is reasonable (between 1900 and 2100)
          if (parsedDate.year < 1900 || parsedDate.year > 2100) {
            print('⚠️ Parsed date has invalid year: ${parsedDate.year}, trying next format...');
            parsedDate = null;
            continue;
          }
          
          // Check if month is valid (1-12)
          if (parsedDate.month < 1 || parsedDate.month > 12) {
            print('⚠️ Parsed date has invalid month: ${parsedDate.month}, trying next format...');
            parsedDate = null;
            continue;
          }
          
          // Check if day is valid for the month
          if (parsedDate.day < 1 || parsedDate.day > 31) {
            print('⚠️ Parsed date has invalid day: ${parsedDate.day}, trying next format...');
            parsedDate = null;
            continue;
          }
          
          print('✅ Successfully parsed date: $dateString with format: $format -> ${parsedDate.toString().split(' ')[0]}');
          break;
        } catch (e) {
          continue;
        }
      }
      
      // Try parsing as ISO format if other formats failed
      if (parsedDate == null) {
        try {
          parsedDate = DateTime.parse(dateString);
          
          // Validate ISO parsed date
          if (parsedDate.year < 1900 || parsedDate.year > 2100) {
            print('⚠️ ISO parsed date has invalid year: ${parsedDate.year}');
            parsedDate = null;
          } else {
            print('✅ Successfully parsed date: $dateString with DateTime.parse -> ${parsedDate.toString().split(' ')[0]}');
          }
        } catch (e) {
          print('❌ Failed to parse date: $dateString - $e');
        }
      }
      
      // Normalize to start of day (remove time component)
      if (parsedDate != null) {
        DateTime normalized = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        return normalized;
      }
      
      print('❌ Could not parse date: $dateString with any format');
      return null;
    } catch (e) {
      print('❌ Error parsing date: $dateString - $e');
      return null;
    }
  }

  /// Normalize DateTime to start of day for comparison
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get all fertile period dates based on cycle info
  List<DateTime> _getFertilePeriodDates(CycleInfoModel cycleInfo) {
    List<DateTime> fertileDates = [];
    
    DateTime? fertileStart = _parseDate(cycleInfo.dateFertiStart);
    DateTime? fertileEnd = _parseDate(cycleInfo.dateFertireqEnd);
    
    if (fertileStart != null && fertileEnd != null) {
      DateTime current = fertileStart;
      while (current.isBefore(fertileEnd) || current.isAtSameMomentAs(fertileEnd)) {
        fertileDates.add(_normalizeDate(current));
        current = current.add(const Duration(days: 1));
      }
    } else if (fertileStart != null) {
      // If only start date, assume 6 days (typical fertile window)
      for (int i = 0; i < 6; i++) {
        DateTime fertileDay = fertileStart.add(Duration(days: i));
        fertileDates.add(_normalizeDate(fertileDay));
      }
    }
    
    return fertileDates;
  }

  /// Check if a date is a fertile period date
  bool _isFertileDate(DateTime date, CycleInfoModel cycleInfo) {
    DateTime normalizedDate = _normalizeDate(date);
    List<DateTime> fertileDates = _getFertilePeriodDates(cycleInfo);
    return fertileDates.any((fertileDate) {
      DateTime normalizedFertile = _normalizeDate(fertileDate);
      return normalizedDate.isAtSameMomentAs(normalizedFertile);
    });
  }

  /// Check if a date is the first day of menstruation
  bool _isFirstDayOfMenstruation(DateTime date, CycleInfoModel cycleInfo) {
    DateTime? firstDay = _parseDate(cycleInfo.dateRegle);
    if (firstDay == null) return false;
    
    DateTime normalizedDate = _normalizeDate(date);
    DateTime normalizedFirst = _normalizeDate(firstDay);
    
    return normalizedDate.isAtSameMomentAs(normalizedFirst);
  }

  /// Check if a date is the 27th day from menstruation
  bool _is27thDayFromMenstruation(DateTime date, CycleInfoModel cycleInfo) {
    DateTime? firstDay = _parseDate(cycleInfo.dateRegle);
    if (firstDay == null) return false;
    
    DateTime day27 = firstDay.add(const Duration(days: 26)); // 27th day (0-indexed, so +26)
    DateTime normalizedDate = _normalizeDate(date);
    DateTime normalizedDay27 = _normalizeDate(day27);
    
    return normalizedDate.isAtSameMomentAs(normalizedDay27);
  }

  /// Check if a date should be orange (remaining days within cycle range)
  /// Orange is for all days that are not: fertile (white), first day (red), or 27th day (brown)
  /// All remaining days within cycle range (0-35 days from first day) are orange
  bool _isOrangeDate(DateTime date, CycleInfoModel cycleInfo) {
    DateTime? firstDay = _parseDate(cycleInfo.dateRegle);
    if (firstDay == null) return false;
    
    DateTime normalizedDate = _normalizeDate(date);
    DateTime normalizedFirst = _normalizeDate(firstDay);
    
    // Don't mark as orange if it's a fertile day (white), first day (red), or 27th day (brown)
    if (_isFertileDate(date, cycleInfo) ||
        _isFirstDayOfMenstruation(date, cycleInfo) ||
        _is27thDayFromMenstruation(date, cycleInfo)) {
      return false;
    }
    
    // Only mark as orange if the date is within a reasonable cycle range (0-35 days from first day)
    int daysDifference = normalizedDate.difference(normalizedFirst).inDays;
    
    // Only apply orange color within a cycle range (0-35 days from period start)
    if (daysDifference < 0 || daysDifference > 35) {
      return false;
    }
    
    // Orange = not fertile, not first day, not 27th day, but within cycle range
    return true;
  }

  @override
  
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: mainColorLight,
        elevation: 0,
        title: Text(
          language.menstrualCalendar,
          style: boldTextStyle(
            color: mainColorText,
            size: 18,
            weight: FontWeight.w500,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Observer(
        builder: (_) {
          final cycleInfo = _getCycleInfo();
          
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Menstrual Calendar Widget
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        language.monthlyCalendar,
                        style: boldTextStyle(
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (cycleInfo != null) ...[
                        _buildCalendarCarousel(cycleInfo),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              language.pleaseLoadCycleInfo,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Legend below calendar
                if (cycleInfo != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildLegend(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarCarousel(CycleInfoModel cycleInfo) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDate, day);
      },
      calendarFormat: _calendarFormat,
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDate = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        // Disable default decorations to allow custom builders to control colors
        defaultDecoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        selectedDecoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        todayDecoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        weekendTextStyle: TextStyle(
          color: Colors.pink[300]!,
          fontSize: 14,
        ),
        defaultTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        todayTextStyle: TextStyle(
          color: ColorUtils.colorPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
        formatButtonDecoration: BoxDecoration(
          color: ColorUtils.colorPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        formatButtonTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        titleTextStyle: TextStyle(
          color: ColorUtils.colorPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: ColorUtils.colorPrimary,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: ColorUtils.colorPrimary,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        weekendStyle: TextStyle(
          color: Colors.pink[300]!,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, events) {
          bool isToday = isSameDay(date, DateTime.now());
          bool isSelected = isSameDay(date, _selectedDate);
          return _buildDayCell(context, date, cycleInfo, isToday, isSelected);
        },
        todayBuilder: (context, date, events) {
          bool isSelected = isSameDay(date, _selectedDate);
          return _buildDayCell(context, date, cycleInfo, true, isSelected);
        },
        selectedBuilder: (context, date, events) {
          bool isToday = isSameDay(date, DateTime.now());
          return _buildDayCell(context, date, cycleInfo, isToday, true);
        },
        outsideBuilder: (context, date, events) {
          return _buildDayCell(context, date, cycleInfo, false, false, isOutside: true);
        },
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    CycleInfoModel cycleInfo,
    bool isToday,
    bool isSelected, {
    bool isOutside = false,
  }) {
    // Normalize the day to start of day for consistent comparison
    DateTime normalizedDay = _normalizeDate(date);
    
    // Check different date types with priority order (only 4 colors: white, red, brown, orange)
    bool isFirstDay = _isFirstDayOfMenstruation(normalizedDay, cycleInfo);
    bool isDay27 = _is27thDayFromMenstruation(normalizedDay, cycleInfo);
    bool isFertile = _isFertileDate(normalizedDay, cycleInfo);
    bool isOrange = _isOrangeDate(normalizedDay, cycleInfo);
    
    // Determine background color based on priority (only 4 colors)
    Color? backgroundColor;
    Color textColor;
    
    if (isFirstDay) {
      // Blood red for first day of menstruation
      backgroundColor = Colors.red;
      textColor = Colors.white;
    } else if (isDay27) {
      // Chocolate brown for 27th day from menstruation
      backgroundColor = const Color(0xFF7B3F00); // Chocolate brown
      textColor = Colors.white;
    } else if (isFertile) {
      // White for fertile days (matching circular beads diagram style)
      backgroundColor = Colors.white;
      textColor = Colors.black87;
    } else if (isOrange) {
      // Orange for all remaining days within cycle range
      backgroundColor = Colors.orange;
      textColor = Colors.white;
    } else {
      // Default: transparent background for days outside cycle range
      backgroundColor = Colors.transparent;
      textColor = isOutside ? Colors.grey[400]! : Colors.black87;
    }
    
    // Debug: Print date info for troubleshooting
    if (isFirstDay || isDay27 || isFertile || isOrange) {
      print('📅 Date: ${normalizedDay.toString().split(' ')[0]} - FirstDay: $isFirstDay, Day27: $isDay27, Fertile: $isFertile, Orange: $isOrange, Color: $backgroundColor');
    }
    
    // Ensure background color is applied - use proper constraints for TableCalendar
    // Add shadow for fertile days (white) to match circular beads diagram style
    return Container(
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: isFertile 
            ? Border.all(color: Colors.grey[300]!, width: 1) // Light border for white fertile days
            : (isToday && !isFirstDay && !isDay27 && !isFertile && !isOrange
                ? Border.all(color: ColorUtils.colorPrimary, width: 2)
                : null),
        boxShadow: isFertile ? [ // Add shadow for fertile days (white) to match circular beads diagram
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: textColor,
            fontWeight: isToday || isSelected || isFirstDay || isDay27 ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Text(
            language.legend,
            style: boldTextStyle(
              size: 14,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildLegendItem(Colors.red, language.firstDayPeriod),
              _buildLegendItem(Colors.white, language.fertilePeriod),
              _buildLegendItem(Colors.orange, language.otherDays),
              _buildLegendItem(const Color(0xFF7B3F00), language.day27),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    // Check if this is the fertile days legend item
    bool isFertileDays = label == language.fertilePeriod || color == Colors.white;
    
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isFertileDays ? [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}


