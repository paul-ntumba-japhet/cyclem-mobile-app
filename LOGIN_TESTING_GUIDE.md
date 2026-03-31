# Login Process Testing Guide

## Overview
This guide explains how to test the new login logic that manages QuestionData per phone number.

## Test Method Location
The test method is available in the **Sign In Screen** (`lib/screens/user/sign_in_screen.dart`).

## How to Access the Test

### Option 1: Debug Test Button (Recommended)
1. Open the app in **debug mode**
2. Navigate to the **Sign In Screen**
3. You will see an orange **"🧪 Test Login Logic"** button above the regular login button
4. Enter a phone number and password
5. Click the test button

**Note:** The test button is only visible in debug mode (`kDebugMode`).

### Option 2: Direct Method Call
You can also call the test method programmatically:
```dart
_testLoginLogic(
  phoneNumber: "15066882432",
  password: "your_password",
);
```

## What the Test Does

The test method performs a comprehensive check of the login process:

### Step 1: Check for Existing QuestionData
- Checks if QuestionData exists for the phone number
- If found, displays all stored information:
  - Step selections
  - Name and email
  - Period date
  - Cycle/period lengths
  - Health question answers

### Step 2: Fetch SubscriptionInfoModel (if needed)
- If QuestionData doesn't exist, fetches subscription info from QuickShare API
- Displays subscription information:
  - Client number
  - Client name
  - Client email
  - Last period date
  - Transaction date
  - Status

### Step 3: Create QuestionData (if needed)
- Creates new QuestionData from SubscriptionInfoModel
- Uses default values for optional fields
- Sets health questions to: "yes", "yes", "no"
- Uses subscription data for name, email, and period date

### Step 4: Save QuestionData
- Saves QuestionData to phone-specific storage
- Verifies save operation

### Step 5: Test Actual Login
- Performs the actual login API call
- Verifies login response
- Checks that UserModel is constructed correctly from QuestionData
- Verifies data consistency

## Test Output

The test provides detailed console output showing:

```
═══════════════════════════════════════════════════════
🧪 TESTING LOGIN LOGIC WITH QUESTIONDATA MANAGEMENT
═══════════════════════════════════════════════════════

📱 Phone Number: +24315066882432
📱 Phone (API format): 24315066882432
🔑 Password: ********

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 1: Checking for existing QuestionData...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ QuestionData FOUND for phone: 24315066882432
   - Step 1 Selected: 0
   - Step 2 Selected: 0
   - Name: Sidieu
   - Email: sidieumuyila@gmail.com
   ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 5: Testing actual login API call...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Login SUCCESSFUL
   - User ID: 123
   - Token: eyJhbGciOiJIUzI1NiIs...
   ...

═══════════════════════════════════════════════════════
✅ ALL TESTS PASSED
═══════════════════════════════════════════════════════
```

## Test Scenarios

### Scenario 1: New User (No Existing QuestionData)
**Expected Behavior:**
1. QuestionData not found
2. SubscriptionInfoModel fetched successfully
3. New QuestionData created with subscription data
4. QuestionData saved to phone-specific storage
5. Login successful using new QuestionData

**To Test:**
- Use a phone number that has never logged in before
- Or clear QuestionData for a phone number first

### Scenario 2: Existing User (Has QuestionData)
**Expected Behavior:**
1. QuestionData found for phone number
2. Existing QuestionData loaded
3. SubscriptionInfoModel NOT fetched (not needed)
4. Login successful using existing QuestionData

**To Test:**
- Use a phone number that has completed onboarding or logged in before

### Scenario 3: Subscription API Failure
**Expected Behavior:**
1. QuestionData not found
2. SubscriptionInfoModel fetch fails
3. Fallback QuestionData created with minimal defaults
4. Login still succeeds with fallback data

**To Test:**
- Simulate network error or use invalid phone number
- Check that fallback mechanism works

### Scenario 4: Multiple Users
**Expected Behavior:**
1. Each phone number has its own QuestionData
2. Switching between users loads correct QuestionData
3. Data doesn't mix between users

**To Test:**
- Login with different phone numbers
- Verify each has separate QuestionData storage

## Verification Checklist

After running the test, verify:

- [ ] QuestionData is checked by phone number
- [ ] Existing QuestionData is loaded if found
- [ ] New QuestionData is created from SubscriptionInfoModel if not found
- [ ] Subscription data (name, email, period date) is used correctly
- [ ] Default values are set for optional fields
- [ ] Health questions are set to: "yes", "yes", "no"
- [ ] Step 1 is set to user option (not doctor)
- [ ] QuestionData is saved to phone-specific storage
- [ ] Login API call succeeds
- [ ] UserModel is constructed from QuestionData
- [ ] All data is consistent

## Troubleshooting

### Test Button Not Visible
- **Cause:** App is not in debug mode
- **Solution:** Run the app in debug mode (`flutter run` or debug build)

### "QuestionData not found" but user exists
- **Cause:** QuestionData might be stored under global key only
- **Solution:** Check if data exists in global `KEY_QUESTION_DATA` key

### Subscription API Fails
- **Cause:** Network issue or invalid phone number
- **Solution:** Check network connection and phone number format
- **Note:** Test should still work with fallback defaults

### Login Fails
- **Cause:** Invalid credentials or API issue
- **Solution:** Verify phone number and password are correct
- Check Laravel API endpoint is accessible

## Console Logs

All test steps are logged to the console with detailed information:
- Phone number formatting
- QuestionData existence check
- SubscriptionInfoModel fetch results
- QuestionData creation details
- Login API response
- Data verification results

## Test Results Dialog

After the test completes, a dialog shows:
- **Success:** Green checkmark with detailed results
- **Failure:** Red error icon with error message

The dialog includes:
- Test status (Success/Failed)
- Summary of each step
- Any errors encountered

## Manual Testing Steps

1. **Clear QuestionData (Optional):**
   ```dart
   // In debug console or test code
   String phoneForAPI = "15066882432";
   String key = getQuestionDataKeyForPhone(phoneForAPI);
   await removeKey(key);
   ```

2. **Enter Phone and Password:**
   - Phone: `15066882432` (or your test phone)
   - Password: Your test password

3. **Click Test Button:**
   - Orange "🧪 Test Login Logic" button

4. **Review Results:**
   - Check console logs for detailed output
   - Review dialog for summary
   - Verify QuestionData was created/loaded correctly

5. **Verify Storage:**
   ```dart
   // Check if QuestionData was saved
   QuestionsModel? data = loadQuestionDataForPhone("15066882432");
   print('QuestionData exists: ${data != null}');
   ```

## Expected Console Output Examples

### New User Test:
```
✅ QuestionData NOT FOUND for phone: 15066882432
   → Will create new QuestionData from SubscriptionInfoModel

✅ SubscriptionInfoModel fetched successfully
   - Client Name: Sidieu
   - Client Email: sidieumuyila@gmail.com
   - Last Period Date: 24-07-2025

✅ QuestionData created successfully
   - Step 1 Selected: 0 (User option)
   - Health Q1: true (yes)
   - Health Q2: true (yes)
   - Health Q3: false (no)

✅ QuestionData saved successfully
✅ Login SUCCESSFUL
```

### Existing User Test:
```
✅ QuestionData FOUND for phone: 15066882432
   - Name: Sidieu
   - Email: sidieumuyila@gmail.com
   - Period Date: 2025-07-24

✅ Login SUCCESSFUL
   - User data constructed from existing QuestionData
```

## Next Steps After Testing

1. **Verify Data Persistence:**
   - Logout and login again
   - Verify QuestionData persists

2. **Test Multiple Users:**
   - Login with different phone numbers
   - Verify each has separate QuestionData

3. **Test Edge Cases:**
   - Empty subscription data
   - Missing period date
   - Invalid phone format

4. **Integration Testing:**
   - Test full user flow from login to dashboard
   - Verify QuestionData is used throughout the app




















