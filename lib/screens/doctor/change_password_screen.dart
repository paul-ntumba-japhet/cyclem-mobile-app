import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/dynamic_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isFromDoctor;

  const ChangePasswordScreen({super.key, required this.isFromDoctor});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController oldPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  FocusNode oldPassFocus = FocusNode();
  FocusNode newPassFocus = FocusNode();
  FocusNode confirmPassFocus = FocusNode();

  unFocus() {
    oldPassFocus.unfocus();
    newPassFocus.unfocus();
    confirmPassFocus.unfocus();
  }

  Future<void> submit() async {
    unFocus();
    Map req = {
      'old_password': oldPasswordController.text.trim(),
      'new_password': newPasswordController.text.trim(),
    };
    appStore.setLoading(true);

    await changeHealthExpertPasswordApi(req).then((value) {
      appStore.setLoading(false);

      if (value.status == true) {
        toast(value.message.toString());
        finish(context);
      } else {
        toast(value.message);
        return;
      }
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
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
                  // Custom Header
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
                              language.changePassword,
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
                  // Scrollable Content
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
                          // Scrollable Form
                          Expanded(
                            child: Form(
                              key: formKey,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(
                                    left: 16, top: 16, right: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    10.height,
                                    AppTextField(
                                      controller: oldPasswordController,
                                      textFieldType: TextFieldType.PASSWORD,
                                      decoration: InputDecoration(
                                        labelText: language.oldPassword,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              defaultRadius),
                                        ),
                                      ),
                                      focus: oldPassFocus,
                                      autoFillHints: [AutofillHints.password],
                                      errorThisFieldRequired:
                                          language.pleaseEnterPassword,
                                      errorMinimumPasswordLength:
                                          language.minimumlength,
                                    ),
                                    16.height,
                                    AppTextField(
                                      controller: newPasswordController,
                                      textFieldType: TextFieldType.PASSWORD,
                                      decoration: InputDecoration(
                                        labelText: language.newPassword,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              defaultRadius),
                                        ),
                                      ),
                                      focus: newPassFocus,
                                      autoFillHints: [AutofillHints.password],
                                      errorThisFieldRequired:
                                          language.pleaseEnterPassword,
                                      errorMinimumPasswordLength:
                                          language.minimumlength,
                                    ),
                                    16.height,
                                    AppTextField(
                                      controller: confirmPasswordController,
                                      textFieldType: TextFieldType.PASSWORD,
                                      decoration: InputDecoration(
                                        labelText: language.confirmPassword,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              defaultRadius),
                                        ),
                                      ),
                                      focus: confirmPassFocus,
                                      autoFillHints: [AutofillHints.password],
                                      errorThisFieldRequired:
                                          language.PleaseConfirmYourPassword,
                                      errorMinimumPasswordLength:
                                          language.minimumlength,
                                      validator: (value) {
                                        if (value !=
                                            newPasswordController.text) {
                                          return language.passwordDoNotMatch;
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ).center(),
                              ),
                            ),
                          ),
                          // Former bottomNavigationBar Content
                          AppButton(
                            disabledColor: ColorUtils.colorPrimary,
                            text: language.changePassword,
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
