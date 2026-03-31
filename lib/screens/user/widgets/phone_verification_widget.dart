import 'dart:async';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../extensions/extension_util/context_extensions.dart';
import '../../../extensions/extensions.dart';
import '../../../extensions/new_colors.dart';
import '../../../main.dart';
import '../../../model/user/question_model.dart';
import '../../../network/rest_api.dart';
import '../../../service/phone_verification_service.dart';
import '../../../utils/app_common.dart';

class PhoneVerificationWidget extends StatefulWidget {
  final Function()? onVerified;

  const PhoneVerificationWidget({Key? key, this.onVerified}) : super(key: key);

  @override
  State<PhoneVerificationWidget> createState() => _PhoneVerificationWidgetState();
}

class _PhoneVerificationWidgetState extends State<PhoneVerificationWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final PhoneVerificationService _phoneService = PhoneVerificationService();
  
  String _selectedCountryCode = "+243";
  String _selectedCountryIsoCode = "CD";
  String? _verificationId;
  bool _isOTPSent = false;
  bool _isVerified = false;
  int _resendTimer = 0;
  Timer? _timer;
  
  // Loading state management
  bool _isLoading = false;
  String _loadingMessage = "";
  late AnimationController _loadingAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  
  // Helper to get country ISO code from dial code
  String _getCountryIsoFromDialCode(String dialCode) {
    // Common mappings
    Map<String, String> dialToCountry = {
      "+1": "US",
      "+33": "FR",
      "+44": "GB",
      "+49": "DE",
      "+91": "IN",
      "+86": "CN",
      "+81": "JP",
      "+82": "KR",
      "+61": "AU",
      "+55": "BR",
      "+52": "MX",
      "+34": "ES",
      "+39": "IT",
      "+7": "RU",
      "+20": "EG",
      "+27": "ZA",
      "+243": "CD",
    };
    return dialToCountry[dialCode] ?? "CD";
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _loadingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Initialize with saved phone number if exists
    if (questionsModel.step2Phone.phoneNumber != null) {
      _phoneController.text = questionsModel.step2Phone.phoneNumber!;
      _selectedCountryCode = questionsModel.step2Phone.countryCode ?? "+243";
      _selectedCountryIsoCode = _getCountryIsoFromDialCode(_selectedCountryCode);
    } else {
      _selectedCountryIsoCode = _getCountryIsoFromDialCode(_selectedCountryCode);
    }
    if (questionsModel.step2Phone.isVerified == true) {
      _isVerified = true;
      _isOTPSent = true;
      _verificationId = questionsModel.step2Phone.verificationId;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    _loadingAnimationController.dispose();
    super.dispose();
  }
  
  void _setLoading(bool loading, {String message = ""}) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        _loadingMessage = message;
      });
      if (!loading) {
        _loadingAnimationController.stop();
        _loadingAnimationController.reset();
      } else {
        _loadingAnimationController.repeat(reverse: true);
      }
    }
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.trim().isEmpty) {
      toast(language.pleaseEnterYourPhoneNumber);
      return;
    }

    if (_phoneController.text.trim().length < 8) {
      toast(language.pleaseEnterValidPhoneNumber);
      return;
    }

    _setLoading(true, message: language.sendingVerificationCode);

    await _phoneService.sendOTP(
      _phoneController.text.trim(),
      _selectedCountryCode,
      onCodeSent: (String verificationId) {
        _setLoading(false);
        setState(() {
          _verificationId = verificationId;
          _isOTPSent = true;
          questionsModel.step2Phone.phoneNumber = _phoneController.text.trim();
          questionsModel.step2Phone.countryCode = _selectedCountryCode;
          questionsModel.step2Phone.verificationId = verificationId;
          // Save to phone-specific key only
          String? phoneNumber = questionsModel.step2Phone.phoneNumber;
          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
            if (phoneForAPI.isNotEmpty) {
              saveQuestionDataForPhone(phoneForAPI, questionsModel);
            }
          }
        });
        _startResendTimer();
        toast(language.otpSentSuccessfully);
      },
      onError: (String error) {
        _setLoading(false);
        toast(error);
      },
    );
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 4) {
      toast(language.pleaseEnterComplete4DigitOtp);
      return;
    }

    if (_verificationId == null) {
      toast(language.pleaseSendOtpFirst);
      return;
    }

    _setLoading(true, message: language.verifyingCode);

    bool verified = await _phoneService.verifyOTP(
      _verificationId!,
      _otpController.text.trim(),
    );

    if (verified) {
      // Verification and subscription are complete
      // Add a small delay for smooth transition before hiding loader
      await Future.delayed(Duration(milliseconds: 300));
      
      _setLoading(false);
      setState(() {
        _isVerified = true;
        _isOTPSent = true; // Keep this true to hide send button
        questionsModel.step2Phone.isVerified = true;
        questionsModel.step2Phone.otpCode = _otpController.text.trim();
        // Save to phone-specific key only
        String? phoneNumber = questionsModel.step2Phone.phoneNumber;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
          if (phoneForAPI.isNotEmpty) {
            saveQuestionDataForPhone(phoneForAPI, questionsModel);
          }
        }
      });
      
      // Notify parent widget to rebuild (this will update continue button visibility)
      if (widget.onVerified != null) {
        widget.onVerified!();
      }
      
      toast(language.phoneNumberVerifiedSuccessfully);
    } else {
      _setLoading(false);
    }
  }

  Future<void> _resendOTP() async {
    if (_resendTimer > 0) {
      toast(language.pleaseWaitSecondsBeforeResending.replaceAll("%s", _resendTimer.toString()));
      return;
    }

    await _sendOTP();
  }

  Widget _buildLoadingOverlay() {
    if (!_isLoading) return SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: AnimatedBuilder(
            animation: _loadingAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing circle
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(0.1),
                              ),
                            ),
                            // Inner animated circle
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryColor,
                                ),
                              ),
                            ),
                            // Center icon
                            Icon(
                              Icons.phone_android,
                              color: primaryColor,
                              size: 28,
                            ),
                          ],
                        ),
                        24.height,
                        Text(
                          _loadingMessage,
                          style: boldTextStyle(
                            size: 16,
                            color: mainColorText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        8.height,
                        Text(
                          language.pleaseWait,
                          style: secondaryTextStyle(
                            size: 14,
                            color: gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Description
          Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              language.pleaseVerifyPhoneNumberDescription,
              style: boldTextStyle(
                color: mainColorText,
                weight: FontWeight.w400,
                size: 16,
              ),
            ),
          ),
          24.height,

          // Phone Number Input Section
          if (!_isVerified) ...[
            Text(
              language.phoneNumber,
              style: boldTextStyle(
                color: mainColorText,
                weight: FontWeight.w500,
                size: 14,
              ),
            ),
            8.height,
            Container(
              decoration: boxDecorationWithRoundedCorners(
                borderRadius: BorderRadius.circular(12),
                backgroundColor: Colors.white,
                border: Border.all(color: gray.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  CountryCodePicker(
                    onChanged: (CountryCode countryCode) {
                      setState(() {
                        _selectedCountryCode = countryCode.dialCode ?? "+243";
                        _selectedCountryIsoCode = countryCode.code ?? "CD";
                      });
                    },
                    initialSelection: _selectedCountryIsoCode,
                    favorite: ['US', 'FR', 'GB', 'DE'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    textStyle: boldTextStyle(size: 16),
                    flagWidth: 24,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: gray.withOpacity(0.3),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: language.enterPhoneNumber,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        hintStyle: secondaryTextStyle(),
                      ),
                      style: boldTextStyle(size: 16),
                      enabled: !_isVerified,
                    ),
                  ),
                ],
              ),
            ),
            24.height,
            
            // Send OTP Button - Only show if OTP not sent yet
            if (!_isOTPSent)
              AppButton(
                text: language.sendVerificationCode,
                width: context.width(),
                onTap: _sendOTP,
              ),
          ],

          // OTP Input Section
          if (_isOTPSent && !_isVerified) ...[
            Text(
              language.enterVerificationCode,
              style: boldTextStyle(
                color: mainColorText,
                weight: FontWeight.w500,
                size: 14,
              ),
            ),
            8.height,
            PinCodeTextField(
              appContext: context,
              length: 4,
              controller: _otpController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 56,
                fieldWidth: 56,
                activeFillColor: Colors.white,
                inactiveFillColor: Colors.white,
                selectedFillColor: Colors.white,
                activeColor: primaryColor,
                inactiveColor: gray.withOpacity(0.3),
                selectedColor: primaryColor,
                borderWidth: 2,
              ),
              enableActiveFill: true,
              onCompleted: (value) {
                _verifyOTP();
              },
              onChanged: (value) {},
            ),
            16.height,
            
            // Verify Button
            AppButton(
              text: language.verifyCode,
              width: context.width(),
              onTap: _verifyOTP,
            ),
            16.height,
            
            // Resend OTP
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  language.didntReceiveCode,
                  style: secondaryTextStyle(size: 14),
                ),
                if (_resendTimer > 0)
                  Text(
                    language.resendInSeconds.replaceAll('%s', _resendTimer.toString()),
                    style: secondaryTextStyle(
                      size: 14,
                      color: gray,
                    ),
                  )
                else
                  Text(
                    language.resendCode,
                    style: boldTextStyle(
                      size: 14,
                      color: primaryColor,
                    ),
                  ).onTap(() {
                    _resendOTP();
                  }),
              ],
            ),
          ],

          // Verified Success State
          if (_isVerified) ...[
            Container(
              padding: EdgeInsets.all(20),
              decoration: boxDecorationWithRoundedCorners(
                borderRadius: BorderRadius.circular(12),
                backgroundColor: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                  16.width,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.phoneNumberVerified,
                          style: boldTextStyle(
                            size: 16,
                            color: Colors.green,
                          ),
                        ),
                        4.height,
                        Text(
                          "${_selectedCountryCode} ${_phoneController.text.maskPhoneNumber()}",
                          style: secondaryTextStyle(size: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
          ),
        ),
        _buildLoadingOverlay(),
      ],
    );
  }
}

