import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';

import '../../extensions/extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../main.dart';
import '../../model/user/cycle_info_model.dart';
import '../../model/user/payment_plan_model.dart';
import '../../network/rest_api.dart';
import '../../service/phone_verification_service.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/period_date_validation.dart';
import '../user/user_dashboard_screen.dart';

enum MobilePaymentState {
  idle,
  initializing,
  waitingForUssd,
  confirming,
  success,
  failed,
  timeout,
}

class MobileMoneyCheckoutScreen extends StatefulWidget {
  const MobileMoneyCheckoutScreen({
    super.key,
    required this.phoneNumber,
    this.dateRegle = '',
  });

  final String phoneNumber;
  final String dateRegle;

  @override
  State<MobileMoneyCheckoutScreen> createState() =>
      _MobileMoneyCheckoutScreenState();
}

class _MobileMoneyCheckoutScreenState extends State<MobileMoneyCheckoutScreen> {
  static const Duration _pollingInterval = Duration(seconds: 3);
  static const Duration _pollingTimeout = Duration(seconds: 60);
  static const List<String> _waitingMessages = <String>[
    'Ouverture de la fenetre USSD',
    'Veuillez confirmer le code PIN sur votre telephone',
    'Verification du paiement en cours...',
  ];

  late List<_MobilePlan> _plans;
  int _selectedPlanIndex = 2;
  bool _isLoadingPlans = false;
  MobilePaymentState _paymentState = MobilePaymentState.idle;
  String _paymentStatusMessage = '';
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _plans = <_MobilePlan>[
      _MobilePlan(
        id: 'trial',
        title: language.mobileMoneyTrialPlan,
        priceLabel: '0\$',
        features: <String>[
          language.mobileMoneyTrialFeatureBasic,
          language.mobileMoneyTrialFeatureDuration,
        ],
      ),
      _MobilePlan(
        id: 'monthly',
        title: language.mobileMoneyMonthlyPlan,
        priceLabel: '8.999\$ ${language.mobileMoneyPerMonth}',
        features: <String>[
          language.mobileMoneyFeatureFullAccess,
          language.mobileMoneyFeaturePersonalizedAdvice,
          language.mobileMoneyFeatureAdvancedNotifications,
          language.mobileMoneyFeatureSupport,
        ],
        highlightLabel: language.mobileMoneyMostPopular,
      ),
      _MobilePlan(
        id: 'annual',
        title: language.mobileMoneyAnnualPlan,
        priceLabel: '69.999\$',
        features: <String>[
          language.mobileMoneyFeatureFullAccess,
          language.mobileMoneyFeaturePersonalizedAdvice,
          language.mobileMoneyFeatureAdvancedNotifications,
          language.mobileMoneyFeaturePrioritySupport,
        ],
        highlightLabel: _buildSavingsLabel(),
      ),
    ];
    _fetchPaymentPlans();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _fetchPaymentPlans() async {
    setState(() => _isLoadingPlans = true);
    try {
      final List<PaymentPlanModel> apiPlans = await getPaymentPlansApi('USD');
      if (!mounted) return;

      final List<PaymentPlanModel> orderedPlans =
          orderPaymentPlansForDisplay(apiPlans);
      final List<_MobilePlan> updatedPlans = List<_MobilePlan>.from(_plans);
      for (int i = 0; i < updatedPlans.length && i < orderedPlans.length; i++) {
        final PaymentPlanModel apiPlan = orderedPlans[i];
        updatedPlans[i] = updatedPlans[i].copyWith(
          priceLabel: '${apiPlan.montant} ${apiPlan.currency}',
        );
      }

      setState(() {
        _plans = updatedPlans;
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPlans = false);
    }
  }

  String _buildSavingsLabel() {
    const double monthly = 8.999;
    const double annual = 69.999;
    final double monthlyYearTotal = monthly * 12;
    if (monthlyYearTotal <= 0) return '';
    final int percent =
        (((monthlyYearTotal - annual) / monthlyYearTotal) * 100).round();
    return language.mobileMoneySaveLabel.replaceAll('%s', '$percent%');
  }

  String get _operator => getMobileOperator(widget.phoneNumber);

  String get _subtitle {
    switch (_operator) {
      case 'MPESA':
        return 'Vodacom';
      case 'Airtel Money':
        return 'Airtel';
      case 'Orange Money':
        return 'Orange';
      default:
        return language.mobileMoneyRdcSubtitle;
    }
  }

  String get _operatorLogo {
    switch (_operator) {
      case 'MPESA':
        return 'assets/mpesa.png';
      case 'Airtel Money':
        return 'assets/airtel.png';
      case 'Orange Money':
        return 'assets/orange.png';
      default:
        return 'assets/ic_credit_card.png';
    }
  }

  String get _maskedPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 7) return digits;
    final start = digits.substring(0, 5);
    final end = digits.substring(digits.length - 2);
    return '$start*****$end';
  }

  Future<void> _onPayPressed() async {
    if (_isPaymentInProgress) return;
    _setPaymentState(
      MobilePaymentState.initializing,
      message: 'Initialisation du paiement',
    );
    try {
      await authenticateMobilePaymentLocalNumber(
          phoneNumber: widget.phoneNumber);
      final String displayName = (userStore.user?.displayName ?? '').trim();
      final String accountName = displayName.isNotEmpty ? displayName : 'User';
      final String selectedAmount =
          _extractAmountFromLabel(_plans[_selectedPlanIndex].priceLabel);
      await createMobilePaymentAccountApi(
        msisdn: widget.phoneNumber,
        name: accountName,
        phone: widget.phoneNumber,
      );
      final initializationResponse = await initializeMobilePaymentApi(
        phone: widget.phoneNumber,
        name: accountName,
        amount: selectedAmount,
      );

      final String transactionId = initializationResponse.transactionId.trim();
      if (transactionId.isEmpty) {
        throw Exception('Transaction id not found in initialization response');
      }

      _setPaymentState(
        MobilePaymentState.waitingForUssd,
        message: _waitingMessages.first,
      );
      await _startPaymentValidationPolling(transactionId: transactionId);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      _setPaymentState(
        MobilePaymentState.failed,
        message: message.isEmpty ? language.mobileMoneyInitFailed : message,
      );
      toast(message.isEmpty ? language.mobileMoneyInitFailed : message);
    }
  }

  bool get _isPaymentInProgress =>
      _paymentState == MobilePaymentState.initializing ||
      _paymentState == MobilePaymentState.waitingForUssd ||
      _paymentState == MobilePaymentState.confirming;

  void _setPaymentState(MobilePaymentState state, {String? message}) {
    if (!mounted || _isDisposed) return;
    setState(() {
      _paymentState = state;
      if (message != null) {
        _paymentStatusMessage = message;
      }
    });
  }

  Future<void> _startPaymentValidationPolling({
    required String transactionId,
  }) async {
    final DateTime startedAt = DateTime.now();
    int attempt = 0;

    while (mounted && !_isDisposed) {
      final Duration elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= _pollingTimeout) {
        _setPaymentState(
          MobilePaymentState.timeout,
          message: 'Le delai de verification est depasse. Veuillez reessayer.',
        );
        toast('Le paiement est en attente. Veuillez reessayer.');
        return;
      }

      if (attempt == 0) {
        _setPaymentState(
          MobilePaymentState.waitingForUssd,
          message: _waitingMessages[0],
        );
      } else if (attempt == 1) {
        _setPaymentState(
          MobilePaymentState.confirming,
          message: _waitingMessages[1],
        );
      } else {
        _setPaymentState(
          MobilePaymentState.confirming,
          message: _waitingMessages[2],
        );
      }

      await Future<void>.delayed(_pollingInterval);
      if (!mounted || _isDisposed) return;

      final validationResponse = await validateMobilePaymentApi(
        transactionId: transactionId,
      );

      if (validationResponse.responseCode == '004') {
        _setPaymentState(
          MobilePaymentState.success,
          message: validationResponse.responseDesc.isNotEmpty
              ? validationResponse.responseDesc
              : 'Paiement confirme',
        );
        toast(language.mobileMoneyPaymentInitialized
            .replaceAll('%plan%', _plans[_selectedPlanIndex].title)
            .replaceAll('%operator%', _operator));
        await _handlePostPaymentPeriodDateFlow();
        return;
      }

      attempt++;
    }
  }

  String _extractAmountFromLabel(String priceLabel) {
    final RegExpMatch? match =
        RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(priceLabel);
    if (match == null) return '0';
    return match.group(1)!.replaceAll(',', '.');
  }

  Future<void> _handlePostPaymentPeriodDateFlow() async {
    if (!mounted || _isDisposed) return;

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
    if (picked == null || !mounted || _isDisposed) return;

    final validation = validateLastPeriodDate(picked);
    if (!validation.isValid) {
      _setPaymentState(
        MobilePaymentState.failed,
        message: validation.errorMessage ?? periodDateValidationErrorTooOld,
      );
      toast(validation.errorMessage ?? periodDateValidationErrorTooOld);
      return;
    }

    final periodDate = DateFormat('yyyy-MM-dd').format(picked);
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

    if (confirmed != true || !mounted || _isDisposed) return;

    _setPaymentState(
      MobilePaymentState.confirming,
      message: 'Enregistrement en cours...',
    );

    String fullPhoneNumber =
        (userStore.user?.phoneNumber ?? widget.phoneNumber).trim();
    fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!fullPhoneNumber.startsWith('+') && fullPhoneNumber.isNotEmpty) {
      fullPhoneNumber = '+$fullPhoneNumber';
    }
    if (fullPhoneNumber.isEmpty) {
      _setPaymentState(
        MobilePaymentState.failed,
        message: 'Phone number not found. Please sign in again.',
      );
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
    if (!mounted || _isDisposed) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
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
      return;
    }

    _setPaymentState(
      MobilePaymentState.failed,
      message: 'Failed to save period date. Please try again.',
    );
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Failed to save period date. Please try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: whiteColor,
        elevation: 0,
        title: Text(language.mobileMoneyCheckoutTitle,
            style: boldTextStyle(color: whiteColor, size: 18)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OperatorHeader(
                  operator: _operator,
                  subtitle: _subtitle,
                  logoPath: _operatorLogo,
                  maskedPhone: _maskedPhone,
                ),
                const SizedBox(height: 16),
                ...List<Widget>.generate(
                  _plans.length,
                  (index) => _PricingCard(
                    plan: _plans[index],
                    isLoadingPrice: _isLoadingPlans,
                    isSelected: _selectedPlanIndex == index,
                    onTap: () => setState(() => _selectedPlanIndex = index),
                  ),
                ),
                const SizedBox(height: 8),
                _InfoCard(
                  icon: Icons.verified_user_outlined,
                  title: language.mobileMoneySecureTitle,
                  subtitle: language.mobileMoneySecureSubtitle,
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.info_outlined,
                  title: language.mobileMoneyBeforeConfirmTitle,
                  subtitle: language.mobileMoneyBeforeConfirmSubtitle,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPaymentInProgress ? null : _onPayPressed,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                        child: _isPaymentInProgress
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                '${language.mobileMoneyPayWith} $_operator',
                                style: boldTextStyle(
                                    color: Colors.white, size: 15),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isPaymentInProgress)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.18),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _PaymentStatusCard(
                        key: ValueKey<String>('status_${_paymentState.name}'),
                        state: _paymentState,
                        message: _paymentStatusMessage,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OperatorHeader extends StatelessWidget {
  const _OperatorHeader({
    required this.operator,
    required this.subtitle,
    required this.logoPath,
    required this.maskedPhone,
  });

  final String operator;
  final String subtitle;
  final String logoPath;
  final String maskedPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFF7F4FF), Color(0xFFEDE7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              logoPath,
              height: 48,
              width: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(operator, style: boldTextStyle(size: 20)),
                const SizedBox(height: 2),
                Text(subtitle, style: secondaryTextStyle(size: 13)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(maskedPhone, style: primaryTextStyle(size: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.plan,
    required this.isLoadingPrice,
    required this.isSelected,
    required this.onTap,
  });

  final _MobilePlan plan;
  final bool isLoadingPrice;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                Expanded(
                    child: Text(plan.title, style: boldTextStyle(size: 16))),
                if ((plan.highlightLabel ?? '').isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FBEE),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      plan.highlightLabel!,
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
              isLoadingPrice ? '...' : plan.priceLabel,
              style: boldTextStyle(size: 18, color: primaryColor),
            ),
            const SizedBox(height: 10),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(feature, style: primaryTextStyle(size: 13))),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: boldTextStyle(size: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: secondaryTextStyle(size: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePlan {
  const _MobilePlan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.features,
    this.highlightLabel,
  });

  final String id;
  final String title;
  final String priceLabel;
  final List<String> features;
  final String? highlightLabel;

  _MobilePlan copyWith({
    String? id,
    String? title,
    String? priceLabel,
    List<String>? features,
    String? highlightLabel,
  }) {
    return _MobilePlan(
      id: id ?? this.id,
      title: title ?? this.title,
      priceLabel: priceLabel ?? this.priceLabel,
      features: features ?? this.features,
      highlightLabel: highlightLabel ?? this.highlightLabel,
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({
    super.key,
    required this.state,
    required this.message,
  });

  final MobilePaymentState state;
  final String message;

  Color get _accentColor {
    switch (state) {
      case MobilePaymentState.success:
        return const Color(0xFF119946);
      case MobilePaymentState.failed:
      case MobilePaymentState.timeout:
        return const Color(0xFFD32F2F);
      default:
        return primaryColor;
    }
  }

  IconData get _icon {
    switch (state) {
      case MobilePaymentState.success:
        return Icons.check_circle_outline;
      case MobilePaymentState.failed:
      case MobilePaymentState.timeout:
        return Icons.error_outline;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  bool get _showProgress =>
      state == MobilePaymentState.initializing ||
      state == MobilePaymentState.waitingForUssd ||
      state == MobilePaymentState.confirming;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: primaryTextStyle(size: 13),
            ),
          ),
          if (_showProgress) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _accentColor,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
