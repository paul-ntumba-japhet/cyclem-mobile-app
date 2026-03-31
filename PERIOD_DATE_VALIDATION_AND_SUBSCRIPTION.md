# Period Date Validation and Subscription API Implementation

This guide documents the addition of date validation constraints and subscription API call after period date selection.

## Overview

**Location:** Step 8 (Period Date Selection - When did your last period start?)  
**Requirement:** Add validation constraints and subscription API call after date selection  
**API Action:** `actionActive: "SACR"` (different from previous subscriptions)

## Date Validation Constraints

### Constraint 1: No Future Dates (Except Today)
- **Rule:** Cannot select or submit future dates
- **Exception:** Today is allowed
- **Implementation:** Validation checks if selected date is after today

### Constraint 2: Maximum 33 Days Ago
- **Rule:** Cannot select or submit dates more than 33 days prior to current day
- **Boundary:** 33 days ago is inclusive (can be selected)
- **Implementation:** Validation calculates minDate = today - 33 days and checks if selected date is before minDate

### Constraint 3: Valid Date Required
- **Rule:** Must be a valid date
- **Implementation:** DateTime validation ensures date is properly formatted and valid

## Implementation Details

### 1. Calendar Constraints

**File:** `lib/screens/user/questions_list_screen.dart`

**Updated `enabledDayPredicate` in TableCalendar:**
- Only enables dates within the valid range (33 days ago to today, inclusive)
- Disables all dates outside this range visually in the calendar

**Updated calendar boundaries:**
- `firstDay`: Set to 35 days ago (with buffer for navigation)
- `lastDay`: Set to today (current date)

### 2. Date Validation

**File:** `lib/screens/user/questions_list_screen.dart`

**Added `validateStep3PeriodDate()` method:**
- Validates date is selected
- Validates date is not in the future (except today)
- Validates date is not more than 33 days ago
- Validates date format
- Calls subscription API if validation passes
- Only allows proceeding if API returns 200 or 201

### 3. Subscription API Integration

**File:** `lib/service/phone_verification_service.dart`

**Added `createSubscriptionWithPeriodDate()` static method:**
- Accepts phone number, period date, and 3 question answers
- Uses `actionActive: "SACR"` (different from previous subscriptions)
- Includes `dateRegles` field with the selected date
- `emailClient` and `nomClient` are empty strings (as specified)
- Returns `true` only if status is 200 or 201

**Subscription Request Body:**
```json
{
  "identifiantMarchand": "CY-6585526235-WEB",
  "infoSouscription": {
    "montantPaye": 0,
    "numeroMMClient": "",
    "numeroBillingClient": "$phone",  // Formatted phone number (digits only)
    "emailClient": "",                  // Empty string
    "nomClient": "",                    // Empty string
    "devise": "USD",
    "dateRegles": "$date",              // Format: "yyyy-MM-dd" (e.g., "2023-02-27")
    "questionnaires": {
      "questionUn": "true/false",       // From step4Question1.answer
      "questionDeux": "true/false",     // From step4Question2.answer
      "questionTrois": "true/false",    // From step4Question3.answer
      "questionReponse": "true"
    }
  },
  "dateDecreation": "2023-02-27T14:15:39.191Z",  // Current timestamp (ISO 8601)
  "actionActive": "SACR",
  "source": {"source": "WEB"}
}
```

### 4. Updated Continue Button Logic

**File:** `lib/screens/user/questions_list_screen.dart`

**Updated step 8 handling:**
- Calls `validateStep3PeriodDate()` (async)
- Only proceeds if validation passes AND subscription API succeeds
- Shows loading state during API call
- Displays error messages if validation or API fails

### 5. Date Restoration

**File:** `lib/screens/user/questions_list_screen.dart`

**Updated `initState()`:**
- Restores previously selected date from `questionsModel.step3.selectedLastPeriodDate`
- Parses saved date string back to DateTime
- Sets calendar focus to saved date if available

## Validation Flow

1. User selects a date in the calendar
   - Calendar only shows selectable dates (33 days ago to today)
   - Future dates and dates older than 33 days are disabled

2. User clicks "Continue"
   - Validates date is selected
   - Validates date is not in the future (except today)
   - Validates date is not more than 33 days ago
   - Formats date as "yyyy-MM-dd"

3. Subscription API Call
   - Collects phone number from step2Phone
   - Collects question answers from step4Question1, step4Question2, step4Question3
   - Calls subscription API with period date
   - Shows loading indicator

4. Success/Failure
   - If API returns 200 or 201: User proceeds to next step
   - If API fails: Error message shown, user cannot proceed

## Date Format

- **Display Format:** User-friendly calendar display
- **Storage Format:** "yyyy-MM-dd" (e.g., "2023-02-27")
- **API Format:** "yyyy-MM-dd" (same as storage)

## Error Messages

- "Please select the date of your last period" - No date selected
- "Cannot select a future date. Please select today or a past date." - Future date selected
- "Please select a date within the last 33 days" - Date more than 33 days ago
- "Phone number not found. Please verify your phone number first." - Missing phone number
- "Failed to complete subscription: {error}" - API call failed

## Testing Checklist

- [ ] Verify calendar only enables dates within valid range
- [ ] Verify future dates are disabled (except today is enabled)
- [ ] Verify dates more than 33 days ago are disabled
- [ ] Test selecting today's date
- [ ] Test selecting date exactly 33 days ago
- [ ] Test selecting date 34 days ago (should be disabled)
- [ ] Test selecting tomorrow's date (should be disabled)
- [ ] Verify validation prevents proceeding without date selection
- [ ] Verify validation prevents proceeding with invalid date
- [ ] Verify subscription API is called with correct data
- [ ] Verify user can only proceed if API returns 200 or 201
- [ ] Verify error messages display correctly
- [ ] Verify loading state shows during API call
- [ ] Test date restoration from saved data

## Files Modified

1. ✅ `lib/screens/user/questions_list_screen.dart`
   - Updated calendar constraints
   - Added date validation method
   - Updated continue button logic
   - Added date restoration in initState

2. ✅ `lib/service/phone_verification_service.dart`
   - Added `createSubscriptionWithPeriodDate()` method

## Subscription API Differences

There are now 3 subscription API calls with different `actionActive` values:

1. **After OTP Verification:** `actionActive: "SACN"`
   - Called immediately after phone verification
   - Includes phone number only

2. **After Question 3:** `actionActive: "SACQ"`
   - Called after user answers all 3 Yes/No questions
   - Includes phone, email, name, and question answers

3. **After Period Date Selection:** `actionActive: "SACR"` (NEW)
   - Called after user selects period date
   - Includes phone, period date (dateRegles), and question answers
   - emailClient and nomClient are empty strings

