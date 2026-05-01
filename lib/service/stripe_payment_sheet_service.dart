import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../network/rest_api.dart';

class StripePaymentSheetRegistrationResult {
  final String customerId;
  final String paymentMethodId;

  const StripePaymentSheetRegistrationResult({
    required this.customerId,
    required this.paymentMethodId,
  });
}

class StripePaymentSheetService {
  /// Initializes and presents Stripe PaymentSheet using setup-intent data
  /// from `createStripeSetupIntentPaymentMethodApi`.
  static Future<StripePaymentSheetRegistrationResult?> presentSetupIntentPaymentSheet({
    required BuildContext context,
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      final setupData = await createStripeSetupIntentPaymentMethodApi(
        name: name,
        email: email,
        phone: phone,
      );

      // Use publishable key returned by backend for this setup-intent flow.
      if (setupData.data.publishableKey.isNotEmpty) {
        Stripe.publishableKey = setupData.data.publishableKey;
        await Stripe.instance.applySettings();
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Cycle Menstruel',
          customerId: setupData.data.customerId,
          customerEphemeralKeySecret: setupData.data.ephemeralKeySecret,
          setupIntentClientSecret: setupData.data.clientSecret,
          style: ThemeMode.system
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final setupIntent =
          await Stripe.instance.retrieveSetupIntent(setupData.data.clientSecret);
      final String? paymentMethodId = setupIntent.paymentMethodId;
      if (paymentMethodId == null || paymentMethodId.isEmpty) {
        throw Exception('Payment method id not found after setup intent confirmation');
      }

      final result = StripePaymentSheetRegistrationResult(
        customerId: setupData.data.customerId,
        paymentMethodId: paymentMethodId,
      );

      if (!context.mounted) return result;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PaymentSheet completed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      return result;
    } on StripeException catch (e) {
      if (!context.mounted) return null;
      final code = e.error.code.name;
      final message = e.error.message ?? e.error.localizedMessage ?? 'Stripe error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PaymentSheet ($code): $message'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PaymentSheet failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }
}
