import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/dynamic_theme.dart';
import 'package:era_flutter/screens/user/sign_in_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isFirebaseVerified;

  const ResetPasswordScreen({
    super.key,
    required this.phoneNumber,
    this.isFirebaseVerified = false,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode confirmPasswordFocus = FocusNode();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    logScreenView("Reset password screen");
  }

  Future<void> _resetPassword() async {
    if (!widget.isFirebaseVerified) {
      toast('Phone verification is required before resetting password.');
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      toast(language.passwordDoNotMatch);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the reset password API
      final result = await resetPassword(
        phoneNumber: widget.phoneNumber,
        newPassword: password,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['status'] == true || result['code'] == '200') {
        toast(result['message']?.toString() ?? language.passwordResetSuccess);
        
        // Navigate to sign in screen
        UserSignInScreen().launch(context, isNewTask: true);
      } else {
        toast(result['message']?.toString() ?? language.failedToResetPassword);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Extract error message
      String errorMessage = language.errorResettingPassword;
      String errorStr = e.toString();
      if (errorStr.contains("Exception:")) {
        errorMessage = errorStr.split("Exception:")[1].trim();
      } else if (errorStr.length < 200) {
        errorMessage = errorStr.replaceAll("Exception: ", "").trim();
      }
      
      toast(errorMessage);
    }
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
                              language.resetPassword,
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
                                language.createNewPassword,
                                style: boldTextStyle(
                                  size: textFontSize_20,
                                  weight: FontWeight.w600,
                                  color: mainColorText,
                                ),
                              ),
                              8.height,
                              Text(
                                language.pleaseEnterNewPasswordBelow,
                                style: primaryTextStyle(
                                  size: textFontSize_14,
                                  color: mainColorBodyText,
                                ),
                              ),
                              32.height,
                              // Password Field
                              Text(
                                language.password,
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
                                child: TextFormField(
                                  controller: passwordController,
                                  obscureText: !_passwordVisible,
                                  focusNode: passwordFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(confirmPasswordFocus);
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return language.passwordIsRequired;
                                    }
                                    if (value.trim().length < 6) {
                                      return language.PasswordMustBeAtLeast;
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: language.enterNewPassword,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _passwordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _passwordVisible = !_passwordVisible;
                                        });
                                      },
                                    ),
                                    errorStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                              24.height,
                              // Confirm Password Field
                              Text(
                                language.confirmPassword,
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
                                child: TextFormField(
                                  controller: confirmPasswordController,
                                  obscureText: !_confirmPasswordVisible,
                                  focusNode: confirmPasswordFocus,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    _resetPassword();
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return language.PleaseConfirmYourPassword;
                                    }
                                    if (value != passwordController.text) {
                                      return language.passwordDoNotMatch;
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: language.confirmPassword,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _confirmPasswordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _confirmPasswordVisible = !_confirmPasswordVisible;
                                        });
                                      },
                                    ),
                                    errorStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                              32.height,
                              // Reset Password Button
                              AppButton(
                                disabledColor: ColorUtils.colorPrimary,
                                text: language.resetPassword,
                                elevation: 0,
                                textStyle: boldTextStyle(
                                  color: Colors.white,
                                  weight: FontWeight.w500,
                                  size: 16,
                                ),
                                color: primaryColor,
                                onTap: _resetPassword,
                                width: context.width(),
                              ),
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
