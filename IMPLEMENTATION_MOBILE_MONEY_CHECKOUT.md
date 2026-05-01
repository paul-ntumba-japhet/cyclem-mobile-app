````md
# Cursor Task Brief — Premium Mobile Money Checkout (Flutter)

## Objective

Create a premium, modern, highly attractive mobile money checkout screen in Flutter for users in the Democratic Republic of Congo.

The screen must feel production-ready, elegant, trustworthy, high-converting, and visually polished.

Use clean architecture, reusable widgets, responsive layout, smooth animations, and maintainable code.

---

# Main Tasks

## 1. Create Reusable Function

Create a reusable helper:

```dart
String getMobileOperator(String phoneNumber)
````

This function receives a phone number and returns the correct operator name based on the first 5 digits.

### Rules

If the first 5 digits are:

* 24382
* 24381
* 24386

Return:

```dart
"MPESA"
```

---

If the first 5 digits are:

* 24399
* 24398
* 24397
* 24396

Return:

```dart
"Airtel Money"
```

---

If the first 5 digits are:

* 24380
* 24384
* 24385
* 24389

Return:

```dart
"Orange Money"
```

---

If no match:

```dart
"Unknown Operator"
```

---

## 2. Checkout Screen UI

Build a premium checkout page using the operator returned by `getMobileOperator()`.

---

# Header Section

## Title

Display operator name dynamically:

Examples:

* MPESA
* Airtel Money
* Orange Money

---

## Subtitle

Display mobile network name:

| Operator     | Subtitle |
| ------------ | -------- |
| MPESA        | Vodacom  |
| Airtel Money | Airtel   |
| Orange Money | Orange   |

---

## Logo

Display the correct logo dynamically.

Use local assets:

```text
assets/images/mpesa.png
assets/images/airtel.png
assets/images/orange.png
```

---

## Masked User Phone Number

Examples:

```text
24382*****21
24399*****67
24380*****12
```

---

# 3. Payment Plans

Create elegant selectable pricing cards.

Only one plan selectable at a time.

---

## Trial Plan

### Title

Trial

### Price

0$

### Features

* Basic features
* Trial duration: 3 days

---

## Monthly Plan

### Title

Monthly

### Price

8.999$ / month

### Features

* Full premium access
* Personalized advice
* Advanced notifications
* Support

---

## Annual Plan (Highlighted)

### Title

Annual

### Price

69.999$

### Show Savings Percentage

Calculate savings versus paying monthly for 12 months.

Display badge example:

```text
Save 35%
```

### Features

* Full premium access
* Personalized advice
* Advanced notifications
* Priority support

---

# 4. Information Section

Create premium info cards.

---

## Card 1

### Icon

Security icon

### Title

100% Secure Payment

### Subtitle

No banking data is stored on this screen.

---

## Card 2

### Icon

```dart
Icons.info_outlined
```

### Title

Before confirming

### Subtitle

Make sure your mobile money account has enough balance.

---

# 5. Payment Button

Large premium CTA button.

Dynamic labels:

```text
Pay with MPESA
Pay with Airtel Money
Pay with Orange Money
```

Use loading state after tap.

Rounded corners, shadow, premium gradient.

---

# UI / UX Direction

Use:

* premium fintech design
* glassmorphism or soft cards
* rounded corners
* elegant spacing
* subtle animations
* clean typography
* polished gradients
* premium micro-interactions

---

# Recommended Packages

```yaml
google_fonts
flutter_animate
flutter_svg
```

---

# Suggested File Structure

```text
lib/
 ├── screens/
 │    └── premium_mobile_checkout.dart
 │
 ├── widgets/
 │    ├── operator_header.dart
 │    ├── pricing_card.dart
 │    ├── info_card.dart
 │    └── pay_button.dart
 │
 └── utils/
      └── mobile_operator.dart
```

---

# Code Standards

Use:

* null safety
* clean naming
* reusable widgets
* responsive layout
* maintainable structure
* constants where needed

---

# Final Objective

The screen must feel:

* premium
* modern
* trustworthy
* elegant
* high-converting
* Play Store / App Store quality

Avoid cheap/basic design.

Make the user want to subscribe immediately after opening the checkout screen.

```
```
