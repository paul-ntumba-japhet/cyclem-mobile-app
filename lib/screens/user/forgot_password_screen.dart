import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/dynamic_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

bool mIsDark = false;

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  GlobalKey<FormState> formKey = GlobalKey();

  TextEditingController forgotEmailController = TextEditingController();
  FocusNode emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    init();
    logScreenView("Forgot password screen");
  }

  void init() async {
    //
  }

  Future<void> submit() async {
    emailFocus.unfocus();
    String email = forgotEmailController.text.trim();

    Map req = {
      'email': email,
    };
    appStore.setLoading(true);

    await forgotPasswordApi(req).then((value) {
      if (value.status == false) {
        toast(value.message);
        appStore.setLoading(false);
        return;
      }
      toast(value.message.validate());

      appStore.setLoading(false);

      finish(context);
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
                                    Text(language.email,
                                        style: primaryTextStyle()),
                                    8.height,
                                    AppTextField(
                                      focus: emailFocus,
                                      autoFocus: true,
                                      controller: forgotEmailController,
                                      textFieldType: TextFieldType.EMAIL,
                                      decoration: defaultInputDecoration(
                                        context,
                                        label: language.enterEmail,
                                      ),
                                      errorThisFieldRequired:
                                          language.emailFieldIsRequired,
                                      errorInvalidEmail:
                                          language.EmailIsNotValid,
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
