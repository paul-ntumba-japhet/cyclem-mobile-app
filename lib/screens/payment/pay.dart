import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../utils/app_common.dart';
import '../../utils/period_date_validation.dart';
import '../../model/user/payment_plan_model.dart';
import '../../model/user/cycle_info_model.dart';
import '../../network/rest_api.dart';
import '../../main.dart';
import '../../service/phone_verification_service.dart';
import '../../utils/app_constants.dart';
import '../../extensions/shared_pref.dart';
import '../../screens/user/user_dashboard_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class PayScreen extends StatefulWidget {
  final PaymentPlanModel paymentPlan;

  const PayScreen({
    super.key,
    required this.paymentPlan,
  });

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  CardFieldInputDetails _card = const CardFieldInputDetails(complete: true);

  @override
  void initState() {
    super.initState();
    logScreenView("Pay screen");
    
    // Log received payment plan
    print('💰 Received payment plan:');
    print('  Description: ${widget.paymentPlan.description}');
    print('  Amount: ${widget.paymentPlan.montant} ${widget.paymentPlan.currency}');
    print('  Price ID Stripe: ${widget.paymentPlan.priceIdStripe}');
  }

  Future<dynamic> _handlePayPress() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // 1. Gather customer billing information (ex. email)
      const billingDetails = BillingDetails(
        email: 'email@stripe.com',
        phone: '15067062059',
        address: Address(
          city: 'Houston',
          country: 'US',
          line1: '1459  Circle Drive',
          line2: '',
          state: 'Texas',
          postalCode: '77063',
        ),
      ); // mocked data for tests

      // 2. Create payment method
      final paymentMethod = await Stripe.instance.createPaymentMethod(
          params: const PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(
          billingDetails: billingDetails,
        ),
      ));

      return paymentMethod.id;
    } catch (e) {
      print('❌ Error creating payment method: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors du paiement: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    }
  }

  /// Show a full-screen beautiful loading overlay (same style for both steps).
  static void _showPaymentLoadingOverlay(BuildContext context, {String message = 'Chargement...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: false,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          ),
                          Icon(
                            Icons.schedule_outlined,
                            color: primaryColor.withOpacity(0.9),
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: mainColorText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Hide the loading overlay (call after async work).
  static void _hidePaymentLoadingOverlay(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Paiement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            
            // Visa card image
            SizedBox(
              width: MediaQuery.of(context).size.width - 40, // Account for padding
              height: 200,
              child: Image.asset(
                'assets/visa.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('❌ Error loading visa image: $error');
                  print('   Path attempted: assets/visa.png');
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey.withOpacity(0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image non trouvée',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Display text based on description
            _buildDescriptionText(widget.paymentPlan.description),
            
            const SizedBox(height: 40),

            // Card form field (Stripe is initialized in main.dart)
            _buildCardFormField(),
            
            const SizedBox(
              height: 20,
            ),
            
            _showPaymentButton(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Display text according to the description parameter
  /// Returns a widget with text content based on the plan description
  Widget _buildDescriptionText(String description) {
    String displayText = _getTextByDescription(description);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: mainColorText,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Get text content based on description
  /// Returns appropriate text for different plan descriptions
  String _getTextByDescription(String description) {
    // Normalize description for case-insensitive comparison
    String normalizedDescription = description.toLowerCase().trim();
    
    switch (normalizedDescription) {
      case 'annuel':
        return 'Abonnement annuel - Accès complet à toutes les fonctionnalités pendant 12 mois. Idéal pour un suivi à long terme de votre cycle menstruel.';
      
      case 'mensuel':
        return 'Abonnement mensuel - Accès complet à toutes les fonctionnalités pendant 1 mois. Parfait pour essayer toutes les fonctionnalités de l\'application.';
      
      case 'essaie':
      case 'essai':
        return 'Période d\'essai - Découvrez les fonctionnalités principales de l\'application. Accès limité pendant la période d\'essai.';
      
      default:
        return 'Plan sélectionné: $description. Profitez de toutes les fonctionnalités de l\'application pour suivre votre cycle menstruel.';
    }
  }

  /// Build CardFormField
  Widget _buildCardFormField() {
    return CardFormField(
      autofocus: true,
      style: CardFormStyle(
        backgroundColor: primaryColor,
        placeholderColor: Colors.white.withOpacity(0.7),
        borderColor: primaryColor,
        textColor: Colors.white,
      ),
      onCardChanged: (card) {
        setState(() {
          _card = card!;
        });
      },
      preferredNetworks: [
        CardBrand.Visa,
        CardBrand.Mastercard,
        CardBrand.Amex
      ],
    );
  }

  /// Show date confirmation dialog after payment (like onboarding). On confirm, close and call createSubscriptionWithPeriodDate.
  Future<void> _showDateConfirmationDialogAfterPayment(
    DateTime selectedDay,
    ScaffoldMessengerState scaffoldMessenger,
  ) async {
    final formattedDate = DateFormat('dd MMMM yyyy', 'fr').format(selectedDay);
    final periodDate = DateFormat('yyyy-MM-dd').format(selectedDay);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            language.dateSelected,
            style: boldTextStyle(color: mainColorText, size: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.youHaveSelected,
                style: primaryTextStyle(color: mainColorText, size: 14),
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
                style: primaryTextStyle(color: mainColorText, size: 12),
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

    if (confirmed != true || !mounted) return;

    _showPaymentLoadingOverlay(context, message: 'Enregistrement en cours...');

    String fullPhoneNumber = userStore.user?.phoneNumber ?? '';
    fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!fullPhoneNumber.startsWith('+') && fullPhoneNumber.isNotEmpty) {
      fullPhoneNumber = '+$fullPhoneNumber';
    }
    if (fullPhoneNumber.isEmpty) {
      if (mounted) _hidePaymentLoadingOverlay(context);
      toast('Phone number not found. Please sign in again.');
      return;
    }

    // Use fixed questionnaire answers: yes, yes, no (do not load from question data)
    const bool q1 = true;  // yes
    const bool q2 = true;  // yes
    const bool q3 = false; // no

    final success = await PhoneVerificationService.createSubscriptionWithPeriodDate(
      phoneNumber: fullPhoneNumber,
      periodDate: periodDate,
      question1Answer: q1,
      question2Answer: q2,
      question3Answer: q3,
    );

    if (!mounted) return;
    _hidePaymentLoadingOverlay(context);

    if (success) {
      // Update dateRegle so circular beads, calendar, and graph use the new date
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
        const SnackBar(
          content: Text('Subscription and period date saved successfully.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      appStore.setHomeScreenUpdated(true);
      DashboardScreen(currentIndex: 0).launch(context, isNewTask: true);
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to save period date. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Get or create Stripe customer ID (reused for Pay button and Get IDs button).
  Future<String> _getOrCreateStripeCustomerId() async {
    String userName = '';
    String userEmail = '';
    String userPhone = '';

    if (userStore.user != null) {
      userName = (userStore.user?.displayName ?? '').trim();
      userEmail = userStore.email.isNotEmpty ? userStore.email : (userStore.user?.email ?? '');
      userPhone = userStore.user?.phoneNumber ?? '';
    }
    if (userName.isEmpty) userName = 'Customer';
    if (userEmail.isEmpty) userEmail = 'customer@example.com';
    if (userPhone.isEmpty) userPhone = '+1234567890';

    final customerResponse = await createStripeCustomerApi(
      name: userName,
      email: userEmail,
      phone: userPhone,
      description: 'Customer for ${widget.paymentPlan.description}',
    );
    return customerResponse.customer;
  }

  Widget _showPaymentButton(){
    if (_card.complete){
      return SizedBox(
        width: MediaQuery.of(context).size.width,
        child: ElevatedButton(
          onPressed: () async {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            try {
              final paymentMethodId = await _handlePayPress();
              final customerId = await _getOrCreateStripeCustomerId();
              final priceId = widget.paymentPlan.priceIdStripe;

              final result = await createStripeSubscriptionApi(
                customerId: customerId,
                priceId: priceId,
                paymentMethodId: paymentMethodId,
              );
              if (result.isEmpty || !mounted) return;

              _showPaymentLoadingOverlay(context, message: 'Chargement...');
              await Future.delayed(const Duration(milliseconds: 400));
              if (!mounted) return;
              _hidePaymentLoadingOverlay(context);

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final firstDate = today.subtract(const Duration(days: 33));

              final picked = await showDatePicker(
                context: context,
                initialDate: today,
                firstDate: firstDate,
                lastDate: today,
                helpText: language.dateSelected,
              );
              if (picked == null || !mounted) return;

              final validation = validateLastPeriodDate(picked);
              if (!validation.isValid) {
                toast(validation.errorMessage ?? periodDateValidationErrorTooOld);
                return;
              }

              await _showDateConfirmationDialogAfterPayment(picked, scaffoldMessenger);
            } catch (e) {
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          }, 
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
            backgroundColor: WidgetStateProperty.all<Color>(primaryColor),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0)
              ))
          ),
          child: const Text('Payez')),
      );
    }
    else 
    {
      return const SizedBox();
    }
  }

}

