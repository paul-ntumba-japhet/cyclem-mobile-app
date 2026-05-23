import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../extensions/extensions.dart';
import '../extensions/shared_pref.dart';
import '../languageConfiguration/LanguageDataConstant.dart';
import '../languageConfiguration/LanguageDefaultJson.dart';
import '../main.dart';
import '../model/user/cycle_info_model.dart';
import '../network/rest_api.dart';
import '../screens/payment/mobile_money_checkout.dart';
import '../service/phone_verification_service.dart';
import 'app_common.dart';
import 'app_constants.dart';
import 'period_date_validation.dart';

enum ActivateCollierFlowResult {
  saved,
  redirectedToPayment,
  cancelled,
  failed,
}

Future<ActivateCollierFlowResult> runActivateCollierFlow({
  required BuildContext context,
  String? initialPhoneNumber,
  String? initialDateRegle,
  Future<bool?> Function(DateTime selectedDay)? confirmDate,
  Future<void> Function()? onSaved,
}) async {
  if (!context.mounted) return ActivateCollierFlowResult.cancelled;

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final String phone = (initialPhoneNumber ??
          userStore.user?.phoneNumber ??
          getStringAsync(KEY_PHONE_NUMBER))
      .trim();
  final String dateRegle = (initialDateRegle ?? userStore.cycleInfo?.dateRegle ?? '').trim();

  if (phone.isEmpty) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(language.phoneNotAvailablePleaseReconnect),
        backgroundColor: Colors.orange,
      ),
    );
    return ActivateCollierFlowResult.failed;
  }

  try {
    final metadata = await getPaymentFlowMetadata(
      phoneNumber: phone,
      dateRegle: dateRegle,
    );

    if (metadata.paymentStatus.code != '100') {
      bool mobileRedirectTriggered = false;
      final decision = await shouldRedirectToPaymentFlow(
        context: context,
        phoneNumber: phone,
        dateRegle: dateRegle,
        metadata: metadata,
        onMobilePaymentRedirect: () {
          mobileRedirectTriggered = true;
          MobileMoneyCheckoutScreen(
            phoneNumber: phone,
            dateRegle: dateRegle,
          ).launch(context);
        },
        onError: (message) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(message.isNotEmpty ? message : language.anErrorHasOccurred),
              backgroundColor: Colors.red,
            ),
          );
        },
      );

      if (decision == PaymentFlowDecision.redirectedToMobile &&
          !mobileRedirectTriggered &&
          context.mounted) {
        MobileMoneyCheckoutScreen(
          phoneNumber: phone,
          dateRegle: dateRegle,
        ).launch(context);
      }
      return ActivateCollierFlowResult.redirectedToPayment;
    }
  } catch (e) {
    if (context.mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${language.errorLabel}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return ActivateCollierFlowResult.failed;
  }

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

  if (picked == null || !context.mounted) {
    return ActivateCollierFlowResult.cancelled;
  }

  final validation = validateLastPeriodDate(picked);
  if (!validation.isValid) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(validation.errorMessage ?? periodDateValidationErrorTooOld),
        backgroundColor: Colors.orange,
      ),
    );
    return ActivateCollierFlowResult.failed;
  }

  bool? confirmed;
  if (confirmDate != null) {
    confirmed = await confirmDate(picked);
  } else {
    confirmed = await _showDefaultDateConfirmationDialog(context, picked);
  }
  if (confirmed != true || !context.mounted) {
    return ActivateCollierFlowResult.cancelled;
  }

  String fullPhoneNumber = (userStore.user?.phoneNumber ?? phone).replaceAll(RegExp(r'[^\d+]'), '');
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
    return ActivateCollierFlowResult.failed;
  }

  const bool q1 = true;
  const bool q2 = true;
  const bool q3 = false;
  final String periodDate = DateFormat('yyyy-MM-dd').format(picked);

  try {
    final success = await PhoneVerificationService.createSubscriptionWithPeriodDate(
      phoneNumber: fullPhoneNumber,
      periodDate: periodDate,
      question1Answer: q1,
      question2Answer: q2,
      question3Answer: q3,
      suppressFailureToast: true,
    );

    if (!context.mounted) return ActivateCollierFlowResult.cancelled;
    if (!success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(language.failedToSavePeriodDatePleaseTryAgain),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return ActivateCollierFlowResult.failed;
    }

    final phoneForAPI = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    await userStore.setPeriodDate(periodDate);
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

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(language.periodDateSavedSuccess),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    appStore.setHomeScreenUpdated(true);
    if (onSaved != null) {
      await onSaved();
    }
    return ActivateCollierFlowResult.saved;
  } catch (e) {
    if (context.mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${language.errorLabel}: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return ActivateCollierFlowResult.failed;
  }
}

Future<bool?> _showDefaultDateConfirmationDialog(
  BuildContext context,
  DateTime selectedDay,
) async {
  final locale = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
  final formattedDate = DateFormat('dd MMMM yyyy', locale).format(selectedDay);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text(
          language.dateSelected,
          style: boldTextStyle(color: Colors.black87, size: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              language.youHaveSelected,
              style: primaryTextStyle(color: Colors.black87, size: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                formattedDate,
                style: boldTextStyle(color: primaryColor, size: 16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              language.doYouWantToContinueWithThisDate,
              style: primaryTextStyle(color: Colors.black87, size: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              language.cancel,
              style: primaryTextStyle(color: Colors.grey, size: 14),
            ),
          ),
          buildDateConfirmationButton(
            label: language.next,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );
}
