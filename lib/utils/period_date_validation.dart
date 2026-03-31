/// Centralized validation logic for "last period date" selection.
/// Used in onboarding and anywhere the app needs to validate that a date
/// is within the allowed range (from [lastPeriodDateMaxDaysAgo] days ago up to today).
library;

/// Maximum number of days in the past that a "last period" date can be selected.
/// Dates older than this are considered invalid.
const int lastPeriodDateMaxDaysAgo = 33;

/// Default error messages for validation (can be overridden by callers for localization).
const String periodDateValidationErrorNotSelected =
    'Please select the date of your last period';
const String periodDateValidationErrorFutureDate =
    'Cannot select a future date. Please select today or a past date.';
const String periodDateValidationErrorTooOld =
    'Please select a date within the last $lastPeriodDateMaxDaysAgo days';

/// Result of validating a last-period date.
class PeriodDateValidationResult {
  final bool isValid;
  final String? errorMessage;

  const PeriodDateValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  /// Valid date.
  factory PeriodDateValidationResult.valid() =>
      const PeriodDateValidationResult(isValid: true);

  /// Invalid date with a specific message.
  factory PeriodDateValidationResult.invalid(String message) =>
      PeriodDateValidationResult(isValid: false, errorMessage: message);
}

/// Validates a "last period" date against the rules:
/// 1. [selectedDate] must not be null (date must be selected).
/// 2. Date must not be in the future (today is allowed).
/// 3. Date must not be more than [lastPeriodDateMaxDaysAgo] days in the past.
///
/// [referenceDate] defaults to today (date-only). Pass it for tests or custom "today".
///
/// Returns [PeriodDateValidationResult.valid()] if all checks pass, otherwise
/// [PeriodDateValidationResult.invalid] with the appropriate message.
PeriodDateValidationResult validateLastPeriodDate(
  DateTime? selectedDate, {
  DateTime? referenceDate,
  String? errorNotSelected,
  String? errorFutureDate,
  String? errorTooOld,
}) {
  final today = _dateOnly(referenceDate ?? DateTime.now());
  final minDate = today.subtract(Duration(days: lastPeriodDateMaxDaysAgo));
  final minDateOnly = _dateOnly(minDate);

  // 1. Date must be selected
  if (selectedDate == null) {
    return PeriodDateValidationResult.invalid(
      errorNotSelected ?? periodDateValidationErrorNotSelected,
    );
  }

  final selectedDateOnly = _dateOnly(selectedDate);

  // 2. Cannot select future dates (today is allowed)
  if (selectedDateOnly.isAfter(today)) {
    return PeriodDateValidationResult.invalid(
      errorFutureDate ?? periodDateValidationErrorFutureDate,
    );
  }

  // 3. Cannot select dates more than [lastPeriodDateMaxDaysAgo] days ago (inclusive)
  if (selectedDateOnly.isBefore(minDateOnly)) {
    return PeriodDateValidationResult.invalid(
      errorTooOld ?? periodDateValidationErrorTooOld,
    );
  }

  return PeriodDateValidationResult.valid();
}

/// Returns true if [date] is within the allowed last-period range:
/// from ([referenceDate] - [lastPeriodDateMaxDaysAgo]) up to and including [referenceDate].
/// [referenceDate] defaults to today (date-only).
bool isLastPeriodDateInAllowedRange(
  DateTime date, {
  DateTime? referenceDate,
}) {
  final today = _dateOnly(referenceDate ?? DateTime.now());
  final minDate = today.subtract(Duration(days: lastPeriodDateMaxDaysAgo));
  final minDateOnly = _dateOnly(minDate);
  final dayOnly = _dateOnly(date);
  final isNotBeforeMin = !dayOnly.isBefore(minDateOnly);
  final isTodayOrPast = dayOnly.isBefore(today) || _isSameDay(dayOnly, today);
  return isNotBeforeMin && isTodayOrPast;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
