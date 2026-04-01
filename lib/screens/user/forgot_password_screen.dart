import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/dynamic_theme.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

bool mIsDark = false;

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  GlobalKey<FormState> formKey = GlobalKey();

  TextEditingController phoneController = TextEditingController();
  FocusNode phoneFocus = FocusNode();
  String _selectedCountryCode = "+243";
  String _selectedCountryIsoCode = "CD";
  String? _pendingFullPhone;
  String? _serverAuthCode;

  @override
  void initState() {
    super.initState();
    init();
    logScreenView("Forgot password screen");
  }

  void init() async {
    //
  }

  Future<bool> _requestAuthenticationCode({
    required String fullPhone,
    bool showSuccessToast = false,
  }) async {
    appStore.setLoading(true);
    try {
      final code = await autenticationCode(fullPhone);
      _pendingFullPhone = fullPhone;
      _serverAuthCode = code;
      appStore.setLoading(false);
      if (showSuccessToast) {
        toast('Code sent successfully.');
      }
      return true;
    } catch (e) {
      appStore.setLoading(false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      toast(msg.isNotEmpty ? msg : language.failedToGetAuthCode);
      return false;
    }
  }

  Future<void> submit() async {
    phoneFocus.unfocus();
    final String phone = phoneController.text.trim();
    final String fullPhone = '$_selectedCountryCode$phone';

    final ok = await _requestAuthenticationCode(fullPhone: fullPhone);
    if (ok) {
      _showOtpDialog();
    }
  }

  Future<void> _showOtpDialog() async {
    final TextEditingController pinController = TextEditingController();
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(language.verifyCode),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(language.enterFiveDigitCode),
                  12.height,
                  PinCodeTextField(
                    appContext: context,
                    controller: pinController,
                    length: 5,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(8),
                      fieldHeight: 48,
                      fieldWidth: 40,
                      activeColor: primaryColor,
                      selectedColor: primaryColor,
                      inactiveColor: gray.withOpacity(0.4),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setDialogState(() {
                          errorMessage = null;
                        });
                      }
                    },
                  ),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(language.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    if (_pendingFullPhone == null ||
                        _pendingFullPhone!.isEmpty) {
                      final String phone = phoneController.text.trim();
                      _pendingFullPhone = '$_selectedCountryCode$phone';
                    }
                    if (errorMessage != null) {
                      setDialogState(() {
                        errorMessage = null;
                      });
                    }
                    await _requestAuthenticationCode(
                      fullPhone: _pendingFullPhone!,
                      showSuccessToast: true,
                    );
                  },
                  child: const Text("Resend code"),
                ),
                TextButton(
                  onPressed: () {
                    final entered = pinController.text.trim();
                    if (entered.length != 5) {
                      setDialogState(() {
                        errorMessage = language.pleaseEnterCompleteFiveDigitCode;
                      });
                      return;
                    }
                    if (entered != (_serverAuthCode ?? '')) {
                      setDialogState(() {
                        errorMessage = language.invalidCodeTryAgain;
                      });
                      return;
                    }
                    Navigator.pop(dialogContext);
                    if (_pendingFullPhone != null) {
                      ResetPasswordScreen(phoneNumber: _pendingFullPhone!)
                          .launch(context);
                    }
                  },
                  child: Text(language.verifyCode),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
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
                      child: Column(
                        children: [
                          Expanded(
                            child: Form(
                              key: formKey,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                    left: 16, top: 30, right: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(language.phoneNumber,
                                        style: primaryTextStyle()),
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
                                                _selectedCountryCode =
                                                    countryCode.dialCode ?? "+243";
                                                _selectedCountryIsoCode =
                                                    countryCode.code ?? "CD";
                                              });
                                            },
                                            initialSelection:
                                                _selectedCountryIsoCode,
                                            favorite: const ['CD', 'US', 'FR'],
                                            showCountryOnly: false,
                                            showOnlyCountryWhenClosed: false,
                                            alignLeft: false,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
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
                                              focusNode: phoneFocus,
                                              controller: phoneController,
                                              keyboardType: TextInputType.phone,
                                              textInputAction:
                                                  TextInputAction.done,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              validator: (value) {
                                                final v = value?.trim() ?? '';
                                                if (v.isEmpty) {
                                                  return language
                                                      .phoneNumberRequired;
                                                }
                                                if (v.length < 8) {
                                                  return language
                                                      .pleaseEnterValidPhoneNumber;
                                                }
                                                return null;
                                              },
                                              decoration: InputDecoration(
                                                hintText:
                                                    language.enterPhoneNumber,
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                errorStyle: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    16.height,
                                  ],
                                ).center(),
                              ),
                            ),
                          ),
                          AppButton(
                            disabledColor: ColorUtils.colorPrimary,
                            text: language.submit,
                            textStyle: boldTextStyle(color: white),
                            color: primaryColor,
                            onTap: () {
                              if (formKey.currentState!.validate()) {
                                submit();
                              }
                            },
                            width: context.width(),
                          ).paddingAll(16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Observer(
                builder: (context) => Loader().visible(appStore.isLoading),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
