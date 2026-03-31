# Implementation Guide: QuestionData Management on Login

## Overview
When a user logs in with phone number and password, the system should check if QuestionData (QuestionsModel) exists for that phone number. If it exists, use it; otherwise, create a new QuestionsModel object using data from SubscriptionInfoModel and default values.

## Implementation Steps

### Step 1: Create Helper Function to Get QuestionData Key by Phone Number

**Location:** `lib/utils/app_constants.dart`

Add a new constant and helper function to generate phone-specific keys:

```dart
// Add this constant
const KEY_QUESTION_DATA_PREFIX = "question_data_";

// Helper function to get phone-specific question data key
String getQuestionDataKeyForPhone(String phoneNumber) {
  // Remove non-digit characters for consistent key
  String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  return '$KEY_QUESTION_DATA_PREFIX$cleanPhone';
}
```

**Alternative:** Add this helper function in `lib/extensions/shared_pref.dart` or create a new utility file.

---

### Step 2: Create Function to Load QuestionData by Phone Number

**Location:** `lib/network/rest_api.dart` or create `lib/utils/question_data_utils.dart`

Create a helper function to load QuestionData for a specific phone number:

```dart
import '../model/user/question_model.dart';
import '../extensions/shared_pref.dart';
import '../utils/app_constants.dart';

/// Load QuestionData for a specific phone number
/// Returns null if not found
QuestionsModel? loadQuestionDataForPhone(String phoneNumber) {
  try {
    String key = getQuestionDataKeyForPhone(phoneNumber);
    Map<String, dynamic>? questionData = getJSONAsync(key);
    
    if (questionData != null && questionData.isNotEmpty) {
      return QuestionsModel.fromJson(questionData);
    }
    return null;
  } catch (e) {
    print('Error loading question data for phone $phoneNumber: $e');
    return null;
  }
}
```

---

### Step 3: Create Function to Save QuestionData by Phone Number

**Location:** Same file as Step 2

```dart
/// Save QuestionData for a specific phone number
Future<void> saveQuestionDataForPhone(String phoneNumber, QuestionsModel questionsModel) async {
  try {
    String key = getQuestionDataKeyForPhone(phoneNumber);
    await setValue(key, questionsModel.toJson());
    print('QuestionData saved for phone: $phoneNumber');
  } catch (e) {
    print('Error saving question data for phone $phoneNumber: $e');
    rethrow;
  }
}
```

---

### Step 4: Create Function to Initialize QuestionData from Subscription Info

**Location:** `lib/network/rest_api.dart` or `lib/utils/question_data_utils.dart`

This function creates a new QuestionsModel using SubscriptionInfoModel data and defaults:

```dart
import '../model/user/question_model.dart';
import '../model/user/subscription_info_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_common.dart';

/// Create a new QuestionsModel from SubscriptionInfoModel with defaults
QuestionsModel createQuestionDataFromSubscription({
  required SubscriptionInfoModel subscriptionInfo,
  required String phoneNumber,
  String? countryCode,
}) {
  // Step 1: Using Era - Set to option for user (not doctor)
  // Option 0 = "Yes, for tracking" (user option)
  Step1 newStep1 = Step1(
    title: "${language.areYouUsing} Era ${language.forYourself} ?",
    options: ["${language.yesForTracking}. ", "${language.yesAsADoctor}."],
    selectedOption: 0, // User option (not doctor)
    isConfirm: true,
    isSkip: false,
  );

  // Step 2: Goal Type - Use default (Track Cycle)
  Step2 newStep2 = Step2(
    title: "${language.whatIsYourGoalType}?",
    desc: "${language.allFeatureswWillBeAvailable}",
    options: [
      GoalTypeModel(
        img: ic_track_cycle,
        title: "${language.trackCycle}",
        desc: "${language.stayPreparedForYourNextPeriod}."),
      GoalTypeModel(
        img: ic_track_pregnancy,
        title: "${language.trackPregnancy}",
        desc: "${language.monitorChangesInYourBody}.")
    ],
    selectedOption: 0, // Default: Track Cycle
    isConfirm: true,
    isSkip: false,
  );

  // Step 2 Phone: Set phone number and mark as verified
  Step2Phone newStep2Phone = Step2Phone(
    phoneNumber: phoneNumber.replaceAll(RegExp(r'[^\d]'), ''),
    countryCode: countryCode ?? "+243",
    verificationId: null,
    isVerified: true, // Already verified through login
    otpCode: null,
  );

  // Step 3 Personal Info: Use data from SubscriptionInfoModel
  Step3PersonalInfo newStep3PersonalInfo = Step3PersonalInfo(
    fullName: subscriptionInfo.nomClient.isNotEmpty 
        ? subscriptionInfo.nomClient 
        : null,
    email: subscriptionInfo.emailClient.isNotEmpty 
        ? subscriptionInfo.emailClient 
        : null,
    isCompleted: true,
  );

  // Step 4 Questions: Use "yes", "yes", "no" as specified
  Step4Question1 newStep4Question1 = Step4Question1(
    question: "Do you have any existing health conditions?",
    answer: true, // "yes"
    isCompleted: true,
  );

  Step4Question2 newStep4Question2 = Step4Question2(
    question: "Are you currently taking any medications?",
    answer: true, // "yes"
    isCompleted: true,
  );

  Step4Question3 newStep4Question3 = Step4Question3(
    question: "Have you consulted a doctor about your cycle recently?",
    answer: false, // "no"
    isCompleted: true,
  );

  // Step 3: Period Information - Use dateDernierRegles from SubscriptionInfoModel
  String periodDate = subscriptionInfo.dateDernierRegles.isNotEmpty
      ? subscriptionInfo.dateDernierRegles
      : ""; // Empty if not available (user can skip)

  Step3 newStep3 = Step3(
    title: "${language.whenDidYourLastPeriod}",
    desc: "${language.provideThisInformationSoThatWeCanPredict}.",
    selectedLastPeriodDate: periodDate,
    isSkip: periodDate.isEmpty, // Skip if no date available
    isConfirm: periodDate.isNotEmpty,
  );

  // Step 4: Cycle Length - Use default
  Step4 newStep4 = Step4(
    title: "${language.whatIsYourCycleLength} ?",
    cycleLengthList: getCycleLengthList(),
    selectedOption: DEFAULT_CYCLE_LENGTH, // Default: 28 days
    isConfirm: true,
    isSkip: false,
  );

  // Step 5: Period Duration - Use default
  Step5 newStep5 = Step5(
    title: "${language.whatIsYourPeriodDuration} ?",
    desc: "${language.whatIsYourPeriodDurationDescription}.",
    periodLengthList: getPeriodLengthList(),
    selectedOption: DEFAULT_PERIOD_LENGTH, // Default: 5 days
    isConfirm: true,
    isSkip: false,
  );

  // Step 6: Luteal Phase - Use default (skip, selectedOption = -1)
  Step6 newStep6 = Step6(
    title: "What is Luteal Phase?",
    desc: "The luteal phase is the duration between ovulation and the start of your period. Logging its length helps improve the accuracy of ovulation predictions.",
    lutealLengthList: getLutealLengthList(),
    selectedOption: -1, // Not selected (skipped)
    isConfirm: false,
    isSkip: true,
  );

  // Step 7: Additional Information - Use defaults (skip)
  Step7 newStep7 = Step7(
    title: "Complete Your Profile",
    desc: "Help us personalize your experience by providing your age",
    question1: null,
    question2: "What year were you born?",
    answerToQuestion1: null,
    answerToQuestion2: null,
    confirm: false,
    skip: true,
  );

  // Create and return the complete QuestionsModel
  return QuestionsModel(
    step1: newStep1,
    step2: newStep2,
    step2Phone: newStep2Phone,
    step3PersonalInfo: newStep3PersonalInfo,
    step4Question1: newStep4Question1,
    step4Question2: newStep4Question2,
    step4Question3: newStep4Question3,
    step3: newStep3,
    step4: newStep4,
    step5: newStep5,
    step6: newStep6,
    step7: newStep7,
  );
}
```

**Note:** Make sure to import all necessary dependencies:
- `language` from your language configuration
- `ic_track_cycle`, `ic_track_pregnancy` from `app_images.dart`
- `getCycleLengthList()`, `getPeriodLengthList()`, `getLutealLengthList()` from your utility functions
- `DEFAULT_CYCLE_LENGTH`, `DEFAULT_PERIOD_LENGTH` from `app_constants.dart`

---

### Step 5: Update logInAsUserApi to Check and Initialize QuestionData

**Location:** `lib/network/rest_api.dart`

Modify the `logInAsUserApi` function to check for existing QuestionData and create it if needed:

```dart
Future<UserResponse> logInAsUserApi(request) async {
  // ... existing login code ...
  
  // After successful login and before constructing UserModel:
  
  // Extract phone number from request
  String? phoneNumber = request['username']?.toString();
  if (phoneNumber == null || phoneNumber.isEmpty) {
    throw Exception('Phone number is required for login');
  }
  
  // Format phone number (remove non-digits)
  String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  
  // Check if QuestionData exists for this phone number
  QuestionsModel? existingQuestionData = loadQuestionDataForPhone(phoneForAPI);
  
  QuestionsModel questionsModelData;
  
  if (existingQuestionData != null) {
    // Use existing QuestionData
    print('Using existing QuestionData for phone: $phoneForAPI');
    questionsModelData = existingQuestionData;
  } else {
    // QuestionData doesn't exist - create new one from SubscriptionInfoModel
    print('QuestionData not found for phone: $phoneForAPI. Creating new one from subscription info...');
    
    try {
      // Fetch subscription info from QuickShare API
      SubscriptionInfoModel subscriptionInfo = await getSubscriptionInfoApi(phoneNumber);
      
      // Get country code from request if available, or use default
      String? countryCode = request['country_code']?.toString();
      
      // Create new QuestionData from subscription info
      questionsModelData = createQuestionDataFromSubscription(
        subscriptionInfo: subscriptionInfo,
        phoneNumber: phoneNumber,
        countryCode: countryCode,
      );
      
      // Save the new QuestionData for this phone number
      await saveQuestionDataForPhone(phoneForAPI, questionsModelData);
      print('New QuestionData created and saved for phone: $phoneForAPI');
      
    } catch (e) {
      print('Error fetching subscription info or creating QuestionData: $e');
      // Fallback: Create QuestionData with minimal defaults if subscription fetch fails
      questionsModelData = createQuestionDataFromSubscription(
        subscriptionInfo: SubscriptionInfoModel(
          numeroClient: phoneForAPI,
          nomClient: '',
          emailClient: '',
          dateTransaction: '',
          dateDernierRegles: '',
          dateDernierPayJour: '',
          dateDernierPayMois: '',
          statusClient: '0',
          reqType: 'R',
        ),
        phoneNumber: phoneNumber,
        countryCode: request['country_code']?.toString(),
      );
      await saveQuestionDataForPhone(phoneForAPI, questionsModelData);
    }
  }
  
  // Now use questionsModelData for the rest of the login process
  // ... rest of existing code to construct UserModel from questionsModelData ...
}
```

---

### Step 6: Update Code That Uses QuestionData to Load by Phone Number

**Location:** Any file that reads `KEY_QUESTION_DATA`

Update all places that read QuestionData to use the phone-specific key:

**Example in `lib/screens/user/user _setting_screen.dart`:**

```dart
getQuestionData() async {
  try {
    var userType = getStringAsync(USER_TYPE);
    var goalType;
    if (GOAL.runtimeType is int) {
      goalType = getIntAsync(GOAL);
    } else {
      goalType = getIntAsync(GOAL);
    }
    
    if (userType == ANONYMOUS) {
      // For anonymous users, use global key
      Map<String, dynamic> map = getJSONAsync(KEY_QUESTION_DATA);
      questionsModelData = QuestionsModel.fromJson(map);
    } else if (userType == APP_USER) {
      // For app users, load by phone number
      String? phoneNumber = userStore.user?.phoneNumber;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
        QuestionsModel? loadedData = loadQuestionDataForPhone(phoneForAPI);
        if (loadedData != null) {
          questionsModelData = loadedData;
        } else {
          // Fallback to global key for backward compatibility
          Map<String, dynamic> map = getJSONAsync(KEY_QUESTION_DATA);
          if (map.isNotEmpty) {
            questionsModelData = QuestionsModel.fromJson(map);
          }
        }
      }
    } else {
      // Default initialization
      questionsModelData = QuestionsModel(
        step1: step1,
        step2: step2,
        // ... rest of defaults
      );
    }
    
    // ... rest of existing code ...
  } catch (e) {}
}
```

---

### Step 7: Update Code That Saves QuestionData to Save by Phone Number

**Location:** Files that save QuestionData (e.g., `lib/screens/user/questions_list_screen.dart`)

When saving QuestionData, also save it with the phone-specific key:

```dart
// When saving QuestionData during onboarding
Future<void> saveQuestionData(QuestionsModel questionsModel) async {
  // Save to global key for backward compatibility
  await setValue(KEY_QUESTION_DATA, questionsModel.toJson());
  
  // Also save to phone-specific key if user is logged in
  if (userStore.isLoggedIn && userStore.user?.phoneNumber != null) {
    String phoneNumber = userStore.user!.phoneNumber!;
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    await saveQuestionDataForPhone(phoneForAPI, questionsModel);
  }
}
```

---

### Step 8: Handle Date Format Conversion

**Location:** `createQuestionDataFromSubscription` function

The `dateDernierRegles` from SubscriptionInfoModel might be in format "24-07-2025" (DD-MM-YYYY), but the app might expect a different format. Add conversion if needed:

```dart
String convertDateToAppFormat(String dateString) {
  if (dateString.isEmpty) return "";
  
  try {
    // Try parsing DD-MM-YYYY format
    List<String> parts = dateString.split('-');
    if (parts.length == 3) {
      String day = parts[0].padLeft(2, '0');
      String month = parts[1].padLeft(2, '0');
      String year = parts[2];
      
      // Convert to YYYY-MM-DD format (ISO format)
      return '$year-$month-$day';
    }
  } catch (e) {
    print('Error converting date format: $e');
  }
  
  // Return as-is if conversion fails
  return dateString;
}

// In createQuestionDataFromSubscription:
String periodDate = subscriptionInfo.dateDernierRegles.isNotEmpty
    ? convertDateToAppFormat(subscriptionInfo.dateDernierRegles)
    : "";
```

---

### Step 9: Testing Checklist

1. **Test New User Login:**
   - Login with a phone number that has no existing QuestionData
   - Verify that QuestionData is created from SubscriptionInfoModel
   - Verify that all default values are set correctly
   - Verify that subscription data (name, email, period date) is used

2. **Test Existing User Login:**
   - Login with a phone number that has existing QuestionData
   - Verify that existing QuestionData is loaded and used
   - Verify that subscription data is NOT overwritten

3. **Test Subscription API Failure:**
   - Simulate subscription API failure
   - Verify that QuestionData is still created with minimal defaults
   - Verify that login still succeeds

4. **Test Multiple Users:**
   - Login with different phone numbers
   - Verify that each phone number has its own QuestionData
   - Verify that switching between users loads correct QuestionData

5. **Test Data Persistence:**
   - Login, logout, login again
   - Verify that QuestionData persists across sessions

---

### Step 10: Migration Strategy (Optional)

If you want to migrate existing QuestionData to phone-specific storage:

```dart
/// Migrate existing global QuestionData to phone-specific storage
Future<void> migrateQuestionDataToPhoneStorage(String phoneNumber) async {
  try {
    // Check if global QuestionData exists
    Map<String, dynamic>? globalData = getJSONAsync(KEY_QUESTION_DATA);
    
    if (globalData != null && globalData.isNotEmpty) {
      String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      // Check if phone-specific data already exists
      QuestionsModel? existing = loadQuestionDataForPhone(phoneForAPI);
      
      if (existing == null) {
        // Migrate global data to phone-specific storage
        QuestionsModel questionsModel = QuestionsModel.fromJson(globalData);
        await saveQuestionDataForPhone(phoneForAPI, questionsModel);
        print('Migrated QuestionData to phone-specific storage for: $phoneForAPI');
      }
    }
  } catch (e) {
    print('Error migrating QuestionData: $e');
  }
}

// Call this during login if needed
```

---

## Summary of Changes

1. **New Constants:** `KEY_QUESTION_DATA_PREFIX` and helper function `getQuestionDataKeyForPhone()`
2. **New Functions:**
   - `loadQuestionDataForPhone()` - Load QuestionData by phone number
   - `saveQuestionDataForPhone()` - Save QuestionData by phone number
   - `createQuestionDataFromSubscription()` - Create QuestionData from SubscriptionInfoModel
   - `convertDateToAppFormat()` - Convert date format if needed
3. **Modified Functions:**
   - `logInAsUserApi()` - Check and initialize QuestionData on login
   - `getQuestionData()` in settings screen - Load by phone number
   - QuestionData save operations - Save to phone-specific key
4. **Data Flow:**
   - Login → Check QuestionData by phone → If not exists, fetch SubscriptionInfo → Create QuestionData → Save → Use for navigation

---

## Important Notes

1. **Backward Compatibility:** Keep saving to `KEY_QUESTION_DATA` for backward compatibility with anonymous users
2. **Error Handling:** Always handle cases where SubscriptionInfo API fails
3. **Date Formats:** Ensure date format conversion matches your app's expectations
4. **Phone Number Formatting:** Always normalize phone numbers (remove non-digits) for consistent keys
5. **Default Values:** Use the exact defaults specified in the requirements
6. **Step 1 Selection:** Ensure `selectedOption: 0` is used (user option, not doctor)

---

## Files to Modify

1. `lib/utils/app_constants.dart` - Add helper function
2. `lib/network/rest_api.dart` - Add helper functions and update `logInAsUserApi`
3. `lib/utils/question_data_utils.dart` - (Optional) Create new file for QuestionData utilities
4. `lib/screens/user/user _setting_screen.dart` - Update `getQuestionData()`
5. `lib/screens/user/questions_list_screen.dart` - Update save operations
6. Any other files that read/write QuestionData

---

## Implementation Order

1. Step 1: Add helper function for phone-specific keys
2. Step 2-3: Create load/save functions
3. Step 4: Create initialization function from subscription
4. Step 5: Update login function
5. Step 6-7: Update read/write operations throughout app
6. Step 8: Add date format conversion if needed
7. Step 9: Test thoroughly
8. Step 10: Migration (if needed)

