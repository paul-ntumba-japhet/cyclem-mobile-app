# Forgot Password via Firebase OTP (Procedure)

This document defines the full implementation procedure to replace the current "forgot password" OTP sending logic with Firebase Phone Authentication.

## Goal

When the user taps **Forgot password**, the app must:

1. Validate the account/phone association.
2. Send a **6-digit OTP** using Firebase to the client's registered phone number.
3. Verify the OTP.
4. Allow password reset only after successful verification.

No password reset is allowed without a valid Firebase OTP verification step.

## Scope

- Replace only the OTP delivery/verification part of the "forgot password" flow.
- Keep existing sign-in behavior unchanged.
- Keep existing backend password update endpoint, but enforce OTP verification token/session before reset.

## Preconditions

- Firebase is already configured for Android and iOS.
- `firebase_auth` is available in the app.
- The backend can return the user's registered phone number (or masked phone) from username/email/phone lookup.

## High-Level Flow

1. User taps **Forgot password**.
2. User enters account identifier (phone/email/username depending on current UI).
3. App requests account recovery data from backend:
   - Confirm account exists.
   - Return the **registered phone** for this account (or a masked version + internal ID).
4. App starts Firebase phone verification on that registered number.
5. Firebase sends OTP SMS (6 digits).
6. User enters OTP.
7. App verifies OTP with Firebase credential.
8. If verification succeeds, app obtains a temporary reset authorization from backend.
9. User enters new password + confirmation.
10. App submits reset request with reset authorization.
11. Backend updates password and invalidates the reset authorization.

## Detailed Procedure

### Phase 1: UI Entry Point

1. Add/confirm a **Forgot password** action in `sign_in_screen`.
2. Route to a dedicated recovery screen:
   - Suggested: `forgot_password_screen.dart`.
3. The screen must include:
   - Account identifier input.
   - "Send code" button.
   - OTP input (6 digits, initially hidden/disabled).
   - "Verify code" button.
   - New password + confirm password fields (shown only after OTP verified).
   - "Reset password" button.

### Phase 2: Account and Phone Validation

1. Create/confirm backend endpoint to initiate recovery (example):
   - `POST /auth/recovery/init`
2. Request payload:
   - `identifier` (email/phone/username from UI).
3. Response payload should include:
   - `recoveryId` (server-generated, short-lived).
   - `phoneMasked` (for UI confirmation).
   - `phoneE164` (optional; preferred if safe and required by app).
4. Security rules:
   - Do not reveal whether the account exists in explicit error text.
   - Use generic message: "If this account exists, a code will be sent."

### Phase 3: Send OTP with Firebase

1. Build a dedicated service:
   - Suggested: `phone_recovery_service.dart`.
2. On "Send code":
   - Use `FirebaseAuth.verifyPhoneNumber(...)`.
   - Use registered phone from Phase 2 (never user-typed number if different).
3. Handle callbacks:
   - `verificationCompleted`: auto-retrieval path (Android).
   - `verificationFailed`: map Firebase errors to user-safe messages.
   - `codeSent`: store `verificationId` and enable OTP input.
   - `codeAutoRetrievalTimeout`: keep manual OTP option.
4. Timer and resend:
   - Start 60-second countdown.
   - Disable resend until timer ends.
   - Reuse `resendToken` when available.

### Phase 4: Verify OTP

1. Validate OTP format before submit:
   - Exactly 6 digits.
2. Create credential:
   - `PhoneAuthProvider.credential(verificationId, smsCode)`.
3. Verify by signing in with credential:
   - `FirebaseAuth.instance.signInWithCredential(...)`.
4. On success:
   - Mark `isOtpVerified = true`.
   - Immediately sign out temporary Firebase user if app should not keep this auth session.

### Phase 5: Exchange Verification for Reset Authorization

1. After Firebase OTP success, call backend endpoint (example):
   - `POST /auth/recovery/verify`
2. Send:
   - `recoveryId`
   - Firebase proof data (`uid`, `idToken`, or verification assertion agreed with backend).
3. Backend validates Firebase proof and returns:
   - `resetToken` (short-lived, one-time-use).

### Phase 6: Reset Password

1. Show new password form only when `isOtpVerified = true`.
2. Validate:
   - Password policy (length/complexity).
   - Confirmation matches.
3. Call backend reset endpoint (example):
   - `POST /auth/recovery/reset`
4. Send:
   - `resetToken`
   - `newPassword`
   - `confirmPassword` (if backend expects it)
5. On success:
   - Show confirmation.
   - Navigate to sign-in screen.
   - Invalidate local recovery session state.

## Data and State Design

Maintain one in-memory/session object for recovery:

- `identifier`
- `recoveryId`
- `registeredPhoneMasked`
- `verificationId`
- `resendToken`
- `isCodeSent`
- `isOtpVerified`
- `resetToken`
- `expiresAt`

Clear this object on:

- Screen exit/back.
- Successful reset.
- Timeout or too many failed attempts.

## Error Handling Matrix

1. **Invalid phone format from backend data**
   - Show technical-safe error.
   - Log for support.
2. **Firebase `too-many-requests`**
   - Block resend temporarily and display wait message.
3. **Wrong OTP**
   - Allow retry with attempt limit.
4. **Expired OTP**
   - Ask user to resend code.
5. **Network failure**
   - Keep state and allow retry without restarting flow.
6. **Backend reject after Firebase success**
   - Treat as security failure; restart recovery.

## Security Requirements

- Never trust client-only OTP verification for password reset authorization.
- Backend must verify Firebase token/proof before issuing `resetToken`.
- `resetToken` must be:
  - Short-lived (recommended: 5-10 minutes).
  - One-time-use.
  - Bound to the specific account and recovery session.
- Add rate-limits on:
  - Recovery initiation.
  - OTP verification attempts.
  - Password reset attempts.
- Do not log full phone numbers or OTP codes.

## UI/UX Requirements

- Show masked phone confirmation (example: `+243 *** ** 32`).
- Disable primary buttons while requests are in progress.
- Keep messages simple:
  - "Code sent"
  - "Invalid code"
  - "Code expired, resend"
- Support manual OTP entry even when auto-retrieval fails.

## Test Plan (Before Production)

1. Happy path: valid account -> OTP -> verify -> reset success.
2. Wrong OTP (multiple times) -> lockout/rate-limit behavior.
3. OTP timeout -> resend -> success.
4. Nonexistent account -> generic response only.
5. Network interruption during each phase.
6. App background/foreground during OTP wait.
7. Android auto-retrieval and iOS manual-only flow.
8. Ensure old OTP mechanism is no longer used anywhere in forgot-password flow.

## Implementation Checklist

- [ ] Add recovery UI screen/flow wiring from sign-in.
- [ ] Add recovery state model/controller.
- [ ] Integrate Firebase `verifyPhoneNumber` for forgot-password path.
- [ ] Implement OTP verify action with 6-digit validation.
- [ ] Add backend endpoints (`init`, `verify`, `reset`) or map to existing ones.
- [ ] Add resend timer and attempt limits.
- [ ] Add analytics/logging events (without sensitive data).
- [ ] Add widget/unit/integration tests for the recovery flow.
- [ ] Remove/disable old OTP sender for forgot-password path.
- [ ] Final QA on Android and iOS.

## Definition of Done

The feature is done when:

1. "Forgot password" sends OTP through Firebase to the registered phone.
2. OTP must be 6 digits and must verify successfully.
3. Password reset works only after verified OTP.
4. Previous OTP mechanism is fully replaced for this flow.
5. Security and rate-limiting checks pass QA.
