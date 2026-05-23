import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../model/user/question_model.dart';
import '../../model/user/user_models/user_model.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import 'sign_in_screen.dart';
//import '../../extensions/app_text_field.dart';
import '../screens.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isAccountAlreadyExistsError(String? message) {
    if (message == null) return false;

    final normalized = message.toLowerCase();
    return normalized.contains('409') ||
        normalized.contains('already exists') ||
        normalized.contains('already exist') ||
        normalized.contains('already registered') ||
        normalized.contains('user already exists') ||
        normalized.contains('existe deja') ||
        normalized.contains('existe déjà');
  }

  Future<void> _showAccountExistsAnimationAndRedirect() async {
    if (!mounted) return;

    final message = language.accountAlreadyExistsRedirectMessage;
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                tween: Tween<double>(begin: 0.6, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_search_rounded,
                    color: Colors.orange.shade700,
                    size: 34,
                  ),
                ),
              ),
              16.height,
              Text(
                message,
                textAlign: TextAlign.center,
                style: primaryTextStyle(size: 14),
              ),
              14.height,
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ],
          ),
        );
      },
    );

    await Future.delayed(Duration(seconds: 2));

    if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
      Navigator.of(dialogContext!).pop();
    }

    if (!mounted) return;
    UserSignInScreen().launch(context, isNewTask: true);
  }

  @override
  void initState() {
    super.initState();
    logScreenView("SignUp screen");
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Get phone number from step2Phone
    String? phoneNumber = questionsModel.step2Phone.phoneNumber;
    String? countryCode = questionsModel.step2Phone.countryCode ?? "+1";

    if (phoneNumber == null || phoneNumber.isEmpty) {
      toast(language.phoneNumberNotFound);
      return;
    }

    if (hasInvalidDrcLeadingZero(
      countryCode: countryCode,
      phoneNumber: phoneNumber,
    )) {
      toast(getDrcLeadingZeroErrorMessage());
      return;
    }

    // Format phone number with country code
    String fullPhoneNumber = '$countryCode$phoneNumber';
    fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!fullPhoneNumber.startsWith('+')) {
      fullPhoneNumber = '+$fullPhoneNumber';
    }

    appStore.setLoading(true);

    try {
      final loginResult = await loginWithPhoneAndCode(
        phoneNumber: fullPhoneNumber,
        password: _passwordController.text.trim(),
      );

      appStore.setLoading(false);

      if (loginResult.status == false || loginResult.data == null) {
        final errorMessage =
            loginResult.message ?? language.loginFailedPleaseCheckCredentials;
        if (_isAccountAlreadyExistsError(errorMessage)) {
          await _showAccountExistsAnimationAndRedirect();
          return;
        }
        toast(errorMessage);
        return;
      }

      final userModel = loginResult.data!;

      // Set up user store for dashboard
      userStore
        ..setLogin(true)
        ..setUserModelData(userModel)
        ..setUserID(userModel.id!)
        ..setUserPassword(_passwordController.text.trim())
        ..setLoginUsertype(APP_USER)
        ..setToken(userModel.apiToken!);

      // Save data to local storage
      saveUserToLocalStorage(userModel);
      setValue(TOKEN, userModel.apiToken);
      setValue(LASTNAME, userModel.lastName ?? "");
      setValue(PASSWORD, _passwordController.text.trim());
      setValue(IS_USER_SIGNED_UP, true);
      setValue(USER_TYPE, APP_USER);
      setValue(IS_LOGIN, true);

      // Update configuration for dashboard
      await _updateConfiguration(userModel);

      // Navigate to loading screen with progress (0-100%)
      SignupLoadingScreen().launch(context, isNewTask: true);
    } catch (e) {
      appStore.setLoading(false);
      final rawError = e.toString();
      final cleanError = rawError.startsWith('Exception:')
          ? rawError.replaceFirst('Exception:', '').trim()
          : rawError;
      if (_isAccountAlreadyExistsError(cleanError)) {
        await _showAccountExistsAnimationAndRedirect();
        return;
      }
      toast(cleanError.isNotEmpty ? cleanError : language.somethingWentWrong);
    }
  }

  Future<void> _updateConfiguration(UserModel userModel) async {
    // Update cycle and period settings from user model or question data
    int cycleLength = userModel.cycleLength ?? 
        questionsModel.step4.selectedOption ?? 
        DEFAULT_CYCLE_LENGTH;
    int periodLength = userModel.periodLength ?? 
        questionsModel.step5.selectedOption ?? 
        DEFAULT_PERIOD_LENGTH;

    if (cycleLength == 0) {
      cycleLength = DEFAULT_CYCLE_LENGTH;
    }
    if (periodLength == 0) {
      periodLength = DEFAULT_PERIOD_LENGTH;
    }

    // Set in userStore and SharedPreferences
    userStore.setCycleLength(cycleLength);
    userStore.setPeriodsLength(periodLength);
    setValue(CYCLE_LENGTH, cycleLength);
    setValue(PERIOD_LENGTH, periodLength);

    // The full updateConfiguration (including menstrual cycle widget) 
    // will be handled by the DashboardScreen when it initializes
    // No need to call it here as it requires MenstrualCycleWidget.instance
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: mainColorLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: mainColorText),
          onPressed: () => finish(context),
        ),
        title: Text(
          language.completeRegistration,
          style: boldTextStyle(
            color: mainColorText,
            size: 18,
            weight: FontWeight.w500,
          ),
        ),
      ),
      body: Observer(
        builder: (context) {
          // Explicitly observe language changes to ensure rebuild
          final _ = appStore.selectedLanguage;
          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          language.enterYourPassword,
                          style: boldTextStyle(
                            color: mainColorText,
                            weight: FontWeight.w400,
                            size: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      32.height,

                      // Password Field
                      Text(
                        language.password,
                        style: boldTextStyle(
                          color: mainColorText,
                          weight: FontWeight.w500,
                          size: 14,
                        ),
                      ),
                      8.height,
                      AppTextField(
                        controller: _passwordController,
                        textFieldType: TextFieldType.PASSWORD,
                        focus: _passwordFocus,
                        nextFocus: _confirmPasswordFocus,
                        decoration: InputDecoration(
                          hintText: language.enterYourPassword,
                          labelText: language.password,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gray.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gray.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        isValidationRequired: true,
                        errorThisFieldRequired: language.pleaseEnterPassword,
                        errorMinimumPasswordLength: language.passwordMustHaveAtLeastSixCharacters,
                      ),
                      24.height,

                      // Confirm Password Field
                      Text(
                        language.confirmPassword,
                        style: boldTextStyle(
                          color: mainColorText,
                          weight: FontWeight.w500,
                          size: 14,
                        ),
                      ),
                      8.height,
                      AppTextField(
                        controller: _confirmPasswordController,
                        textFieldType: TextFieldType.PASSWORD,
                        focus: _confirmPasswordFocus,
                        decoration: InputDecoration(
                          hintText: language.confirmYourPassword,
                          labelText: language.confirmPassword,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gray.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gray.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        isValidationRequired: true,
                        errorThisFieldRequired: language.pleaseConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return language.pleaseConfirmPassword;
                          }
                          if (value != _passwordController.text.trim()) {
                            return language.passwordsDoNotMatch;
                          }
                          return null;
                        },
                      ),
                      32.height,

                      // Sign Up Button
                      AppButton(
                        text: language.completeRegistration,
                        width: context.width(),
                        onTap: _handleSignUp,
                      ),
                      24.height,
                    ],
                  ),
                ),
              ),
              if (appStore.isLoading)
                Center(
                  child: Loader(),
                ),
            ],
          );
        },
      ),
    );
  }
}
