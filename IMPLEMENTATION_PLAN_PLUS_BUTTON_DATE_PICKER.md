# Implementation Plan: Replace + Button Screen with Direct Date Picker

## Overview
This document outlines the step-by-step implementation plan to replace the `MenstrualLogPeriodView` screen (currently shown when tapping the + button) with a direct date picker flow that includes payment status checks and subscription API calls.

---

## Current Behavior

### Current Flow:
1. User taps the **+ button** (FloatingActionButton) in the bottom navigation bar of `user_dashboard_screen.dart`
2. The app navigates to `MenstrualLogPeriodView` screen (symptoms logging screen)
3. User can log symptoms and period information

### Current Code Location:
- **File**: `lib/screens/user/user_dashboard_screen.dart`
- **Method**: `navigateToMenstrualLogPeriodView()` (line ~146)
- **Button**: FloatingActionButton `onPressed` handler (line ~188)

---

## New Behavior

### New Flow:
1. User taps the **+ button**
2. **Date picker is displayed directly** (no screen navigation)
3. User selects a date
4. Date validation is performed using `validateLastPeriodDate()`
5. If valid, the following checks are performed:
   - **Payment status check** via `getPaymentStatusApi()`
   - **Subscription API call** (if payment is active)
   - **Period date update** (if subscription succeeds)
   - **Error messages** displayed based on payment status and API responses

---

## Implementation Steps

### Step 1: Modify the + Button Handler in `user_dashboard_screen.dart`

**Location**: `lib/screens/user/user_dashboard_screen.dart` (line ~188)

**Current Code:**
```dart
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
```

**New Code:**
```dart
floatingActionButton: FloatingActionButton(
  elevation: 0,
  heroTag: language.todayActivity,
  child: Icon(Icons.add, size: 44, color: Colors.white),
  onPressed: () async {
    await _handlePlusButtonDatePicker();
  },
),
```

**Action**: Replace the `onPressed` handler to call a new method `_handlePlusButtonDatePicker()` instead of navigating to `MenstrualLogPeriodView`.

---

### Step 2: Create New Method `_handlePlusButtonDatePicker()`

**Location**: `lib/screens/user/user_dashboard_screen.dart` (add after `navigateToMenstrualLogPeriodView` method)

**Purpose**: This method will:
1. Show the date picker
2. Validate the selected date
3. Check payment status
4. Call subscription API if needed
5. Update period date if successful
6. Display appropriate error messages

**Method Signature:**
```dart
Future<void> _handlePlusButtonDatePicker() async {
  // Implementation details below
}
```

---

### Step 3: Implement Date Picker Display

**Within `_handlePlusButtonDatePicker()`:**

```dart
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
  
  // Continue to validation...
}
```

**Notes:**
- Uses the same date picker configuration as in `circular_beads_diagram.dart`
- `lastPeriodDateMaxDaysAgo` constant is defined in `lib/utils/period_date_validation.dart` (value: 33)
- Import required: `import '../utils/period_date_validation.dart';`

---

### Step 4: Implement Date Validation

**Within `_handlePlusButtonDatePicker()`, after date picker:**

```dart
final scaffoldMessenger = ScaffoldMessenger.of(context);

// Validate the selected date
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
```

**Notes:**
- Uses existing `validateLastPeriodDate()` function from `lib/utils/period_date_validation.dart`
- Displays validation error message if date is invalid
- Returns early if validation fails

---

### Step 5: Get User Phone Number

**Within `_handlePlusButtonDatePicker()`, after validation:**

```dart
// Get and format phone number
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
```

**Notes:**
- Phone number is required for API calls
- Format: ensure it starts with '+' if not empty
- Display error if phone number is not available

---

### Step 6: Check Payment Status

**Within `_handlePlusButtonDatePicker()`, after phone number validation:**

```dart
// Check payment status
try {
  final paymentStatus = await getPaymentStatusApi(fullPhoneNumber);
  
  // Handle different payment status codes
  if (paymentStatus.code == '100') {
    // Active payment - proceed to subscription API
    // Continue to Step 7
  } else if (paymentStatus.code == '300') {
    // Inactive payment - check country code
    // Continue to Step 8
  } else {
    // Other status - show error
    // Continue to Step 9
  }
} catch (e) {
  // Handle API error
  if (mounted) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('${language.errorLabel}: ${language.failedToLoadTransactions}'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return;
}
```

**Notes:**
- Import required: `import '../network/rest_api.dart';`
- `getPaymentStatusApi()` returns `PaymentStatusModel` with `code` and `message` fields
- Error handling for API failures

---

### Step 7: Handle Active Payment (Code 100) - Call Subscription API

**Within `_handlePlusButtonDatePicker()`, inside the `if (paymentStatus.code == '100')` block:**

```dart
if (paymentStatus.code == '100') {
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
  
  if (!mounted) return;
  
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
        content: Text("Your cycle is still active..."),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
```

**Notes:**
- Import required: `import '../service/phone_verification_service.dart';`
- `createSubscriptionWithPeriodDate()` returns `true` if HTTP status is 200 or 201, `false` otherwise
- **Note**: The function returns `true` for both status 200 and 201. The requirement specifies checking for status 200, but since the function treats both as success, we'll use `success == true` to mean status 200 (or 201) was returned.
- If `success == true`, update period date in userStore and cycle info
- If `success == false`, show "Your cycle is still active..." message
- Import required for date formatting: `import 'package:intl/intl.dart';`
- Import required for cycle info: `import '../model/user/cycle_info_model.dart';`
- Import required for storage: `import '../utils/shared_pref.dart';`

---

### Step 8: Handle Inactive Payment (Code 300) - Check Country Code

**Within `_handlePlusButtonDatePicker()`, inside the `else if (paymentStatus.code == '300')` block:**

```dart
else if (paymentStatus.code == '300') {
  // Inactive payment - check country code
  if (!isDRCCountryCode(fullPhoneNumber)) {
    // Not DRC (country code 243) - redirect to payment
    StripeCheckout().launch(context);
  } else {
    // DRC (country code 243) - show message
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text("You must pay before submitting a new date"),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
```

**Notes:**
- Import required: `import '../utils/app_common.dart';` (for `isDRCCountryCode`)
- Import required: `import '../screens/payment/stripe_checkout.dart';` (for `StripeCheckout`)
- `isDRCCountryCode()` checks if phone number starts with country code 243 (DRC)
- If not DRC: redirect to Stripe payment flow
- If DRC: show payment required message

---

### Step 9: Handle Other Payment Status Codes

**Within `_handlePlusButtonDatePicker()`, inside the `else` block:**

```dart
else {
  // Other payment status - show error
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Text("An error has occurred"),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}
```

**Notes:**
- Handles any payment status code other than "100" or "300"
- Displays generic error message

---

### Step 10: Add Error Handling for Entire Method

**Wrap the entire `_handlePlusButtonDatePicker()` method in try-catch:**

```dart
Future<void> _handlePlusButtonDatePicker() async {
  if (!mounted) return;
  
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  try {
    // All the implementation from Steps 3-9
    // ...
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
```

**Notes:**
- Catches any unexpected errors
- Displays error message to user
- Checks `mounted` before showing SnackBar

---

## Required Imports

Add these imports to `lib/screens/user/user_dashboard_screen.dart`:

```dart
import 'package:intl/intl.dart';
import '../utils/period_date_validation.dart';
import '../network/rest_api.dart';
import '../service/phone_verification_service.dart';
import '../utils/app_common.dart';
import '../screens/payment/stripe_checkout.dart';
import '../model/user/cycle_info_model.dart';
import '../utils/shared_pref.dart';
```

---

## Translation Keys (Optional)

If you want to translate the hardcoded messages, add these keys to your language files:

1. **"Your cycle is still active..."**
   - Key: `cycleStillActive`
   - French: "Votre cycle est toujours actif..."

2. **"You must pay before submitting a new date"**
   - Key: `mustPayBeforeSubmittingDate`
   - French: "Vous devez payer avant de soumettre une nouvelle date"

3. **"An error has occurred"**
   - Key: `anErrorHasOccurred`
   - French: "Une erreur s'est produite"

Then replace hardcoded strings with `language.cycleStillActive`, `language.mustPayBeforeSubmittingDate`, and `language.anErrorHasOccurred`.

---

## Testing Checklist

After implementation, test the following scenarios:

1. ✅ **Valid date selection with active payment (code 100)**
   - Select a valid date
   - Verify subscription API is called
   - Verify period date is updated if API returns 200
   - Verify "Your cycle is still active..." message if API doesn't return 200

2. ✅ **Valid date selection with inactive payment (code 300) - Non-DRC user**
   - Select a valid date
   - Verify payment flow is launched (Stripe checkout)

3. ✅ **Valid date selection with inactive payment (code 300) - DRC user**
   - Select a valid date with DRC phone number (starts with 243)
   - Verify "You must pay before submitting a new date" message is shown

4. ✅ **Valid date selection with other payment status**
   - Select a valid date
   - Verify "An error has occurred" message is shown

5. ✅ **Invalid date selection (future date)**
   - Select a future date
   - Verify validation error message is shown

6. ✅ **Invalid date selection (too old)**
   - Select a date more than 33 days ago
   - Verify validation error message is shown

7. ✅ **No phone number available**
   - Test with user that has no phone number
   - Verify "Phone not available" error message

8. ✅ **Payment status API error**
   - Simulate API failure
   - Verify error message is shown

---

## Files to Modify

1. **`lib/screens/user/user_dashboard_screen.dart`**
   - Modify FloatingActionButton `onPressed` handler
   - Add `_handlePlusButtonDatePicker()` method
   - Add required imports

---

## Files to Reference (No Changes Needed)

1. **`lib/utils/period_date_validation.dart`** - Date validation logic
2. **`lib/network/rest_api.dart`** - `getPaymentStatusApi()` function
3. **`lib/service/phone_verification_service.dart`** - `createSubscriptionWithPeriodDate()` function
4. **`lib/utils/app_common.dart`** - `isDRCCountryCode()` function
5. **`lib/screens/widgets/circular_beads_diagram.dart`** - Reference implementation for date picker and validation

---

## Summary

This implementation will:
- ✅ Remove navigation to `MenstrualLogPeriodView` screen
- ✅ Show date picker directly when + button is tapped
- ✅ Validate selected date using existing validation function
- ✅ Check payment status via API
- ✅ Call subscription API for active payments (code 100)
- ✅ Update period date if subscription API returns status 200
- ✅ Handle inactive payments (code 300) based on country code
- ✅ Display appropriate error messages for all scenarios
- ✅ Maintain existing error handling patterns

---

## Notes

- **Subscription API Response**: The `createSubscriptionWithPeriodDate()` function returns `true` for HTTP status 200 or 201, and `false` otherwise. The requirement specifies checking for status 200, but since the function treats both 200 and 201 as success, we'll use `success == true` to mean the API returned a successful status (200 or 201). If you need to distinguish between 200 and 201, you would need to modify the function to return the actual status code.

- **Payment Status Code "100"**: The payment status code "100" for active payment is mentioned in the requirements. However, the current `PaymentStatusModel` only explicitly handles "300" for inactive payments. The `isActive` getter returns `true` if code is NOT "300". **Please verify with the API documentation** that:
  - Code "100" is indeed returned for active payments
  - Or if any code other than "300" should be treated as active
  - Update the condition in Step 6 accordingly if needed

- **Alternative Approach**: If code "100" is not confirmed, you could use `paymentStatus.isActive` (which returns `true` for any code != "300") instead of checking `paymentStatus.code == '100'`.

- Consider adding loading indicators during API calls for better UX.

- The date picker implementation matches the one in `circular_beads_diagram.dart` for consistency.

