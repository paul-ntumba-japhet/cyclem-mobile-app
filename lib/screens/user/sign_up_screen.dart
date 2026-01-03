import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/date_time_extensions.dart';
import '../../extensions/extensions.dart';
import '../../main.dart';
import '../../model/user/question_model.dart';
import '../../network/rest_api.dart';
import '../../utils/utils.dart';
import '../screens.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  @override
  void initState() {
    super.initState();
    logScreenView("SignUp screen");
  }

  TextEditingController mFirstNameCount = TextEditingController();
  TextEditingController mLastNameCount = TextEditingController();
  TextEditingController mEmailCount = TextEditingController();
  TextEditingController mPassCount = TextEditingController();

  FocusNode mFNameFocus = FocusNode();
  FocusNode mLNameFocus = FocusNode();
  FocusNode mEmailFocus = FocusNode();
  FocusNode mPassFocus = FocusNode();

  @override
  void dispose() {
    mEmailCount.dispose();
    mPassCount.dispose();
    super.dispose();
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

  Future<void> proceedToRegisterApiCall() async {
    try {
      final credential = await signInWithGoogle();
      if (credential?.user == null) return;

      final user = credential!.user!;
      final displayNameParts = user.displayName?.split(" ") ?? [];
      final firstName = displayNameParts.isNotEmpty ? displayNameParts[0] : "";
      final lastName =
          displayNameParts.length > 1 ? displayNameParts[1] : "Foo";
      final email = user.email ?? "";
      final password = user.email;
      final int age = questionsModel.step7.answerToQuestion2?.isNotEmpty == true
          ? getCurrentAgeFromYear(
              int.tryParse(questionsModel.step7.answerToQuestion2!)!)
          : 0;

      final map = getJSONAsync(KEY_QUESTION_DATA);
      final questionsModelData = QuestionsModel.fromJson(map);
      final step1 = questionsModelData.step1;
      final step3 = questionsModelData.step3;
      final step4 = questionsModelData.step4;
      final step5 = questionsModelData.step5;
      final step6 = questionsModelData.step6;

      final req = {
        "first_name": firstName,
        "last_name": lastName,
        "age": age,
        "email": email,
        "password": password,
        "goal_type": step1.selectedOption == -1 ? 0 : step1.selectedOption,
        "user_type": "app_user",
        "period_start_date": step3.selectedLastPeriodDate!.isEmpty
            ? getDateTimeString(DateTime.now())
            : step3.selectedLastPeriodDate.toString(),
        "cycle_length": step4.selectedOption,
        "period_length": step5.selectedOption,
        "luteal_phase": step6.selectedOption != -1 ? step6.selectedOption : 0,
      };

      final registerResult = await registerApi(req);

      registerResult.fold(
        (errorResponse) {
          toast(errorResponse.message ?? "Registration failed");
        },
        (userModel) {
          userStore
            ..setLogin(true)
            ..setUserModelData(userModel)
            ..setUserID(userModel.id!)
            ..setUserPassword(password!)
            ..setLoginUsertype(APP_USER)
            ..setUserModelData(userModel)
            ..setToken(userModel.apiToken!);

          // Save data to local storage
          saveUserToLocalStorage(userModel);
          setValue(TOKEN, userModel.apiToken);
          setValue(LASTNAME, userModel.lastName);
          setValue(PASSWORD, password);
          setValue(IS_USER_SIGNED_UP, true);

          DashboardScreen(currentIndex: 0).launch(context);
        },
      );
    } catch (e) {
      toast(e.toString());
      rethrow;
    } finally {
      appStore.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Observer(
        builder: (context) {
          return Stack(
            children: [
              Align(
                  alignment: Alignment.bottomCenter,
                  child: Wrap(
                    children: [
                      Container(
                        decoration: boxDecorationWithRoundedCorners(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Align(
                                alignment: Alignment.topLeft,
                                child: Icon(Icons.close, size: 25).onTap(() {
                                  finish(context);
                                })),
                            Text("${language.keepYourHealthDataSafe}",
                                style: boldTextStyle(size: textFontSize_20)),
                            8.height,
                            Text(language.createYourAccountToSaveInformation,
                                style: secondaryTextStyle(),
                                textAlign: TextAlign.center),
                            30.height,
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: boxDecorationWithRoundedCorners(
                                  borderRadius: BorderRadius.circular(20),
                                  backgroundColor:
                                      Colors.grey.withValues(alpha: 0.2)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(ic_google,
                                      height: 20,
                                      width: 20,
                                      color: Colors.black),
                                  10.width,
                                  Text(language.continueWithGoogle,
                                      style:
                                          boldTextStyle(size: textFontSize_14))
                                ],
                              ).center(),
                            ).onTap(() {
                              proceedToRegisterApiCall();
                            }),
                            16.height,
                            if (Platform.isIOS) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: boxDecorationWithRoundedCorners(
                                    borderRadius: BorderRadius.circular(20),
                                    backgroundColor:
                                        Colors.grey.withValues(alpha: 0.2)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.email, size: 20),
                                    10.width,
                                    Text(language.continueWithApple,
                                        style: boldTextStyle(
                                            size: textFontSize_16))
                                  ],
                                ).center(),
                              ),
                            ],
                            16.height,
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Text(language.iWillRegisterLater,
                                      style: boldTextStyle(
                                          color: gray, size: textFontSize_14))
                                  .onTap(() {
                                ProgressScreen()
                                    .launch(context, isNewTask: true);
                              }),
                            ),
                            16.height,
                          ],
                        ).paddingOnly(
                            left: 16, right: 16, top: context.statusBarHeight),
                      ),
                    ],
                  )),
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
