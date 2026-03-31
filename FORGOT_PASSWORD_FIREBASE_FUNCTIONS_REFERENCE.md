# Forgot Password Firebase Flow - Function Reference

This file documents the concrete functions used by the implemented forgot-password flow.

## 1) Screen Entry and Navigation

### `UserSignInScreen` -> Forgot Password entry
- **Location:** `lib/screens/user/sign_in_screen.dart`
- **Call site:** `ForgotPasswordPhoneScreen().launch(context);`
- **Purpose:** opens the phone-based recovery screen when user taps "Forgot password?"

### `ResetPasswordScreen(...).launch(context)`
- **Location:** `lib/screens/user/forgot_password_phone_screen.dart`
- **Purpose:** navigates to reset screen only after Firebase OTP verification succeeds.
- **Parameters used:**
  - `phoneNumber`: full phone string (dial code + local digits)
  - `isFirebaseVerified: true`

## 2) Firebase Recovery Functions

### `Future<void> _submitPhoneNumber()`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** validates phone input and starts first OTP send.
- **Main operations:**
  1. validate form and local phone format.
  2. call `_requestFirebaseCode(isResend: false)`.

### `Future<void> _resendCode()`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** resends OTP only when cooldown reaches zero.
- **Rule:** no resend while loading/verifying/cooldown active.

### `Future<void> _requestFirebaseCode({required bool isResend})`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** central sender for Firebase OTP (initial send + resend).
- **Main operations:**
  1. build full phone and E.164.
  2. call `ensureFirebaseInitialized()`.
  3. call `FirebaseAuth.instance.verifyPhoneNumber(...)`.
  4. store `verificationId` and `resendToken`.
  5. start cooldown via `_startResendCooldown()`.

### `Future<void> _verifyCode(String fullPhoneNumber)`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** validates 6-digit code and verifies by credential.
- **Main operations:**
  1. enforce `enteredCode.length == 6`.
  2. build `PhoneAuthProvider.credential(...)`.
  3. call `_finishAfterPhoneVerified(credential)`.

### `Future<void> _finishAfterPhoneVerified(PhoneAuthCredential credential)`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** final Firebase credential sign-in gate.
- **Main operations:**
  1. `FirebaseAuth.instance.signInWithCredential(credential)`.
  2. `FirebaseAuth.instance.signOut()` (cleanup temporary session).
  3. navigate to `ResetPasswordScreen` with `isFirebaseVerified: true`.

### `String _e164Phone(String fullPhoneNumber)`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** converts phone to E.164-compatible digits (`+` + numeric digits).

### `String _firebaseAuthMessage(FirebaseAuthException e)`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** maps Firebase error codes to user-facing messages.

## 3) OTP Cooldown and UI State Helpers

### `void _startResendCooldown()`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** starts 60-second resend timer.
- **State updated:** `_secondsUntilResend`, `_resendTimer`.

### `String get _resendLabel`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** returns dynamic button text:
  - `Resend code in Ns`
  - `Resend code`

### `String _maskedPhone(String fullPhoneNumber)`
- **Location:** `ForgotPasswordPhoneScreen`
- **Purpose:** masks the destination phone shown in UI after code send.

## 4) Password Reset Guard and API Call

### `Future<void> _resetPassword()`
- **Location:** `lib/screens/user/reset_password_screen.dart`
- **Purpose:** validates password fields and sends reset request.
- **Security gate:** exits early unless `widget.isFirebaseVerified == true`.
- **Main operations:**
  1. local password validation.
  2. call `resetPassword(phoneNumber: ..., newPassword: ...)`.
  3. on success, route back to sign-in.

### `Future<Map<String, dynamic>> resetPassword({required String phoneNumber, required String newPassword})`
- **Location:** `lib/network/rest_api.dart`
- **Purpose:** performs backend password update (`actionDem: "ResetPassAct"`).
- **Important request fields:**
  - `username`: normalized digits-only phone.
  - `password`: new password.
  - `codeAcces`: currently empty string.
  - `actionDem`: `ResetPassAct`.

## 5) Shared Firebase Bootstrap

### `Future<void> ensureFirebaseInitialized()`
- **Location:** `lib/main.dart`
- **Purpose:** initializes Firebase once safely before phone verification calls.

## 6) Runtime Call Sequence

1. Sign-in screen -> `ForgotPasswordPhoneScreen`.
2. User taps Continue -> `_submitPhoneNumber()`.
3. `_requestFirebaseCode(false)` -> `verifyPhoneNumber`.
4. User enters 6-digit OTP -> `_verifyCode(...)`.
5. `_finishAfterPhoneVerified(...)` signs in with credential and signs out.
6. Navigate to reset screen with `isFirebaseVerified: true`.
7. User submits new password -> `_resetPassword()`.
8. `_resetPassword()` -> `resetPassword(...)` API.
9. Success -> return to sign-in screen.

## 7) Notes

- This implementation fully uses Firebase for OTP sending/verification in forgot-password flow.
- Old direct OTP providers are not used in this flow.
- `ResetPasswordScreen` now has a verification guard to prevent direct reset access without Firebase verification.
