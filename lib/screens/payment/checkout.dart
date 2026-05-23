import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../extensions/shared_pref.dart';
import '../../utils/app_images.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../network/rest_api.dart';
import '../../model/user/payment_plan_model.dart';
import '../../model/user/cycle_info_model.dart';
import '../../service/stripe_payment_sheet_service.dart';
import '../../service/phone_verification_service.dart';
import '../../utils/period_date_validation.dart';
import '../user/user_dashboard_screen.dart';
import '../../main.dart';

class StripeCheckout extends StatefulWidget {
  const StripeCheckout({super.key});

  @override
  State<StripeCheckout> createState() => _StripeCheckoutState();
}

class _StripeCheckoutState extends State<StripeCheckout> {
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentSlideIndex = 0;
  
  // Payment plans
  List<PaymentPlanModel> _paymentPlans = [];
  PaymentPlanModel? _selectedPlan;
  bool _isLoadingPlans = false;
  String _errorMessage = '';

  static void _showPaymentLoadingOverlay(BuildContext context,
      {String message = 'Chargement...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mainColorText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void _hidePaymentLoadingOverlay(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showDateConfirmationDialogAfterPayment(
    DateTime selectedDay,
    ScaffoldMessengerState scaffoldMessenger,
  ) async {
    final periodDate = DateFormat('yyyy-MM-dd').format(selectedDay);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(language.dateSelected),
          content: Text(periodDate),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(language.cancel),
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

    const bool q1 = true;
    const bool q2 = true;
    const bool q3 = false;

    final success =
        await PhoneVerificationService.createSubscriptionWithPeriodDate(
      phoneNumber: fullPhoneNumber,
      periodDate: periodDate,
      question1Answer: q1,
      question2Answer: q2,
      question3Answer: q3,
    );

    if (!mounted) return;
    _hidePaymentLoadingOverlay(context);

    if (success) {
      final phoneForAPI = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      await userStore.setPeriodDate(periodDate);
      final existingCycleInfo =
          userStore.cycleInfo ?? loadCycleInfoForPhone(phoneForAPI);
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

  Future<Map<String, String>?> _startPaymentSheetForSelectedPlan(
      PaymentPlanModel plan) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final String rawName = userStore.user?.displayName?.trim() ?? '';
    final String name = rawName.isNotEmpty
        ? rawName
        : 'Customer';

    final String rawEmail =
        (userStore.user?.email ?? userStore.email).trim();
    final String email = rawEmail.isNotEmpty ? rawEmail : 'customer@example.com';

    final String rawPhone =
        (userStore.user?.phoneNumber ?? getStringAsync(KEY_PHONE_NUMBER))
            .replaceAll(RegExp(r'[^\d]'), '');
    final String phone = rawPhone.isNotEmpty ? rawPhone : '243000000000';

    final paymentRegistrationResult =
        await StripePaymentSheetService.presentSetupIntentPaymentSheet(
      context: context,
      name: name,
      email: email,
      phone: phone,
    );

    if (!mounted) return null;
    if (paymentRegistrationResult == null ||
        paymentRegistrationResult.paymentMethodId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment method registration cancelled or failed.'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    final result = <String, String>{
      'customer_id': paymentRegistrationResult.customerId,
      'price_id': plan.priceIdStripe,
      'paymentMathodId': paymentRegistrationResult.paymentMethodId,
    };

    print('✅ Checkout PaymentSheet result: $result');

    _showPaymentLoadingOverlay(context, message: 'Chargement...');
    try {
      final sub = await createQuickshareStripeSubscriptionApi(
        customerId: result['customer_id']!,
        priceId: result['price_id']!,
        paymentMethodId: result['paymentMathodId']!,
      );
      if (!mounted) return result;
      _hidePaymentLoadingOverlay(context);

      if (sub.status) {
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
        if (picked == null || !mounted) return result;

        final validation = validateLastPeriodDate(picked);
        if (!validation.isValid) {
          toast(validation.errorMessage ?? periodDateValidationErrorTooOld);
          return result;
        }

        await _showDateConfirmationDialogAfterPayment(
            picked, scaffoldMessenger);
      }
    } catch (e) {
      if (mounted) _hidePaymentLoadingOverlay(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    return result;
  }

  // Testimonial slides data
  final List<Map<String, List<String>>> _testimonialSlides = [
    {
      'text': [
        'Suivez facilement votre cycle menstruel et introduisez vos  dates  pour 3 cycles et pendant 3 mois gratuitement .',
      ],
    },
    {
      'text': [
        'Recevez des notifications et des conseils personnalisés en fonction de chaque étape de votre cycle menstruel.',
      ],
    },
    {
      'text': [
        'Soyez référée à un professionnel de santé ou à un gynécologue agréé pour un suivi optimal de votre santé reproductive.',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    logScreenView("Stripe Checkout screen");
    _fetchPaymentPlans();
  }

  /// Fetch payment plans from API
  Future<void> _fetchPaymentPlans() async {
    setState(() {
      _isLoadingPlans = true;
      _errorMessage = '';
    });

    try {
      // Fetch plans for USD currency (default)
      List<PaymentPlanModel> plans =
          orderPaymentPlansForDisplay(await getPaymentPlansApi('USD'));
      
      setState(() {
        _paymentPlans = plans;
        _isLoadingPlans = false;
        // Auto-select first plan if available
        if (plans.isNotEmpty) {
          _selectedPlan = plans[0];
        }
      });
      
      print('✅ Fetched ${plans.length} payment plans');
    } catch (e) {
      print('❌ Error fetching payment plans: $e');
      setState(() {
        _isLoadingPlans = false;
        _errorMessage = 'Erreur lors du chargement des plans de paiement';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: mainColorLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: mainColorText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Checkout',
          style: boldTextStyle(
            color: mainColorText,
            size: 18,
            weight: FontWeight.w500,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image container with black gradient and 5 yellow stars text at bottom
            _buildImageWithGradientAndStars(),
            
            // Payment plans section
            _buildPaymentPlansSection(),
          ],
        ),
      ),
    );
  }

  /// Build image container with smart black gradient and yellow 5 stars text at bottom
  Widget _buildImageWithGradientAndStars() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            checkout_image,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Smart black gradient overlay (from transparent at top to black at bottom)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.9),
                  Colors.black,
                ],
                stops: const [0.0, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
          ),
          
          // Carousel with 3 slides at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: _testimonialSlides.length,
                options: CarouselOptions(
                  height: 180,
                  viewportFraction: 1.0,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 5),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  autoPlayCurve: Curves.fastOutSlowIn,
                  pauseAutoPlayOnTouch: true,
                  pauseAutoPlayOnManualNavigate: true,
                  enlargeCenterPage: false,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentSlideIndex = index;
                    });
                  },
                ),
                itemBuilder: (context, index, realIndex) {
                  final slide = _testimonialSlides[index];
                  return _buildTestimonialSlide(slide['text'] as List<String>);
                },
              ),
            ),
          ),
          
          // Carousel indicators
          Positioned(
            left: 0,
            right: 0,
            bottom: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _testimonialSlides.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentSlideIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single testimonial slide with text and 5 yellow stars
  Widget _buildTestimonialSlide(List<String> textLines) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text lines - join all lines with line breaks and wrap properly
          Flexible(
            child: Text(
              textLines.join('\n'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.visible,
              maxLines: null,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 5 yellow stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 22,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Build payment plans section below the image container
  Widget _buildPaymentPlansSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Text('Choisissez votre plan',
              style: boldTextStyle(size: 18, color: mainColorText)),
          
          const SizedBox(height: 20),
          
          // Loading state
          if (_isLoadingPlans)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          
          // Error state
          if (_errorMessage.isNotEmpty && !_isLoadingPlans)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          
          // Payment plans list (mobile-checkout style cards)
          if (!_isLoadingPlans && _errorMessage.isEmpty)
            ...(_paymentPlans.length > 3 
                ? _paymentPlans.take(3).toList() 
                : _paymentPlans)
                .asMap()
                .entries
                .map((entry) {
                  int index = entry.key;
                  PaymentPlanModel plan = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < (_paymentPlans.length > 3 ? 2 : _paymentPlans.length - 1) ? 16 : 0),
                    child: _buildPaymentPlanCard(plan),
                  );
                })
                .toList(),
          
          // Smart button under the last card
          if (!_isLoadingPlans && _errorMessage.isEmpty && _paymentPlans.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildSmartButton(),
            ),
        ],
      ),
    );
  }

  /// Build smart button for proceeding with payment
  Widget _buildSmartButton() {
    // Use selected plan, or default to first plan if none selected
    final planToUse = _selectedPlan ?? 
        (_paymentPlans.isNotEmpty ? _paymentPlans[0] : null);
    
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: planToUse != null
            ? () async {
                await _startPaymentSheetForSelectedPlan(planToUse);
              }
            : null,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [primaryColor, const Color(0xFF7A55FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Center(
            child: Text(
              language.continueText,
              style: boldTextStyle(
                size: 15,
                color: planToUse != null ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getPlanTitle(PaymentPlanModel plan) {
    switch (plan.displayTypeIndex) {
      case 0:
        return language.mobileMoneyTrialPlan;
      case 1:
        return language.mobileMoneyMonthlyPlan;
      case 2:
        return language.mobileMoneyAnnualPlan;
      default:
        return language.mobileMoneyMonthlyPlan;
    }
  }

  List<String> _getPlanFeatures(PaymentPlanModel plan) {
    switch (plan.displayTypeIndex) {
      case 0:
        return <String>[
          language.mobileMoneyTrialFeatureBasic,
          language.mobileMoneyTrialFeatureDuration,
        ];
      case 1:
        return <String>[
          language.mobileMoneyFeatureFullAccess,
          language.mobileMoneyFeaturePersonalizedAdvice,
          language.mobileMoneyFeatureAdvancedNotifications,
          language.mobileMoneyFeatureSupport,
        ];
      case 2:
        return <String>[
          language.mobileMoneyFeatureFullAccess,
          language.mobileMoneyFeaturePersonalizedAdvice,
          language.mobileMoneyFeatureAdvancedNotifications,
          language.mobileMoneyFeaturePrioritySupport,
        ];
      default:
        return <String>[language.mobileMoneyFeatureFullAccess];
    }
  }

  String? _getPlanBadge(PaymentPlanModel plan) {
    if (plan.displayTypeIndex == 1) return language.mobileMoneyMostPopular;
    return null;
  }

  /// Build a single payment plan card (mobile-checkout style)
  Widget _buildPaymentPlanCard(PaymentPlanModel plan) {
    bool isSelected = _selectedPlan?.priceIdStripe == plan.priceIdStripe;
    final String title = _getPlanTitle(plan);
    final String? badge = _getPlanBadge(plan);
    final List<String> features = _getPlanFeatures(plan);
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: boldTextStyle(size: 16))),
                if ((badge ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FBEE),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      badge!,
                      style: primaryTextStyle(
                        color: const Color(0xFF119946),
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${plan.montant} ${plan.currency}',
              style: boldTextStyle(size: 18, color: primaryColor),
            ),
            const SizedBox(height: 10),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature, style: primaryTextStyle(size: 13))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
