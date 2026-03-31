# Phone Verification Implementation Guide

This guide explains how to add phone number verification with OTP to the onboarding flow after step 2.

## Overview

**Location:** After Step 2 (Goal Type selection), before Step 3 (Period Date)
**Requirement:** Mandatory step - user cannot proceed without verifying phone number
**Method:** Firebase Phone Authentication with OTP

## Required Dependencies

Add these to `pubspec.yaml`:

```yaml
dependencies:
  # Phone Authentication (already have firebase_auth, but may need updates)
  firebase_auth: ^5.5.3  # Already included
  
  # OTP Input Field
  pin_code_fields: ^8.0.1  # For OTP input UI
  
  # Phone Number Formatting (optional but recommended)
  phone_numbers_parser: ^4.0.0  # For phone number validation and formatting
```

**Note:** `country_code_picker` is already included in your dependencies.

## Implementation Steps

### Step 1: Update Questions Model

**File:** `lib/model/user/question_model.dart`

Add a new step for phone verification:

```dart
class QuestionsModel {
  Step1 step1;
  Step2 step2;
  Step2Phone step2Phone;  // NEW: Phone verification step
  Step3 step3;
  Step4 step4;
  Step5 step5;
  Step6 step6;
  Step7 step7;

  QuestionsModel({
    required this.step1,
    required this.step2,
    required this.step2Phone,  // NEW
    required this.step3,
    required this.step4,
    required this.step5,
    required this.step6,
    required this.step7,
  });

  factory QuestionsModel.fromJson(Map<String, dynamic> json) {
    return QuestionsModel(
      step1: Step1.fromJson(json['step1']),
      step2: Step2.fromJson(json['step2']),
      step2Phone: Step2Phone.fromJson(json['step2Phone'] ?? {}),  // NEW
      step3: Step3.fromJson(json['step3']),
      step4: Step4.fromJson(json['step4']),
      step5: Step5.fromJson(json['step5']),
      step6: Step6.fromJson(json['step6']),
      step7: Step7.fromJson(json['step7']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step1': step1.toJson(),
      'step2': step2.toJson(),
      'step2Phone': step2Phone.toJson(),  // NEW
      'step3': step3.toJson(),
      'step4': step4.toJson(),
      'step5': step5.toJson(),
      'step6': step6.toJson(),
      'step7': step7.toJson(),
    };
  }
}

// NEW: Phone Verification Step Model
class Step2Phone {
  String? phoneNumber;
  String? countryCode;
  String? verificationId;
  bool? isVerified;
  String? otpCode;

  Step2Phone({
    this.phoneNumber,
    this.countryCode,
    this.verificationId,
    this.isVerified = false,
    this.otpCode,
  });

  factory Step2Phone.fromJson(Map<String, dynamic> json) {
    return Step2Phone(
      phoneNumber: json['phoneNumber'],
      countryCode: json['countryCode'],
      verificationId: json['verificationId'],
      isVerified: json['isVerified'] ?? false,
      otpCode: json['otpCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': this.phoneNumber,
      'countryCode': this.countryCode,
      'verificationId': this.verificationId,
      'isVerified': this.isVerified,
      'otpCode': this.otpCode,
    };
  }
}
```

### Step 2: Create Phone Verification Service

**File:** `lib/service/phone_verification_service.dart` (NEW FILE)

```dart
import 'package:firebase_auth/firebase_auth.dart';
import '../extensions/extensions.dart';

class PhoneVerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send OTP to phone number
  Future<String?> sendOTP(String phoneNumber, String countryCode) async {
    try {
      appStore.setLoading(true);
      
      // Format phone number with country code
      String fullPhoneNumber = '$countryCode$phoneNumber';
      
      // Remove any spaces or special characters
      fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Ensure it starts with +
      if (!fullPhoneNumber.startsWith('+')) {
        fullPhoneNumber = '+$fullPhoneNumber';
      }

      // Send verification code
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed (Android only)
          appStore.setLoading(false);
        },
        verificationFailed: (FirebaseAuthException e) {
          appStore.setLoading(false);
          toast(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          appStore.setLoading(false);
          // Return verification ID for later use
          return verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          appStore.setLoading(false);
        },
        timeout: const Duration(seconds: 60),
      );
      
      return null; // Will be handled in codeSent callback
    } catch (e) {
      appStore.setLoading(false);
      toast('Error sending OTP: ${e.toString()}');
      return null;
    }
  }

  /// Verify OTP code
  Future<bool> verifyOTP(String verificationId, String otpCode) async {
    try {
      appStore.setLoading(true);
      
      // Create credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );

      // Sign in with credential
      await _auth.signInWithCredential(credential);
      
      appStore.setLoading(false);
      return true;
    } catch (e) {
      appStore.setLoading(false);
      toast('Invalid OTP code. Please try again.');
      return false;
    }
  }

  /// Resend OTP
  Future<String?> resendOTP(String phoneNumber, String countryCode) async {
    return await sendOTP(phoneNumber, countryCode);
  }
}
```

### Step 3: Create Phone Verification Widget

**File:** `lib/screens/user/widgets/phone_verification_widget.dart` (NEW FILE)

This will be created in the next step with full implementation.

### Step 4: Update Questions List Screen

**File:** `lib/screens/user/questions_list_screen.dart`

**Changes needed:**

1. **Initialize step2Phone in questionsModel:**
   - Add step2Phone initialization
   - Update step counting logic

2. **Add phone verification step rendering:**
   - Add `step2Phone()` widget method
   - Show it when `currentStep == 2.5` or `currentStep == 3` (adjust numbering)

3. **Update navigation logic:**
   - After step 2, go to phone verification
   - After phone verification, go to step 3
   - Make phone verification mandatory (no skip)

4. **Update progress indicator:**
   - Adjust for new step

### Step 5: Update Registration API

**File:** `lib/network/rest_api.dart`

The registration API already accepts `phoneNumber` in UserModel, so no changes needed unless you want to add phone verification status.

## Detailed Implementation

See the attached files for complete implementation:
- `phone_verification_widget.dart` - Complete phone verification UI
- Updated `question_model.dart` - With Step2Phone
- Updated `questions_list_screen.dart` - With phone verification integration

## Firebase Configuration

### Android Setup

**File:** `android/app/build.gradle`

Ensure Firebase is properly configured (should already be done).

### iOS Setup

**File:** `ios/Runner/Info.plist`

Add phone authentication capability (if not already present).

## Testing

1. Test with valid phone numbers
2. Test OTP reception
3. Test invalid OTP handling
4. Test resend OTP functionality
5. Test mandatory validation (cannot skip)

## UI/UX Considerations

- Match existing app design (mainColorLight, mainColorText, etc.)
- Use country code picker for phone input
- Show loading state during OTP send
- Clear error messages
- Resend OTP option with countdown timer
- Professional, clean interface matching app style
²² 