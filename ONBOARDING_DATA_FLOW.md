# Onboarding Screen Information Storage and Usage During First-Time Registration

## Overview
This document explains how and when onboarding screen information (QuestionData) is stored and used during the first-time registration process.

---

## Registration Flow Overview

```
Splash Screen → QuestionsListScreen (Onboarding) → SignUpScreen → Dashboard
                                    ↓
                            ProgressScreen (for anonymous users)
```

---

## Step-by-Step Flow

### 1. **Entry Point: Splash Screen**

**File:** `lib/screens/common/splash_screen.dart`

**When:** App first launches or user is not logged in

**Action:**
- Checks if user is logged in
- If not logged in → Navigates to `QuestionsListScreen()` (onboarding)

```dart
// From warning_dialog.dart (called from splash)
if (!login) {
  QuestionsListScreen().launch(context, isNewTask: true);
}
```

---

### 2. **Onboarding Process: QuestionsListScreen**

**File:** `lib/screens/user/questions_list_screen.dart`

**Purpose:** Collects all onboarding information through multiple steps

**Steps in Order:**
1. **Step 1:** Are you using Era for yourself? (User vs Doctor)
2. **Step 2:** What is your goal type? (Track Cycle vs Track Pregnancy)
3. **Step 3:** Phone Verification
4. **Step 4:** Personal Information (Name & Email)
5. **Step 5:** Health Question 1 (Yes/No)
6. **Step 6:** Health Question 2 (Yes/No)
7. **Step 7:** Health Question 3 (Yes/No)
8. **Step 8:** Last Period Date
9. **Step 9:** Cycle Length
10. **Step 10:** Period Duration
11. **Step 11:** Age (Birth Year)

---

## When QuestionData is Stored

### **Storage Location:** SharedPreferences with key `KEY_QUESTION_DATA`

### **Storage Points During Onboarding:**

#### **A. Step 1 - User Selection (Step 1)**
**Location:** `questions_list_screen.dart` - `step1()` method

**When:** User selects "Yes, for tracking" (user option)

**Code:**
```dart
onTap: () {
  if (index == 1) {
    DoctorLoginScreen().launch(context); // Doctor path
  } else {
    questionsModel.step1.selectedOption = index;
    currentStep = 2;
    setState(() {});
    // Note: Not saved here, saved later when moving to next step
  }
}
```

**Storage:** Not saved immediately, but saved when moving to Step 2

---

#### **B. Step 2 - Goal Type Selection**
**Location:** `questions_list_screen.dart` - `step2()` method

**When:** User selects goal type and clicks "Confirm"

**Code:**
```dart
// When confirm button is clicked
if (currentStep == 2) {
  questionsModel.step2.selectedOption = selectedIndex;
  setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
  currentStep++;
  setState(() {});
}
```

**Line:** ~122 in `questions_list_screen.dart`

---

#### **C. Step 3 - Phone Verification**
**Location:** `lib/screens/user/widgets/phone_verification_widget.dart`

**When:** Phone number is verified via OTP

**Code:**
```dart
// After successful OTP verification
questionsModel.step2Phone.phoneNumber = phoneNumber;
questionsModel.step2Phone.countryCode = countryCode;
questionsModel.step2Phone.isVerified = true;
setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
```

**Lines:** ~170, ~211 in `phone_verification_widget.dart`

---

#### **D. Step 4 - Personal Information**
**Location:** `lib/screens/user/widgets/personal_info_widget.dart`

**When:** User enters name and email, clicks "Confirm"

**Code:**
```dart
bool validateStep3PersonalInfo() {
  if (currentStep == 4) {
    // Validate and mark as completed
    questionsModel.step3PersonalInfo.isCompleted = true;
    setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
  }
  return true;
}
```

**Lines:** ~113, ~163 in `personal_info_widget.dart`

---

#### **E. Step 5-7 - Health Questions (Yes/No)**
**Location:** `questions_list_screen.dart` - `validateStep4Question1()`, `validateStep4Question2()`, `validateStep4Question3()`

**When:** User answers each health question

**Code:**
```dart
// Question 1
questionsModel.step4Question1.answer = answer; // true/false
questionsModel.step4Question1.isCompleted = true;
setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE

// Question 2
questionsModel.step4Question2.answer = answer;
questionsModel.step4Question2.isCompleted = true;
setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE

// Question 3 (also calls subscription API)
questionsModel.step4Question3.answer = answer;
questionsModel.step4Question3.isCompleted = true;
setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
```

**Lines:** ~134, ~146, ~160 in `questions_list_screen.dart`

**Special Note:** Step 7 (Question 3) also calls `PhoneVerificationService.createSubscriptionWithAnswers()` to create subscription with questionnaire answers.

---

#### **F. Step 8 - Last Period Date**
**Location:** `questions_list_screen.dart` - `validateStep3PeriodDate()`

**When:** User selects last period date and clicks "Confirm"

**Code:**
```dart
Future<bool> validateStep3PeriodDate() async {
  if (currentStep == 8) {
    // Validate date constraints
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    questionsModel.step3.selectedLastPeriodDate = formattedDate;
    setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
    
    // Also calls subscription API with period date
    await PhoneVerificationService.createSubscriptionWithPeriodDate(...);
  }
}
```

**Line:** ~264 in `questions_list_screen.dart`

**Special Note:** Also calls `PhoneVerificationService.createSubscriptionWithPeriodDate()` to update subscription with period date.

---

#### **G. Step 9 - Cycle Length**
**Location:** `questions_list_screen.dart` - Skip button and confirm button

**When:** User selects cycle length or skips

**Code:**
```dart
// When skip button is clicked
if (currentStep == 9) {
  questionsModel.step4.selectedOption = DEFAULT_CYCLE_LENGTH;
  userStore.setCycleLength(DEFAULT_CYCLE_LENGTH);
  setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
}

// When confirm button is clicked (step 10)
if (currentStep == 9 && userStore.cycleLength == 0) {
  userStore.setCycleLength(DEFAULT_CYCLE_LENGTH);
  currentStep++;
  setState(() {});
}
```

**Lines:** ~567-573 (skip), ~462-467 (confirm) in `questions_list_screen.dart`

---

#### **H. Step 10 - Period Duration**
**Location:** `questions_list_screen.dart` - Skip button and confirm button

**When:** User selects period duration or skips

**Code:**
```dart
// When skip button is clicked
if (currentStep == 10) {
  questionsModel.step5.selectedOption = DEFAULT_PERIOD_LENGTH;
  userStore.setPeriodsLength(DEFAULT_PERIOD_LENGTH);
  setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
}

// When confirm button is clicked
if (currentStep == 10) {
  if (userStore.periodsLength == 0) {
    userStore.setPeriodsLength(DEFAULT_PERIOD_LENGTH);
  }
  setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
  currentStep++;
  setState(() {});
}
```

**Lines:** ~569-571 (skip), ~468-476 (confirm) in `questions_list_screen.dart`

---

#### **I. Step 11 - Age (Birth Year)**
**Location:** `questions_list_screen.dart` - Confirm and Skip buttons

**When:** User enters birth year or skips, then navigates to SignUpScreen

**Code:**
```dart
// When confirm button is clicked
if (currentStep == 11) {
  if (validateStep7()) {
    setValue(IS_USER_COMPLETED_QUE, true);
    setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
    SignUpScreen().launch(context);
  }
}

// When skip button is clicked
if (currentStep == 11) {
  setValue(IS_USER_COMPLETED_QUE, true);
  setValue(KEY_QUESTION_DATA, questionsModel.toJson()); // ✅ SAVED HERE
  SignUpScreen().launch(context);
}
```

**Lines:** ~477-483 (confirm), ~498-502 (skip) in `questions_list_screen.dart`

**Important:** Sets `IS_USER_COMPLETED_QUE = true` to mark onboarding as complete.

---

## How QuestionData is Used During Registration

### **1. SignUpScreen (App User Registration)**

**File:** `lib/screens/user/sign_up_screen.dart`

**When:** User completes onboarding and enters password/access code

**Usage:**
```dart
Future<void> _handleSignUp() async {
  // Get phone number from QuestionData
  String? phoneNumber = questionsModel.step2Phone.phoneNumber;
  String? countryCode = questionsModel.step2Phone.countryCode ?? "+1";
  
  // Login with phone and code
  final loginResult = await loginWithPhoneAndCode(
    phoneNumber: fullPhoneNumber,
    password: _passwordController.text.trim(),
    accessCode: _codeController.text.trim(),
  );
  
  // After successful login, update configuration using QuestionData
  await _updateConfiguration(userModel);
}

Future<void> _updateConfiguration(UserModel userModel) async {
  // Use QuestionData for cycle and period settings
  int cycleLength = userModel.cycleLength ?? 
      questionsModel.step4.selectedOption ?? 
      DEFAULT_CYCLE_LENGTH;
  int periodLength = userModel.periodLength ?? 
      questionsModel.step5.selectedOption ?? 
      DEFAULT_PERIOD_LENGTH;
  
  // Save to userStore and SharedPreferences
  userStore.setCycleLength(cycleLength);
  userStore.setPeriodsLength(periodLength);
  setValue(CYCLE_LENGTH, cycleLength);
  setValue(PERIOD_LENGTH, periodLength);
}
```

**Lines:** ~50-141 in `sign_up_screen.dart`

---

### **2. ProgressScreen (Anonymous User Registration)**

**File:** `lib/screens/user/progress_screen.dart`

**When:** User chooses anonymous registration path (not using phone login)

**Usage:**
```dart
Future<void> registerApiCall() async {
  // Load QuestionData from SharedPreferences
  Map<String, dynamic> map = getJSONAsync(KEY_QUESTION_DATA);
  QuestionsModel questionsModelData = QuestionsModel.fromJson(map);
  
  // Extract data from QuestionData
  final String fullName = questionsModel.step3PersonalInfo.fullName ?? 
      questionsModel.step7.answerToQuestion1 ?? 
      "Anonymous";
  
  final int age = questionsModel.step7.answerToQuestion2?.isNotEmpty == true
      ? getCurrentAgeFromYear(int.tryParse(questionsModel.step7.answerToQuestion2!)!)
      : 0;
  
  // Build registration request using QuestionData
  Map<String, dynamic> req = {
    "first_name": firstName,
    "last_name": lastName,
    "age": age,
    "email": randomEmail,
    "password": randomPassword,
    "goal_type": questionsModelData.step1.selectedOption == -1
        ? 0
        : questionsModelData.step1.selectedOption,
    "user_type": "anonymous_user",
    "period_start_date": questionsModelData.step3.selectedLastPeriodDate.isEmptyOrNull
        ? getDateTimeString(DateTime.now())
        : questionsModelData.step3.selectedLastPeriodDate.toString(),
    "cycle_length": questionsModelData.step4.selectedOption,
    "period_length": questionsModelData.step5.selectedOption,
    "luteal_phase": questionsModelData.step6.selectedOption != -1
        ? questionsModelData.step6.selectedOption
        : 0
  };
  
  // Call registration API
  final registerResult = await registerApi(req);
  
  // Update configuration using QuestionData
  updateConfiguration();
}

updateConfiguration() {
  Map<String, dynamic> map = getJSONAsync(KEY_QUESTION_DATA);
  QuestionsModel questionsModelData = QuestionsModel.fromJson(map);
  
  // Use QuestionData to configure MenstrualCycleWidget
  instance.updateConfiguration(
    cycleLength: questionsModelData.step4.selectedOption,
    periodDuration: questionsModelData.step5.selectedOption,
    customerId: userStore.userId.toString(),
    lastPeriodDate: lastPeriodDate,
  );
}
```

**Lines:** ~97-164 in `progress_screen.dart`

---

### **3. logInAsUserApi (Phone/Password Login)**

**File:** `lib/network/rest_api.dart`

**When:** User logs in with phone number and password (after completing onboarding)

**Usage:**
```dart
Future<UserResponse> logInAsUserApi(request) async {
  // Load QuestionData from SharedPreferences
  final Map<String, dynamic>? questionData = getJSONAsync(KEY_QUESTION_DATA);
  if (questionData == null || questionData.isEmpty) {
    throw Exception('Cannot construct user data: Question data not found. Please complete onboarding first.');
  }
  
  final QuestionsModel questionsModelData = QuestionsModel.fromJson(questionData);
  
  // Extract name from QuestionData
  String? fullName = questionsModelData.step3PersonalInfo.fullName;
  List<String> nameParts = fullName?.trim().split(' ') ?? [];
  String firstName = nameParts.isNotEmpty ? nameParts.first : '';
  String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
  
  // Extract email
  String? email = questionsModelData.step3PersonalInfo.email ?? '';
  
  // Extract age
  int age = 0;
  if (questionsModelData.step7.answerToQuestion2?.isNotEmpty == true) {
    age = getCurrentAgeFromYear(int.tryParse(questionsModelData.step7.answerToQuestion2!) ?? 0);
  }
  
  // Construct UserModel using QuestionData
  final Map<String, dynamic> userDataMap = {
    'id': 0,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'age': age,
    'phone_number': phoneForAPI,
    'goal_type': questionsModelData.step1.selectedOption ?? 0,
    'user_type': 'app_user',
    'period_start_date': questionsModelData.step3.selectedLastPeriodDate?.isNotEmpty == true
        ? questionsModelData.step3.selectedLastPeriodDate
        : getDateTimeString(DateTime.now()),
    'cycle_length': questionsModelData.step4.selectedOption ?? DEFAULT_CYCLE_LENGTH,
    'period_length': questionsModelData.step5.selectedOption ?? DEFAULT_PERIOD_LENGTH,
    'luteal_phase': questionsModelData.step6.selectedOption != -1 
        ? questionsModelData.step6.selectedOption 
        : 0,
    'api_token': sanctumToken,
    'status': 'active',
  };
}
```

**Lines:** ~225-272 in `rest_api.dart`

---

## Data Persistence

### **Storage Mechanism:**
- **Storage Type:** SharedPreferences
- **Key:** `KEY_QUESTION_DATA` (constant defined in `app_constants.dart`)
- **Format:** JSON string (converted from `QuestionsModel.toJson()`)

### **Storage Method:**
```dart
// Save
await setValue(KEY_QUESTION_DATA, questionsModel.toJson());

// Load
Map<String, dynamic> map = getJSONAsync(KEY_QUESTION_DATA);
QuestionsModel questionsModel = QuestionsModel.fromJson(map);
```

### **Persistence Points:**
1. After each step completion (incremental saves)
2. Before navigation to next screen
3. After API calls (subscription, registration)

---

## Summary Table: When Data is Stored

| Step | Screen/Widget | When Stored | Line Reference |
|------|---------------|-------------|----------------|
| Step 1 | `questions_list_screen.dart` | When moving to Step 2 | ~122 |
| Step 2 | `questions_list_screen.dart` | When goal type selected | ~122 |
| Step 3 | `phone_verification_widget.dart` | After phone verification | ~170, ~211 |
| Step 4 | `personal_info_widget.dart` | After name/email entered | ~113, ~163 |
| Step 5 | `questions_list_screen.dart` | After Question 1 answered | ~134 |
| Step 6 | `questions_list_screen.dart` | After Question 2 answered | ~146 |
| Step 7 | `questions_list_screen.dart` | After Question 3 answered | ~160 |
| Step 8 | `questions_list_screen.dart` | After period date selected | ~264 |
| Step 9 | `questions_list_screen.dart` | After cycle length selected/skipped | ~567, ~473 |
| Step 10 | `questions_list_screen.dart` | After period duration selected/skipped | ~569, ~473 |
| Step 11 | `questions_list_screen.dart` | Before navigating to SignUpScreen | ~481, ~500 |

---

## Summary Table: When Data is Used

| Use Case | File | Purpose | Line Reference |
|----------|------|---------|----------------|
| Sign Up | `sign_up_screen.dart` | Get phone number, update configuration | ~56, ~118-141 |
| Anonymous Registration | `progress_screen.dart` | Build registration request, configure widget | ~103-139, ~69-91 |
| Phone Login | `rest_api.dart` | Construct UserModel from QuestionData | ~226-272 |
| Settings Screen | `user_setting_screen.dart` | Load and display user's onboarding data | ~276-293 |
| Period Prediction | `period_prediction_screen.dart` | Load cycle/period data | ~151-153 |

---

## Key Points

1. **Incremental Saving:** QuestionData is saved after each step completion, not just at the end
2. **Multiple Save Points:** Data is saved at least 11+ times during onboarding
3. **Used for Registration:** QuestionData is essential for both anonymous and app user registration
4. **Used for Configuration:** QuestionData is used to configure cycle tracking widgets
5. **Persistence:** Data persists in SharedPreferences and survives app restarts
6. **Validation:** Data is validated before saving at each step
7. **API Integration:** Some steps trigger API calls (subscription) before saving

---

## Flow Diagram

```
┌─────────────────┐
│  Splash Screen  │
└────────┬────────┘
         │ (Not logged in)
         ▼
┌─────────────────────┐
│ QuestionsListScreen │
│   (Onboarding)      │
└────────┬────────────┘
         │
         ├─ Step 1 → Save ✅
         ├─ Step 2 → Save ✅
         ├─ Step 3 → Save ✅ (Phone Verified)
         ├─ Step 4 → Save ✅ (Name/Email)
         ├─ Step 5 → Save ✅ (Q1)
         ├─ Step 6 → Save ✅ (Q2)
         ├─ Step 7 → Save ✅ (Q3 + Subscription API)
         ├─ Step 8 → Save ✅ (Period Date + Subscription API)
         ├─ Step 9 → Save ✅ (Cycle Length)
         ├─ Step 10 → Save ✅ (Period Duration)
         └─ Step 11 → Save ✅ (Age)
         │
         ▼
┌─────────────────┐
│  SignUpScreen   │
│  (App Users)    │
└────────┬────────┘
         │ Uses QuestionData
         │ - Phone number
         │ - Cycle/Period settings
         ▼
┌─────────────────┐
│  Dashboard      │
└─────────────────┘

OR

┌─────────────────┐
│ ProgressScreen  │
│ (Anonymous)     │
└────────┬────────┘
         │ Uses QuestionData
         │ - All registration data
         │ - Widget configuration
         ▼
┌─────────────────┐
│  Dashboard      │
└─────────────────┘
```

---

## Important Notes

1. **QuestionData is Required:** Both registration paths (`SignUpScreen` and `ProgressScreen`) require QuestionData to exist
2. **Error Handling:** If QuestionData is missing during login, an error is thrown: "Cannot construct user data: Question data not found"
3. **Default Values:** If optional fields are skipped, defaults are used (DEFAULT_CYCLE_LENGTH = 28, DEFAULT_PERIOD_LENGTH = 5)
4. **API Calls:** Subscription APIs are called during onboarding (Steps 7 and 8) to sync data with backend
5. **Completion Flag:** `IS_USER_COMPLETED_QUE` is set to `true` when onboarding is complete (Step 11)




















