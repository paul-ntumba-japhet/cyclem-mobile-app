````md
# Cursor Task Brief — Mobile Payment State Management and Waiting Animations (Flutter)

## Objective

Implement a robust and professional mobile payment flow in Flutter using the following APIs:

1. `initializeMobilePaymentApi`  
   Used to initialize the mobile payment immediately after the user taps the mobile payment button.

2. `validateMobilePaymentApi`  
   Used to validate the payment by sending the `sysTID` returned by `initializeMobilePaymentApi`.

A payment is considered **successful only when** `responsecode == "004"`.

The UX must feel clear, professional, modern, and reassuring, especially during the delay before the USSD window appears.

---

# Functional Requirements

## 1. Payment Flow Overview

The payment flow must follow these steps:

### Step 1 — User taps the payment button
- Immediately call `initializeMobilePaymentApi`.
- Display the existing loading animation already available in the application.
- Show the message:

```text
Initialisation du paiement
````

* Disable the payment button during this phase to prevent duplicate taps.
* As soon as `initializeMobilePaymentApi` returns an HTTP status `200`, remove the first loading animation.

---

## 2. Start Payment Validation Polling

After `initializeMobilePaymentApi` succeeds:

* Extract the `sysTID` returned by the API.
* Start polling with `validateMobilePaymentApi`.
* The first validation request must be sent **3 seconds after** the initialization success.
* After that, continue polling **every 3 seconds**.
* Stop polling after a total timeout of **60 seconds**.

---

## 3. Payment Success Rule

For every polling response from `validateMobilePaymentApi`:

* Check `responsecode`.
* The payment is valid and successful **only if**:

```text
responsecode == "004"
```

If `responsecode` is not `004`, continue polling until:

* success is reached, or
* timeout is reached.

---

# State Management Requirements

Implement a clear state machine for the payment flow.

## Recommended Payment States

Use an enum similar to this:

```dart
enum MobilePaymentState {
  idle,
  initializing,
  waitingForUssd,
  confirming,
  success,
  failed,
  timeout,
}
```

---

## State Transition Logic

### `idle`

Default state before payment starts.

### `initializing`

Set this state immediately after the user taps the payment button.

Actions:

* call `initializeMobilePaymentApi`
* disable payment button
* show existing loading animation
* display:

```text
Initialisation du paiement
```

### `waitingForUssd`

Set this state once initialization succeeds with status `200`.

Actions:

* remove the first loading animation
* begin polling process
* show sequential waiting messages
* keep payment button disabled

### `confirming`

Use this state during payment status verification while polling is active.

Display a professional animation using:

* `AnimatedSwitcher`, or
* a modern professional progress bar

### `success`

Set this state only when `validateMobilePaymentApi` returns:

```text
responsecode == "004"
```

### `timeout`

Set this state when polling reaches 60 seconds without success.

### `failed`

Use this state for:

* initialization failure
* validation request failure
* unexpected exceptions
* invalid unrecoverable responses

---

# Waiting Messages Sequence

During the waiting period before the USSD window appears and during validation, show the following messages in sequence:

## Message 1

```text
Ouverture de la fenêtre USSD
```

## Message 2

```text
Veuillez confirmer le code PIN sur votre téléphone
```

## Message 3

```text
Vérification du paiement en cours...
```

These messages must be displayed progressively and professionally while polling is running.

---

# Animation Requirements

## During Initialization

Use the loading animation already present in the application.

Message to display:

```text
Initialisation du paiement
```

## During Payment Validation / Waiting

Use one of the following:

* `AnimatedSwitcher`
* a modern and professional progress bar

The animation must visually communicate that:

* the app is waiting for the USSD interaction
* the payment is being checked in the background
* the user should remain patient and not tap again

---

# Button Behavior

## Before payment starts

* button enabled

## During initialization

* button disabled

## During polling / waiting for USSD

* button still disabled

## After success / failure / timeout

* button can be re-enabled depending on the final UX decision

Important: the user must never be able to launch multiple payment requests while one payment is already in progress.

---

# Polling Rules

## Trigger

Start polling only after `initializeMobilePaymentApi` succeeds and returns status `200`.

## Polling Schedule

* first call to `validateMobilePaymentApi`: after `3 seconds`
* then: every `3 seconds`
* total timeout: `60 seconds`

## Validation Rule

At each polling call:

* read `responsecode`
* if `responsecode == "004"`, mark payment as successful and stop polling
* otherwise continue until timeout

---

# UX Guidelines

The waiting experience must feel controlled and trustworthy.

The user must clearly understand that:

* payment initialization is in progress
* the USSD window may take a few seconds to appear
* PIN confirmation must happen on the phone
* payment status is being checked automatically

Avoid a frozen or silent screen.

The UI should always communicate the current step of the payment process.

---

# Technical Expectations

Implement the flow in a clean and reusable way.

Recommended approach:

* use a dedicated payment controller, cubit, bloc, notifier, or provider
* isolate polling logic in a reusable method
* centralize payment state updates
* avoid duplicate timers or overlapping validation requests

---

# Expected Flow Summary

## On payment button tap

1. disable button
2. set state to `initializing`
3. call `initializeMobilePaymentApi`
4. show existing animation with message:

```text
Initialisation du paiement
```

## If initialization succeeds with status 200

1. remove the first animation
2. extract `sysTID`
3. switch to waiting/confirming flow
4. start polling with `validateMobilePaymentApi`
5. first poll after 3 seconds
6. continue every 3 seconds
7. stop after 60 seconds timeout

## During polling

Display these sequential messages:

* `Ouverture de la fenêtre USSD`
* `Veuillez confirmer le code PIN sur votre téléphone`
* `Vérification du paiement en cours...`

Use `AnimatedSwitcher` or a modern progress bar for the waiting animation.

## If validation returns `responsecode == "004"`

* stop polling
* set payment as success

## If timeout is reached

* stop polling
* set state to timeout

## If an error occurs

* stop polling
* set state to failed

---

# Final Quality Requirement

The payment flow must feel:

* premium
* clear
* responsive
* professional
* safe
* production-ready

The user must never feel that the app is frozen while waiting for the USSD popup or payment confirmation.

```
```
