import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../utils/app_images.dart';
import '../../utils/app_common.dart';
import '../../network/rest_api.dart';
import '../../model/user/payment_plan_model.dart';
import 'pay.dart';

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
      List<PaymentPlanModel> plans = await getPaymentPlansApi('USD');
      
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
          Text(
            'Choisissez votre plan',
            style: TextStyle(
              color: mainColorText,
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
          ),
          
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
          
          // Payment plans list
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
      child: ElevatedButton(
        onPressed: planToUse != null
            ? () {
                // Navigate to pay screen with the selected plan (or default first plan)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PayScreen(
                      paymentPlan: planToUse,
                    ),
                  ),
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: planToUse != null ? 2 : 0,
        ),
        child: Text(
          'Continuer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: planToUse != null ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  /// Build a single payment plan card
  Widget _buildPaymentPlanCard(PaymentPlanModel plan) {
    bool isSelected = _selectedPlan?.priceIdStripe == plan.priceIdStripe;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio button indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey,
                  width: 2,
                ),
                color: isSelected ? primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            
            const SizedBox(width: 16),
            
            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan description
                  Text(
                    plan.description,
                    style: TextStyle(
                      color: mainColorText,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Plan amount
                  Text(
                    '${plan.montant} ${plan.currency}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
