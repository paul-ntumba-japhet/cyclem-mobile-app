import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../utils/app_common.dart';
import '../../utils/dynamic_theme.dart';
import 'reset_password_screen.dart';

class ForgotPasswordPhoneScreen extends StatefulWidget {
  const ForgotPasswordPhoneScreen({super.key});

  @override
  State<ForgotPasswordPhoneScreen> createState() => _ForgotPasswordPhoneScreenState();
}

class _ForgotPasswordPhoneScreenState extends State<ForgotPasswordPhoneScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  final FocusNode phoneFocus = FocusNode();

  String _selectedCountryCode = "+243";
  String _selectedCountryIsoCode = "CD";
  bool _isLoading = false;
  String? _phoneError;

  final TextEditingController _pinController = TextEditingController();
  bool _isCodeSent = false;
  bool _isVerifying = false;
  String? _verificationError;
  int? _forceResendingToken;
  Timer? _resendTimer;
  int _secondsUntilResend = 0;

  String? _verificationId;
  /// Phone string passed to [ResetPasswordScreen] (same format as before: dial code + local digits).
  String? _pendingFullPhone;

  static const int _otpLength = 6;
  static const int _resendCooldownSeconds = 60;

  @override
  void dispose() {
    _resendTimer?.cancel();
    phoneController.dispose();
    phoneFocus.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    logScreenView("Forgot password phone screen");
  }

  String _e164Phone(String fullPhoneNumber) {
    final digits = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return '+$digits';
  }

  String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return language.pleaseEnterValidPhoneNumber;
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'session-expired':
        return 'The verification session expired. Request a new code.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return language.invalidCodeTryAgain;
      case 'missing-verification-code':
        return 'Please enter the full 6-digit code.';
      default:
        return e.message?.isNotEmpty == true ? e.message! : e.code;
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() {
      _secondsUntilResend = _resendCooldownSeconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() {
          _secondsUntilResend = 0;
        });
      } else {
        setState(() {
          _secondsUntilResend--;
        });
      }
    });
  }

  String get _resendLabel {
    if (_secondsUntilResend > 0) {
      return 'Resend code in ${_secondsUntilResend}s';
    }
    return 'Resend code';
  }

  String _maskedPhone(String fullPhoneNumber) {
    final digits = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length <= 4) return fullPhoneNumber;
    final prefixLength = digits.length > 7 ? 3 : 2;
    final suffix = digits.substring(digits.length - 2);
    final prefix = digits.substring(0, prefixLength);
    return '+$prefix****$suffix';
  }

  Future<void> _requestFirebaseCode({required bool isResend}) async {
    String phoneNumber = phoneController.text.trim();
    if (phoneNumber.isEmpty || phoneNumber.length < 8) {
      setState(() {
        _phoneError = language.pleaseEnterValidPhoneNumber;
      });
      return;
    }

    final String fullPhoneNumber = '$_selectedCountryCode$phoneNumber';
    _pendingFullPhone = fullPhoneNumber;
    final String e164 = _e164Phone(fullPhoneNumber);

    setState(() {
      _isLoading = true;
      _verificationError = null;
      if (!isResend) {
        _verificationId = null;
        _pinController.clear();
      }
    });

    try {
      await ensureFirebaseInitialized();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _verificationError = '${language.failedToGetAuthCode}: ${e.toString()}';
      });
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 120),
      forceResendingToken: isResend ? _forceResendingToken : null,
      verificationCompleted: (PhoneAuthCredential credential) {
        Future(() => _finishAfterPhoneVerified(credential));
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _verificationError = _firebaseAuthMessage(e);
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _forceResendingToken = resendToken;
          _isLoading = false;
          _isCodeSent = true;
        });
        _startResendCooldown();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _submitPhoneNumber() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    String phoneNumber = phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() {
        _phoneError = language.phoneNumberRequired;
      });
      return;
    }

    String fullPhoneNumber = '$_selectedCountryCode$phoneNumber';
    String phoneForAPI = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (phoneForAPI.isEmpty || phoneForAPI.length < 8) {
      setState(() {
        _phoneError = language.pleaseEnterValidPhoneNumber;
      });
      return;
    }

    await _requestFirebaseCode(isResend: false);
  }

  Future<void> _resendCode() async {
    if (_secondsUntilResend > 0 || _isLoading || _isVerifying) return;
    await _requestFirebaseCode(isResend: true);
  }

  Future<void> _finishAfterPhoneVerified(PhoneAuthCredential credential) async {
    if (!mounted) return;
    setState(() {
      _isVerifying = true;
      _verificationError = null;
      _isLoading = false;
    });

    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isLoading = false;
      });
      final String fullPhone =
          _pendingFullPhone ?? '$_selectedCountryCode${phoneController.text.trim()}';
      ResetPasswordScreen(
        phoneNumber: fullPhone,
        isFirebaseVerified: true,
      ).launch(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isLoading = false;
        _verificationError = _firebaseAuthMessage(e);
        _pinController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isLoading = false;
        _verificationError = e.toString();
        _pinController.clear();
      });
    }
  }

  Future<void> _verifyCode(String fullPhoneNumber) async {
    String enteredCode = _pinController.text.trim();

    if (enteredCode.length != _otpLength) {
      setState(() {
        _verificationError = 'Please enter the full 6-digit code.';
      });
      return;
    }

    if (_verificationId == null) {
      setState(() {
        _verificationError = language.authCodeNotAvailableTryAgain;
      });
      return;
    }

    _pendingFullPhone = fullPhoneNumber;

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: enteredCode,
    );

    await _finishAfterPhoneVerified(credential);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    color: kPrimaryColor,
                    child: Column(
                      children: [
                        10.height,
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: Icon(
                                CupertinoIcons.back,
                                color: mainColorText,
                              ),
                            ),
                            Text(
                              language.forgotPassword,
                              style: boldTextStyle(
                                size: textFontSize_18,
                                weight: FontWeight.w500,
                                color: mainColorText,
                              ),
                            ),
                          ],
                        ),
                        10.height,
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: context.width(),
                      decoration: const BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Form(
                        key: formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              24.height,
                              Text(
                                language.enterPhoneNumber,
                                style: boldTextStyle(
                                  size: textFontSize_20,
                                  weight: FontWeight.w600,
                                  color: mainColorText,
                                ),
                              ),
                              8.height,
                              Text(
                                language.weWillSendYouCodeToResetPassword,
                                style: primaryTextStyle(
                                  size: textFontSize_14,
                                  color: mainColorBodyText,
                                ),
                              ),
                              32.height,
                              Text(
                                language.phoneNumber,
                                style: boldTextStyle(
                                  size: textFontSize_14,
                                  color: mainColorText,
                                ),
                              ),
                              8.height,
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white),
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
                                      favorite: ['CD', 'US', 'FR', 'GB', 'DE'],
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
                                      child: TextFormField(
                                        controller: phoneController,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.done,
                                        focusNode: phoneFocus,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        onFieldSubmitted: (_) {
                                          _submitPhoneNumber();
                                        },
                                        onChanged: (value) {
                                          setState(() {
                                            if (value.trim().isEmpty) {
                                              _phoneError = language.phoneNumberRequired;
                                            } else if (value.trim().length < 8) {
                                              _phoneError = language.pleaseEnterValidPhoneNumber;
                                            } else {
                                              _phoneError = null;
                                            }
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            _phoneError = language.phoneNumberRequired;
                                            return _phoneError;
                                          }
                                          if (value.trim().length < 8) {
                                            _phoneError = language.pleaseEnterValidPhoneNumber;
                                            return _phoneError;
                                          }
                                          _phoneError = null;
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          hintText: language.enterPhoneNumber,
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          errorStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              32.height,
                              if (!_isCodeSent)
                                AppButton(
                                  disabledColor: ColorUtils.colorPrimary,
                                  text: language.continueText,
                                  elevation: 0,
                                  textStyle: boldTextStyle(
                                    color: Colors.white,
                                    weight: FontWeight.w500,
                                    size: 16,
                                  ),
                                  color: primaryColor,
                                  onTap: _submitPhoneNumber,
                                  width: context.width(),
                                ),
                              if (_isCodeSent) ...[
                                if (_pendingFullPhone != null) ...[
                                  Container(
                                    width: context.width(),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Code sent to ${_maskedPhone(_pendingFullPhone!)}',
                                      style: primaryTextStyle(
                                        size: 13,
                                        color: mainColorBodyText,
                                      ),
                                    ),
                                  ),
                                  16.height,
                                ],
                                Text(
                                  'Enter 6-digit code',
                                  style: boldTextStyle(
                                    color: mainColorText,
                                    weight: FontWeight.w500,
                                    size: 14,
                                  ),
                                ),
                                8.height,
                                PinCodeTextField(
                                  appContext: context,
                                  length: _otpLength,
                                  controller: _pinController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  pinTheme: PinTheme(
                                    shape: PinCodeFieldShape.box,
                                    borderRadius: BorderRadius.circular(12),
                                    fieldHeight: 56,
                                    fieldWidth: 48,
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
                                    _verifyCode(
                                        '$_selectedCountryCode${phoneController.text.trim()}');
                                  },
                                  onChanged: (value) {
                                    setState(() {
                                      _verificationError = null;
                                    });
                                  },
                                ),
                                if (_verificationError != null) ...[
                                  16.height,
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _verificationError!,
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                24.height,
                                AppButton(
                                  disabledColor: ColorUtils.colorPrimary.withOpacity(0.7),
                                  text: _resendLabel,
                                  elevation: 0,
                                  textStyle: boldTextStyle(
                                    color: Colors.white,
                                    weight: FontWeight.w500,
                                    size: 14,
                                  ),
                                  color: _secondsUntilResend > 0
                                      ? primaryColor.withOpacity(0.7)
                                      : primaryColor,
                                  onTap: _secondsUntilResend > 0 ? null : _resendCode,
                                  width: context.width(),
                                ),
                                12.height,
                                AppButton(
                                  disabledColor: ColorUtils.colorPrimary,
                                  text: _isVerifying ? language.verifying : language.verifyCode,
                                  elevation: 0,
                                  textStyle: boldTextStyle(
                                    color: Colors.white,
                                    weight: FontWeight.w500,
                                    size: 16,
                                  ),
                                  color: primaryColor,
                                  onTap: _isVerifying
                                      ? null
                                      : () {
                                          _verifyCode(
                                              '$_selectedCountryCode${phoneController.text.trim()}');
                                        },
                                  width: context.width(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
