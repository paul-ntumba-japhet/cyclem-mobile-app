import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../extensions/extensions.dart';
import '../../../extensions/new_colors.dart';
import '../../../main.dart';
import '../../../model/user/question_model.dart';
import '../../../network/rest_api.dart';

class PersonalInfoWidget extends StatefulWidget {
  final Function()? onCompleted;

  const PersonalInfoWidget({Key? key, this.onCompleted}) : super(key: key);

  @override
  State<PersonalInfoWidget> createState() => _PersonalInfoWidgetState();
}

class _PersonalInfoWidgetState extends State<PersonalInfoWidget> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize with saved data if exists
    if (questionsModel.step3PersonalInfo.fullName != null) {
      _fullNameController.text = questionsModel.step3PersonalInfo.fullName!;
    }
    if (questionsModel.step3PersonalInfo.email != null) {
      _emailController.text = questionsModel.step3PersonalInfo.email!;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    language.pleaseProvideFullNameAndEmailToCompleteProfile,
                    style: boldTextStyle(
                      color: mainColorText,
                      weight: FontWeight.w400,
                      size: 16,
                    ),
                  ),
                ),
                24.height,

                // Full Name Field
                Text(
                  language.fullName,
                  style: boldTextStyle(
                    color: mainColorText,
                    weight: FontWeight.w500,
                    size: 14,
                  ),
                ),
            8.height,
            AppTextField(
              controller: _fullNameController,
              textFieldType: TextFieldType.NAME,
              focus: _nameFocusNode,
              nextFocus: _emailFocusNode,
              decoration: InputDecoration(
                hintText: language.enterYourFullName,
                labelText: language.fullName,
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
              errorThisFieldRequired: language.pleaseEnterFullName,
              onChanged: (value) {
                // Auto-save on change
                questionsModel.step3PersonalInfo.fullName = value.trim();
                questionsModel.step3PersonalInfo.isCompleted = false; // Reset until validated
                // Save to phone-specific key only
                String? phoneNumber = questionsModel.step2Phone.phoneNumber;
                if (phoneNumber != null && phoneNumber.isNotEmpty) {
                  String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
                  if (phoneForAPI.isNotEmpty) {
                    saveQuestionDataForPhone(phoneForAPI, questionsModel);
                  }
                }
              },
            ),
            24.height,

            // Email Field
            Text(
              language.emailAddress,
              style: boldTextStyle(
                color: mainColorText,
                weight: FontWeight.w500,
                size: 14,
              ),
            ),
            8.height,
            AppTextField(
              controller: _emailController,
              textFieldType: TextFieldType.EMAIL,
              focus: _emailFocusNode,
              decoration: InputDecoration(
                hintText: language.enterYourEmailAddress,
                labelText: language.email,
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
              errorThisFieldRequired: language.pleaseEnterYourEmailAddress,
              errorInvalidEmail: language.pleaseEnterValidEmailAddress,
              onChanged: (value) {
                // Auto-save on change
                questionsModel.step3PersonalInfo.email = value.trim();
                questionsModel.step3PersonalInfo.isCompleted = false; // Reset until validated
                // Save to phone-specific key only
                String? phoneNumber = questionsModel.step2Phone.phoneNumber;
                if (phoneNumber != null && phoneNumber.isNotEmpty) {
                  String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
                  if (phoneForAPI.isNotEmpty) {
                    saveQuestionDataForPhone(phoneForAPI, questionsModel);
                  }
                }
              },
            ),
              ],
            ),
          ),
        );
      },
    );
  }

}

