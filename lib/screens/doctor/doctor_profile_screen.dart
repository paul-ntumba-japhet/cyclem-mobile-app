import 'package:era_flutter/extensions/colors.dart';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/int_extensions.dart';
import 'package:era_flutter/extensions/extension_util/widget_extensions.dart';
import 'package:era_flutter/main.dart';
import 'package:era_flutter/screens/doctor/pending_questions_screen.dart';
import 'package:era_flutter/utils/app_constants.dart';
import 'package:flutter/material.dart';

import '../../components/common/settings_components.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/decorations.dart';
import '../../extensions/new_colors.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/text_styles.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/app_images.dart';
import '../../utils/dynamic_theme.dart';
import '../user/about_screen.dart';
import '../user/bookmark_screen.dart';
import '../user/calculator/calculator_screen.dart';
import '../user/inter_settings_screen.dart';
import 'doctor_blog_screen.dart';
import 'edit_profile_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Widget mSettingOption(String mTitle, String mImg, Function onTapCall) {
    return SettingItemWidget(
      onTap: () {
        onTapCall.call();
      },
      title: mTitle,
      leading: Image.asset(mImg, height: 24, width: 24, color: primaryColor),
      trailing: Icon(Icons.arrow_forward_ios_sharp, color: grayColor, size: 18),
      paddingAfterLeading: 10,
      paddingBeforeTrailing: 10,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  color: mainColorLight,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  language.profile,
                                  style: boldTextStyle(
                                    color: Colors.black,
                                    size: 18,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 90,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          decoration:
                                              boxDecorationWithRoundedCorners(
                                                  boxShape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: mainColorBodyText,
                                                      width: 1.4)),
                                          child: cachedImage(
                                                  getStringAsync(
                                                      DR_PROFILE_IMG),
                                                  height: 70,
                                                  width: 70,
                                                  fit: BoxFit.cover)
                                              .cornerRadiusWithClipRRect(70),
                                        ).onTap(() async {
                                          await DoctorEditProfileScreen()
                                              .launch(context);
                                          setState(() {});
                                        }),
                                        Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: mainColorBodyText,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Image.asset(
                                              ic_pen,
                                              height: 14,
                                              width: 14,
                                            )).onTap(() async {
                                          await DoctorEditProfileScreen()
                                              .launch(context);
                                          setState(() {});
                                        }),
                                      ],
                                    ),
                                    16.width,
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            getStringAsync(DR_NAME).trim(),
                                            style: boldTextStyle(
                                              color: mainColorText,
                                              size: 18,
                                              weight: FontWeight.w500,
                                            ),
                                          ),
                                          4.height,
                                          Text(
                                            getStringAsync(DR_EMAIL),
                                            style: boldTextStyle(
                                              color: mainColorBodyText,
                                              size: 12,
                                              weight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: bgColor,
                  ),
                  child: Column(
                    children: [
                      16.height,
                      mSettingOption(language.MyBlogs, ic_dialog, () {
                        DoctorBlogScreen(isFromTabs: false).launch(context);
                      }),
                      10.height,
                      mSettingOption(
                          language.pendingQuestions, ic_question_mark, () {
                        PendingQuestionsScreen().launch(context);
                        //MyQuestionScreen().launch(context);
                      }),
                      10.height,
                      mSettingOption(language.bookmark, ic_bookmark2, () {
                        BookmarkScreen().launch(context);
                      }),
                      10.height,
                      mSettingOption(language.calculatorTools, ic_calculator,
                          () {
                        CalculatorScreen(isFromDoctor: true).launch(context);
                      }),
                      10.height,
                      mSettingOption(language.settings, ic_settings2, () {
                        InterSettingsScreen().launch(context);
                      }),
                      10.height,
                      mSettingOption(language.about, ic_info, () {
                        AboutScreen().launch(context);
                      }),
                      10.height,
                      mSettingOption(language.logout, ic_logout2, () {
                        showConfirmDialogCustom(
                          image: ic_logout2,
                          bgColor: context.cardColor,
                          iconColor: ColorUtils.colorPrimary,
                          context,
                          negativeBg: context.cardColor,
                          primaryColor: ColorUtils.colorPrimary,
                          title: language.areYouSureLogout,
                          positiveText: language.logout,
                          height: 100,
                          onAccept: (c) {
                            logout(context: context);
                          },
                        );
                      }),
                      10.height,
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
