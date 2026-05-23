
import 'package:country_code_picker/country_code_picker.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/screens/screens.dart';
import 'package:era_flutter/utils/app_images.dart';
import 'package:era_flutter/utils/dynamic_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import 'forgot_password_screen.dart';
import 'questions_list_screen.dart';

class UserSignInScreen extends StatefulWidget {
  const UserSignInScreen({super.key});

  @override
  State<UserSignInScreen> createState() => _UserSignInScreenState();
}

class _UserSignInScreenState extends State<UserSignInScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController phoneController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  FocusNode passFocus = FocusNode();
  FocusNode phoneFocus = FocusNode();

  bool _passwordVisible = false;
  String? _phoneError;
  String? _passwordError;
  String _selectedCountryCode = "+243";
  String _selectedCountryIsoCode = "CD";

  // Loading state management
  bool _isLoading = false;
  String _loadingMessage = "";
  late AnimationController _loadingAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

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
    
    init();
    logScreenView("SignIn screen");
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    phoneFocus.dispose();
    passFocus.dispose();
    super.dispose();
  }

  init() async {
    appStore.setLoading(false);
    setState(() {});

    if (getBoolAsync(IS_REMEMBER)) {
      // Load phone number if saved (phone numbers are typically not saved for security)
      // passwordController.text = getStringAsync(PASSWORD);
    }
  }

  void _setLoading(bool loading, {String message = ""}) {
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: boldTextStyle(
                    size: 18,
                    color: mainColorText,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: primaryTextStyle(
              size: 14,
              color: mainColorBodyText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                language.okayIUnderstand,
                style: boldTextStyle(
                  size: 16,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUserNotAvailableAnimationAndRedirect() async {
    if (!mounted) return;

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
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.blue.shade700,
                    size: 34,
                  ),
                ),
              ),
              16.height,
              Text(
                language.accountNotAvailableCreateOneMessage,
                textAlign: TextAlign.center,
                style: primaryTextStyle(
                  size: 14,
                  color: mainColorBodyText,
                ),
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
    QuestionsListScreen().launch(context, isNewTask: true);
  }

  Future<void> loginApi(
      {bool? isFormAutoValid, String? phoneNumber, String? password}) async {
    hideKeyboard(context);
    passFocus.unfocus();
    phoneFocus.unfocus();
    bool formCurrentState = isFormAutoValid != null
        ? isFormAutoValid
        : formKey.currentState!.validate();
    if (formCurrentState) {
      if (hasInvalidDrcLeadingZero(
        countryCode: _selectedCountryCode,
        phoneNumber: phoneNumber ?? '',
      )) {
        final drcMessage = getDrcLeadingZeroErrorMessage();
        setState(() {
          _phoneError = drcMessage;
        });
        _showErrorDialog(language.loginError, drcMessage);
        return;
      }

      // Combine country code with phone number
      String fullPhoneNumber = '$_selectedCountryCode$phoneNumber';
      // Format phone number (remove + and non-digits for API)
      String phoneForAPI = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      Map<String, dynamic> req = {
        'username': phoneForAPI,
        'password': password,
        'actionDem': 'LoginAct',
      };
      
      // Show loading animation
      _setLoading(true, message: language.authenticating);
      
      try {
        final value = await logInAsUserApi(req);

        if (value.status == false) {
          _setLoading(false);
          _showErrorDialog(
            language.loginFailed,
            value.message ?? language.unableToLogin,
          );
          return;
        }
        
        if (value.data!.status == statusActive) {
          setValue(TOKEN, value.data!.apiToken);
          setValue(GOAL, value.data!.goalType!);
          userStore.setLogin(true);
          userStore.setUserID(value.data!.id!);
          userStore.setToken(value.data!.apiToken.validate());
          userStore.setGoal(value.data!.goalType!);
          userStore.setLoginUsertype(APP_USER);
          userStore.setUserModelData(value.data!);
          
          // Save complete UserModel to SharedPreferences for app restart persistence
          await saveUserToLocalStorage(value.data!);
          
          if (getBoolAsync(IS_REMEMBER)) {
            userStore.setUserPassword(passwordController.text.trim());
          }
          await setValue(USER_TYPE, APP_USER);
          await setValue(IS_LOGIN, true);
          
          _setLoading(false);
          DashboardScreen(currentIndex: 0).launch(context);
        } else {
          _setLoading(false);
          _showErrorDialog(
            language.accountInactive,
            language.accountInactiveMessage,
          );
        }
      } catch (e) {
        _setLoading(false);

        if (e is LoginHttpException) {
          if (e.statusCode == 401) {
            await _showUserNotAvailableAnimationAndRedirect();
            return;
          }
          _showErrorDialog(
            language.loginError,
            e.bodyMessage?.validate().isNotEmpty == true
                ? e.bodyMessage!
                : language.unableToLogin,
          );
          return;
        }

        String errorMessage = language.unexpectedError;
        String errorTitle = language.loginError;
        String errorStr = e.toString();

        if (e == 'invalid_username' || errorStr.contains('invalid_username')) {
          errorMessage = language.invalidCredentials;
        } else if (errorStr.contains('network') ||
            errorStr.contains('connection')) {
          errorMessage = language.networkError;
        } else if (errorStr.isNotEmpty) {
          if (errorStr.contains('Exception:')) {
            errorMessage = errorStr.split('Exception:')[1].trim();
          } else if (errorStr.length < 200) {
            errorMessage = errorStr.replaceAll('Exception: ', '').trim();
          }
        }

        _showErrorDialog(errorTitle, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: mainColorLight,
                pinned: true,
                leading: IconButton(
                  icon: Icon(CupertinoIcons.back, color: mainColor),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  language.login,
                  style: boldTextStyle(
                    color: mainColorText,
                    size: 18,
                    weight: FontWeight.w500,
                  ),
                ),
                titleSpacing: 0,
                expandedHeight: 0,
                elevation: 0,
                surfaceTintColor: mainColorLight,
                forceElevated: true,
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Container(
                      height: 40,
                      color: mainColorLight,
                    ),
                    Transform.translate(
                      offset: Offset(0, -30),
                      child: Container(
                        width: context.width(),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Container(
                          padding: EdgeInsets.only(
                              top: context.statusBarHeight + 16),
                          child: Form(
                            key: formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  height: 90,
                                  width: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.all(10),
                                  child: Image.asset(
                                    black_logo,
                                    height: 56,
                                    width: 40,
                                  ),
                                ),
                                Text('${language.welcomeBack} 🖐',
                                        style: boldTextStyle(
                                            size: textFontSize_24,
                                            weight: FontWeight.w600,
                                            color: mainColorText))
                                    .paddingOnly(top: 16, bottom: 8, left: 16),
                                Text(
                                  language.helloThereLoginInToContinue,
                                  style: primaryTextStyle(
                                      size: textFontSize_16,
                                      weight: FontWeight.w400,
                                      color: mainColorBodyText),
                                ),
                                24.height,
                                // Phone Number Field with Country Code Picker
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
                                          textInputAction: TextInputAction.next,
                                          focusNode: phoneFocus,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          onEditingComplete: () =>
                                              FocusScope.of(context)
                                                  .requestFocus(passFocus),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value.trim().isEmpty) {
                                                _phoneError = language.phoneNumberRequired;
                                              } else if (hasInvalidDrcLeadingZero(
                                                countryCode: _selectedCountryCode,
                                                phoneNumber: value.trim(),
                                              )) {
                                                _phoneError = getDrcLeadingZeroErrorMessage();
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
                                            if (hasInvalidDrcLeadingZero(
                                              countryCode: _selectedCountryCode,
                                              phoneNumber: value.trim(),
                                            )) {
                                              _phoneError = getDrcLeadingZeroErrorMessage();
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
                                                horizontal: 12, vertical: 8),
                                            errorStyle: TextStyle(
                                                fontSize: 12, color: Colors.red),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).paddingOnly(top: 16, right: 16, left: 16),
                                // Password Field with Eye Icon
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white),
                                  ),
                                  child: StatefulBuilder(
                                    builder: (context, setState) {
                                      return TextFormField(
                                        controller: passwordController,
                                        obscureText: !_passwordVisible,
                                        focusNode: passFocus,
                                        textInputAction: TextInputAction.done,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value.trim().isEmpty) {
                                              _passwordError =
                                                  language.passwordIsRequired;
                                            } else if (value.trim().length <
                                                6) {
                                              _passwordError = language
                                                  .PasswordMustBeAtLeast;
                                            } else {
                                              _passwordError = null;
                                            }
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            _passwordError =
                                                language.passwordIsRequired;
                                            return _passwordError;
                                          }
                                          if (value.trim().length < 6) {
                                            _passwordError =
                                                language.PasswordMustBeAtLeast;
                                            return _passwordError;
                                          }
                                          _passwordError = null;
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          labelText: language.password,
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _passwordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _passwordVisible =
                                                    !_passwordVisible;
                                              });
                                            },
                                          ),
                                          errorStyle: TextStyle(
                                              fontSize: 12, color: Colors.red),
                                        ),
                                      );
                                    },
                                  ),
                                ).paddingOnly(top: 16, right: 16, left: 16),
                                16.height,
                                AppButton(
                                  disabledColor: ColorUtils.colorPrimary,
                                  text: language.login,
                                  elevation: 0,
                                  textStyle: boldTextStyle(
                                      color: Colors.white,
                                      weight: FontWeight.w500,
                                      size: 16),
                                  color: primaryColor,
                                  onTap: () {
                                    loginApi(
                                        password: passwordController.text.trim(),
                                        phoneNumber: phoneController.text.trim());
                                  },
                                  width: context.width(),
                                ).paddingOnly(top: 16, right: 16, left: 16),
                                TextButton(
                                  onPressed: () {
                                    ForgotPasswordScreen().launch(context);
                                  },
                                  child: Text(
                                    language.forgotPassword + "?",
                                    style: boldTextStyle(
                                        color: mainColor,
                                        weight: FontWeight.w400,
                                        size: 16),
                                  ),
                                ).paddingOnly(top: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
          _buildLoadingOverlay(),
        ],
      ),
    );
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
                              Icons.lock_outline,
                              color: primaryColor,
                              size: 28,
                            ),
                          ],
                        ),
                        24.height,
                        Text(
                          _loadingMessage.isNotEmpty
                              ? _loadingMessage
                              : language.processing,
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
}
