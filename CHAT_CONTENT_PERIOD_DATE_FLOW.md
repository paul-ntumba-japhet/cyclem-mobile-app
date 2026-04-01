# Chat Content Flow Based on Menstrual Period Date

This document explains how `ikchatbot_screen.dart` decides what to display in chat based on the user's `dateRegle` (last period date), and how content/feed is loaded after date input.

## File Concerned

- `lib/screens/user/ikchatbot_screen.dart`

## 1) Startup Sequence

When the screen opens, `initState()` runs this order:

1. Load saved chat history from phone-scoped storage (`_loadChatHistory`).
2. Run period-date gate check (`_checkRegistrationPeriodDateRequirement`).
3. If there are no messages and chat is allowed, fetch welcome feed (`_fetchInitialWelcomeMessage`).

## 2) Which `dateRegle` Is Used

The gate check reads cycle data in this order:

1. `userStore.cycleInfo`
2. Fallback: global shared-pref `KEY_CYCLE_INFO`

Then it evaluates:

- Missing date (`''`)
- Placeholder date (`2025-01-01`)
- Placeholder code (`S1`)
- Expired date (`> 32` days old) using `isPeriodDateWithin32Days(...)`

## 3) Gate Outcomes (What Message Appears)

### A) No valid submitted date

If date is empty / placeholder, chat is blocked and shows:

- Message: `language.chatPeriodDateRequiredMessage`
- Smart reply: `language.chatSubmitDateButton`
- `responseKey`: `registration_period_required`

### B) Date exists but is older than 32 days

If date exists but is expired, chat is blocked and shows:

- Message: `language.chatRefreshCycleMessage`
- Smart reply: `language.chatRefreshCycleButton`
- `responseKey`: `refresh_cycle_required`

### C) Valid recent date

Chat is enabled and normal bot feed can run.

## 4) Date Picker and Date Submission Path

When user taps the smart reply button, `_showDatePicker(...)`:

1. Opens date picker (today to 33 days back).
2. Validates selected date.
3. Inserts selected date as user message in chat.
4. Inserts loading bubble.
5. Routes:
   - `registration_period_required` or `refresh_cycle_required` -> `_submitRegistrationPeriodDate(...)`
   - `cycle_eligible` input flow -> `_sendDateInput(...)`

## 5) How Chat Feed Is Displayed After Date

### `_sendDateInput(date, key)`

This function calls:

- `sendChatMessageApi(...)` with:
  - `currentKey: key`
  - `input: date`

Then updates chat UI by:

1. Removing loading bubble.
2. Inserting bot message (`response.text`).
3. Inserting smart replies from `response.choices`.
4. Saving chat history.

## 6) Registration/Refresh Date Save Path

### `_submitRegistrationPeriodDate(formattedDate)`

When save succeeds:

1. Calls `PhoneVerificationService.createSubscriptionWithPeriodDate(...)`.
2. Updates local cycle state:
   - `userStore.setPeriodDate(...)`
   - `userStore.setCycleInfo(updatedCycleInfo)`
   - `saveCycleInfoForPhone(...)`
3. Clears chat state and gate lock:
   - `_requiresRegistrationPeriodDate = false`
   - `_messages.clear()`
4. Triggers app refresh signal:
   - `appStore.setHomeScreenUpdated(true)`
5. Fetches fresh welcome message.

## 7) Instant Refresh Hook for External Updates

A reaction is set in `initState()`:

- Watches `appStore.isHomeScreenUpdated`
- On `true`, `_refreshChatAfterCycleUpdate()`:
  - Removes stale gate prompts
  - Re-runs period-date requirement check
  - Fetches welcome if chat is now allowed and empty

This is why chat can refresh after payment/date updates.

## 8) Practical Debug Notes

The helper `_debugPrintDateRegleUsedInChat(...)` prints:

- source used (`userStore.cycleInfo` vs `KEY_CYCLE_INFO`)
- raw date used by chat
- values from both store and shared pref

Use this when chat content does not match expected date state.
