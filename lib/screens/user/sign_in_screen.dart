
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/screens/screens.dart';
import 'package:era_flutter/utils/app_images.dart';
import 'package:era_flutter/utils/dynamic_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import 'forgot_password_screen.dart';

class UserSignInScreen extends StatefulWidget {
  const UserSignInScreen({super.key});

  @override
  State<UserSignInScreen> createState() => _UserSignInScreenState();
}

class _UserSignInScreenState extends State<UserSignInScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  FocusNode passFocus = FocusNode();
  FocusNode emailFocus = FocusNode();

  bool _passwordVisible = false;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    init();
    logScreenView("SignIn screen");
  }

  init() async {
    appStore.setLoading(false);
    setState(() {});

    if (getBoolAsync(IS_REMEMBER)) {
      emailController.text = getStringAsync(EMAIL);
      passwordController.text = getStringAsync(PASSWORD);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      appStore.setLoading(true);
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      printEraAppLogs('Error: $e');
      return null;
    }
  }

  Future<void> loginWithGoogle(UserCredential credential) async {
    try {
      appStore.setLoading(true);

      final user = credential.user!;
      final email = user.email ?? '';
      final password = email;
      //
      // emailController.text = "";
      // passwordController.text = "";

      await loginApi(isFormAutoValid: true, email: email, password: password);
    } catch (e) {
      toast(e.toString());
    } finally {
      appStore.setLoading(false);
    }
  }

  Future<void> loginApi(
      {bool? isFormAutoValid, String? email, String? password}) async {
    hideKeyboard(context);
    passFocus.unfocus();
    emailFocus.unfocus();
    bool formCurrentState = isFormAutoValid != null
        ? isFormAutoValid
        : formKey.currentState!.validate();
    if (formCurrentState) {
      Map<String, dynamic> req = {
        'email': email,
        'user_type': "app_user",
        'password': password,
      };
      appStore.setLoading(true);
      await logInAsUserApi(req).then((value) async {
        if (value.status == false) {
          toast(value.message);
          appStore.setLoading(false);
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
          if (getBoolAsync(IS_REMEMBER)) {
            userStore.setUserPassword(passwordController.text.trim());
          }
          await setValue(USER_TYPE, APP_USER);
          await setValue(IS_LOGIN, true);
          DashboardScreen(currentIndex: 0).launch(context);
        } else {}
      }).catchError((e) {
        appStore.setLoading(false);
      });
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
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.all(8),
                                  child: Image.asset(
                                    ic_logo,
                                    height: 39,
                                    width: 27,
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
                                // Email Field
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white),
                                  ),
                                  child: TextFormField(
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    focusNode: emailFocus,
                                    onEditingComplete: () =>
                                        FocusScope.of(context)
                                            .requestFocus(passFocus),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value.trim().isEmpty) {
                                          _emailError =
                                              language.emailIsRequired;
                                        } else if (!RegExp(
                                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                            .hasMatch(value.trim())) {
                                          _emailError =
                                              language.pleaseEnterAValidEmail;
                                        } else {
                                          _emailError = null;
                                        }
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        _emailError = language.emailIsRequired;
                                        return _emailError;
                                      }
                                      if (!RegExp(
                                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                          .hasMatch(value.trim())) {
                                        _emailError =
                                            language.pleaseEnterAValidEmail;
                                        return _emailError;
                                      }
                                      _emailError = null;
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: language.email,
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
                                        password:
                                            passwordController.text.trim(),
                                        email: emailController.text.trim());
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
                                16.height,
                                OutlinedButton.icon(
                                  icon: Image.asset(
                                    ic_google,
                                    color: Colors.black,
                                    height: 24,
                                    width: 24,
                                  ),
                                  label: Text(
                                    language.signInWithGoogle,
                                    style: primaryTextStyle(
                                      color: mainColorText,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                  ),
                                  onPressed: () async {
                                    final credential = await signInWithGoogle();
                                    if (credential != null) {
                                      await loginWithGoogle(credential);
                                    }
                                  },
                                ).paddingSymmetric(horizontal: 16),
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
          Observer(
            builder: (context) {
              return Visibility(
                visible: appStore.isLoading,
                child: Center(
                  child: Loader(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
