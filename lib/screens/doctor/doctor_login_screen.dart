import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/utils/app_images.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
// import 'package:mm_core/mm_core.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/dynamic_theme.dart';
import '../user/forgot_password_screen.dart';
import 'doctor_dashboard_screen.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  FocusNode passFocus = FocusNode();
  FocusNode emailFocus = FocusNode();

  String? _emailError;
  String? _passwordError;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    appStore.setLoading(false);
    if (getBoolAsync(IS_REMEMBER)) {
      emailController.text = getStringAsync(DR_EMAIL);
      passwordController.text = getStringAsync(PASSWORD);
    }
  }

  Future<void> save() async {
    hideKeyboard(context);
    emailFocus.unfocus();
    passFocus.unfocus();

    Map<String, dynamic> req = {
      'email': emailController.text.trim(),
      'user_type': Doctor,
      'password': passwordController.text.trim(),
    };

    if (formKey.currentState!.validate()) {
      appStore.setLoading(true);
      await logInApi(req).then((value) async {
        if (value.status == false) {
          toast(value.message);
          appStore.setLoading(false);
          return;
        }

        if (value.data!.status == statusActive) {
          userStore.setUserID(value.data!.id!);
          // MmCore.instance!.updateConfiguration(
          //     authToken: value.data!.apiToken!, isPrintLogs: true);
          setValue(TOKEN, value.data!.apiToken);
          setValue(PASSWORD, passwordController.text.trim());
          setValue(DR_EMAIL, emailController.text);
          userStore.setToken(value.data!.apiToken.validate());
          userStore.setDoctorData(value.data!);
          if (getBoolAsync(IS_REMEMBER)) {
            userStore.setDrPassword(passwordController.text.trim());
          }
          await setValue(USER_TYPE, Doctor);
          await setValue(IS_LOGIN, true);
          getDoctorDetail(context).then((value) {
            appStore.setLoading(false);
            DoctorDashboardScreen().launch(context, isNewTask: true);
          }).catchError((e) {});
        } else {
          appStore.setLoading(false);
          toast("User is not active");
          return;
        }
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
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
                                Text('${language.welcomeBack} Dr🖐',
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
                                    save();
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
    // Scaffold(
    //   appBar: appBarWidget('',
    //       context1: context,
    //       showBack: true,
    //       backWidget: Icon(Octicons.chevron_left,
    //               size: textFontSize_28.toDouble(), color: primaryColor)
    //           .onTap(() {
    //         finish(context);
    //       })),
    //   body: Observer(builder: (context) {
    //     return Stack(
    //       children: [
    //         SingleChildScrollView(
    //           padding: EdgeInsets.only(top: context.statusBarHeight + 16),
    //           child: Form(
    //             key: formKey,
    //             autovalidateMode: AutovalidateMode.onUserInteraction,
    //             child: Column(
    //               crossAxisAlignment: CrossAxisAlignment.center,
    //               mainAxisAlignment: MainAxisAlignment.center,
    //               children: <Widget>[
    //                 64.height,
    //                 Image.asset(
    //                   ic_logo,
    //                   height: 120,
    //                   width: 120,
    //                 ),
    //                 Text(language.login,
    //                         style: boldTextStyle(size: textFontSize_22))
    //                     .paddingAll(16),
    //                 Text(
    //                   language.loginText,
    //                   style: primaryTextStyle(size: textFontSize_14),
    //                 ),
    //                 16.height,
    //                 AppTextField(
    //                   controller: emailController,
    //                   textFieldType: TextFieldType.EMAIL,
    //                   errorThisFieldRequired: language.pleaseEnterEmail,
    //                   errorInvalidEmail: language.pleaseEnterValidEmail,
    //                   decoration: InputDecoration(
    //                       labelText: language.email, border: OutlineInputBorder()),
    //                   nextFocus: passFocus,
    //                   autoFillHints: [AutofillHints.email],
    //                 ).paddingOnly(top: 16, right: 16, left: 16),
    //                 AppTextField(
    //                   controller: passwordController,
    //                   textFieldType: TextFieldType.PASSWORD,
    //                   decoration: InputDecoration(
    //                       labelText: language.password,
    //                       border: OutlineInputBorder()),
    //                   focus: passFocus,
    //                   autoFillHints: [AutofillHints.password],
    //                   errorThisFieldRequired: language.pleaseEnterPassword,
    //                   errorMinimumPasswordLength: language.minimumlength,
    //                   onFieldSubmitted: (s) {
    //                     //signIn();
    //                   },
    //                 ).paddingOnly(top: 16, right: 16, left: 16),
    //                 16.height,
    //                 AppButton(
    //                   disabledColor: ColorUtils.colorPrimary,
    //                   text: language.login,
    //                   textStyle: boldTextStyle(color: white),
    //                   color: ColorUtils.colorPrimary,
    //                   onTap: save,
    //                   width: context.width(),
    //                 ).paddingOnly(top: 16, right: 16, left: 16),
    //                 // Add "Forgot Password?" clickable text here
    //                 TextButton(
    //                   onPressed: () {
    //                     ForgotPasswordScreen().launch(context);
    //                   },
    //                   child: Text(
    //                     '${language.forgotPassword} ?',
    //                     style: secondaryTextStyle(
    //                         size: textFontSize_14,
    //                         color: ColorUtils.colorPrimary),
    //                   ),
    //                 ).paddingOnly(top: 8),
    //               ],
    //             ),
    //           ).center(),
    //         ),
    //         Observer(builder: (context) {
    //           return Loader().center().visible(appStore.isLoading);
    //         })
    //       ],
    //     );
    //   }));
  }
}
