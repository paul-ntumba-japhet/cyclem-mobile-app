import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/utils/app_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart' as fwfh;
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../model/doctor/doctor_models/update_doctor_response.dart';
import '../../network/network_utils.dart';
import '../../utils/app_common.dart';
import '../../utils/app_images.dart';
import '../../utils/dynamic_theme.dart';
import 'html_edit_screen.dart';

class DoctorEditProfileScreen extends StatefulWidget {
  const DoctorEditProfileScreen({super.key});

  @override
  State<DoctorEditProfileScreen> createState() =>
      _DoctorEditProfileScreenState();
}

class _DoctorEditProfileScreenState extends State<DoctorEditProfileScreen> {
  TextEditingController NameController = TextEditingController();
  TextEditingController EmailController = TextEditingController();
  TextEditingController TagLineController = TextEditingController();

  String shortDescHtml = '';
  String careerHtml = '';
  String educationHtml = '';
  String awardsHtml = '';
  String expertiseHtml = '';

  FocusNode NameFocus = FocusNode();
  FocusNode EmailFocus = FocusNode();
  FocusNode TaglineFocus = FocusNode();

  String? profileImg = '';
  XFile? image;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    TagLineController.text = getStringAsync(DR_TAGLINE);
    EmailController.text = getStringAsync(DR_EMAIL);
    NameController.text = getStringAsync(DR_NAME);
    profileImg = getStringAsync(DR_PROFILE_IMG);
    shortDescHtml = getStringAsync(DR_DESC);
    careerHtml = getStringAsync(DR_CAREER);
    educationHtml = getStringAsync(DR_EDUCATION);
    awardsHtml = getStringAsync(DR_AWARDS);
    expertiseHtml = getStringAsync(DR_EXPERTISE);
  }

  Future getImage() async {
    image = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 100);
    setState(() {});
  }

  Future getImageFromCamera() async {
    image = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 100);
    if (image != null) {
      setState(() {});
    }
  }

  Future save() async {
    hideKeyboard(context);
    appStore.setLoading(true);

    MultipartRequest multipartRequest =
        await getMultiPartRequest('update-doctor-profile');
    multipartRequest.fields['name'] = NameController.text;
    multipartRequest.fields['tag_line'] = TagLineController.text;
    multipartRequest.fields['short_description'] = shortDescHtml;
    multipartRequest.fields['career'] = careerHtml;
    multipartRequest.fields['education'] = educationHtml;
    multipartRequest.fields['awards_achievements'] = awardsHtml;
    multipartRequest.fields['area_expertise'] = expertiseHtml;

    if (image != null) {
      multipartRequest.files.add(await MultipartFile.fromPath(
          'health_experts_image', image!.path.toString()));
    }
    multipartRequest.headers.addAll(buildHeaderTokens());

    sendMultiPartRequest(
      multipartRequest,
      onSuccess: (data) async {
        if ((data as String).isJson()) {
          UpdateDoctorResponse res =
              UpdateDoctorResponse.fromJson(jsonDecode(data)['responseData']);
          userStore.setDrName(res.data!.name.validate());
          userStore.setDrDesc(res.data!.shortDescription.validate());
          userStore.setDrTagline(res.data!.tagLine.validate());
          userStore.setDRprofileImage(res.data!.healthExpertsImage.validate());
          userStore.setDrCareer(res.data!.career.validate());
          userStore.setDrEducation(res.data!.education.validate());
          userStore.setDrAwards(res.data!.awardsAchievements.validate());
          userStore.setDrExpertise(res.data!.areaExpertise.validate());
          userStore.setDRprofileImage(res.data!.healthExpertsImage.validate());
          appStore.setLoading(false);
          finish(context, true);
        }
      },
      onError: (error) {
        log(multipartRequest.toString());
        toast(error.toString());
        appStore.setLoading(false);
      },
    ).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  Widget profileImage() {
    if (image != null) {
      return Container(
        padding: EdgeInsets.all(1),
        decoration: boxDecorationWithRoundedCorners(
            boxShape: BoxShape.circle,
            border: Border.all(width: 2, color: primaryColor.withOpacity(0.5))),
        child: Image.file(File(image!.path),
                height: 100, width: 100, fit: BoxFit.cover)
            .cornerRadiusWithClipRRect(65),
      );
    } else if (!profileImg.isEmptyOrNull) {
      return Container(
        padding: EdgeInsets.all(1),
        decoration: boxDecorationWithRoundedCorners(
            boxShape: BoxShape.circle,
            border: Border.all(width: 2, color: primaryColor.withOpacity(0.5))),
        child:
            cachedImage(profileImg, width: 100, height: 100, fit: BoxFit.cover)
                .cornerRadiusWithClipRRect(65),
      );
    } else {
      return Container(
        padding: EdgeInsets.all(1),
        decoration: boxDecorationWithRoundedCorners(
            boxShape: BoxShape.circle,
            border: Border.all(width: 2, color: primaryColor.withOpacity(0.5))),
        child: CircleAvatar(
            maxRadius: 50,
            backgroundColor: Colors.white,
            backgroundImage: AssetImage(black_logo)),
      );
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void navigateToEditScreen(
      String field, String content, Function(String) onUpdate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HtmlEditScreen(
          field: field,
          content: content,
          onUpdate: onUpdate,
        ),
      ),
    );
  }

  Widget htmlField(String title, String content, Function(String) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        10.height,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: primaryTextStyle(color: Colors.grey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            IconButton(
              icon: Icon(Icons.edit, color: primaryColor),
              onPressed: () {
                navigateToEditScreen(title, content, onUpdate);
              },
            ),
          ],
        ),
        10.height,
        Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(defaultRadius),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(defaultRadius),
            child: SingleChildScrollView(
              child: fwfh.HtmlWidget(
                content,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return true;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: mainColorLight,
              pinned: true,
              leading: IconButton(
                icon: Icon(CupertinoIcons.back, color: mainColorText),
                onPressed: () => Navigator.pop(context),
              ),
              titleSpacing: 0,
              title: Text(
                language.editProfile,
                style: boldTextStyle(
                  color: mainColorText,
                  size: 18,
                  weight: FontWeight.w500,
                ),
              ),
              expandedHeight: 0,
              elevation: 0,
              surfaceTintColor: mainColorLight,
              forceElevated: true,
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  Stack(
                    children: [
                      Container(
                        height: 40,
                        color: mainColorLight,
                      ),
                    ],
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
                      constraints: BoxConstraints(
                        minHeight: context.height() - 100,
                      ),
                      child: Observer(
                        builder: (context) {
                          return Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  20.height,
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                          decoration:
                                              boxDecorationWithRoundedCorners(
                                                  boxShape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: bgColor,
                                                      width: 1)),
                                          child: profileImage()),
                                      Container(
                                              padding: EdgeInsets.all(7),
                                              decoration:
                                                  boxDecorationWithRoundedCorners(
                                                      borderRadius: radius(50),
                                                      border: Border.all(
                                                          color: primaryColor),
                                                      backgroundColor:
                                                          Colors.white),
                                              child: Image.asset(
                                                  ic_edit_profile,
                                                  height: 16,
                                                  width: 16,
                                                  color: primaryColor))
                                          .onTap(() {
                                        openBottomSheet();
                                      })
                                    ],
                                  ).onTap(() {
                                    openBottomSheet();
                                  }).center(),
                                  20.height,
                                  Text(language.name,
                                      style:
                                          primaryTextStyle(color: grayColor)),
                                  10.height,
                                  AppTextField(
                                      textInputAction: TextInputAction.next,
                                      controller: NameController,
                                      focus: NameFocus,
                                      textFieldType: TextFieldType.OTHER,
                                      keyboardType: TextInputType.text,
                                      decoration: defaultInputDecoration(
                                          context,
                                          label: language.enterYourName),
                                      suffix: Image.asset(ic_user,
                                              height: 16,
                                              width: 16,
                                              color: grayColor)
                                          .paddingSymmetric(vertical: 12)),
                                  10.height,
                                  Text(language.email,
                                      style:
                                          primaryTextStyle(color: grayColor)),
                                  10.height,
                                  AppTextField(
                                      readOnly: true,
                                      textInputAction: TextInputAction.next,
                                      controller: EmailController,
                                      focus: EmailFocus,
                                      textFieldType: TextFieldType.EMAIL,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: defaultInputDecoration(
                                          context,
                                          label: language.enterEmail),
                                      suffix: Image.asset(ic_mail,
                                              height: 16,
                                              width: 16,
                                              color: grayColor)
                                          .paddingSymmetric(vertical: 12)),
                                  10.height,
                                  Text(language.tagLine,
                                      style:
                                          primaryTextStyle(color: grayColor)),
                                  10.height,
                                  AppTextField(
                                      textInputAction: TextInputAction.next,
                                      controller: TagLineController,
                                      focus: TaglineFocus,
                                      textFieldType: TextFieldType.OTHER,
                                      keyboardType: TextInputType.text,
                                      decoration: defaultInputDecoration(
                                          context,
                                          label: language.enterYourTagLine),
                                      suffix: Image.asset(ic_chat,
                                              height: 16,
                                              width: 16,
                                              color: grayColor)
                                          .paddingSymmetric(vertical: 12)),
                                  10.height,
                                  htmlField(
                                      language.shortDescription, shortDescHtml,
                                      (newContent) {
                                    setState(() {
                                      shortDescHtml = newContent;
                                    });
                                  }),
                                  htmlField(language.career, careerHtml,
                                      (newContent) {
                                    setState(() {
                                      careerHtml = newContent;
                                    });
                                  }),
                                  10.height,
                                  htmlField(language.education, educationHtml,
                                      (newContent) {
                                    setState(() {
                                      educationHtml = newContent;
                                    });
                                  }),
                                  10.height,
                                  htmlField(language.awardsAndAchievements,
                                      awardsHtml, (newContent) {
                                    setState(() {
                                      awardsHtml = newContent;
                                    });
                                  }),
                                  10.height,
                                  htmlField(
                                      language.AreasOfExpertise, expertiseHtml,
                                      (newContent) {
                                    setState(() {
                                      expertiseHtml = newContent;
                                    });
                                  }),
                                  40.height,
                                  AppButton(
                                    disabledColor: ColorUtils.colorPrimary,
                                    text: language.save,
                                    color: primaryColor,
                                    textStyle: primaryTextStyle(color: white),
                                    width: context.width(),
                                    onTap: save,
                                  ),
                                  20.height,
                                ],
                              ).paddingAll(16),
                              if (appStore.isLoading) Loader().center()
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  openBottomSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.3,
            builder: (_, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                ),
                child: ListView(
                  controller: controller,
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: Icon(Icons.camera_alt_outlined,
                          color: context.iconColor),
                      title: Text(language.camera, style: primaryTextStyle()),
                      onTap: () {
                        finish(context);
                        getImageFromCamera();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.photo_library_outlined,
                          color: context.iconColor),
                      title: Text(language.gallery, style: primaryTextStyle()),
                      onTap: () {
                        finish(context);
                        getImage();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        });
  }
}
