import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dotted_border/dotted_border.dart';
import 'package:era_flutter/components/common/required_validation.dart';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/main.dart';
import 'package:era_flutter/model/model.dart';
import 'package:era_flutter/utils/app_common.dart';
import 'package:era_flutter/utils/app_images.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:mm_core/utils/mm_network_utils.dart';
import '../../components/common/html_field_commponent.dart';
import '../../extensions/new_colors.dart';
import '../../network/network_utils.dart';
import '../../utils/dynamic_theme.dart';

class EditBlogScreen extends StatefulWidget {
  final Article? article;

  const EditBlogScreen({super.key, this.article});

  @override
  State<EditBlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<EditBlogScreen> {
  TextEditingController _nameController = TextEditingController();
  TextEditingController _referenceController = TextEditingController();
  String BlogDescriptionHtml = '';
  String? initialHtmlContent;
  List<String> _tags = [
    'Pregnancy Sex',
    'Ovulation',
    'Vaginal discharge',
    'Menstrual Cycle',
    'First Trimester',
    'Pregnancy week'
  ];
  List<String> _reference = [];
  Map<String, int> _tagsIndices = {
    'Pregnancy Sex': 1,
    'Ovulation': 2,
    'Vaginal discharge': 3,
    'Menstrual Cycle': 4,
    'First Trimester': 5,
    'Pregnancy week': 6,
  };
  List<String> _selectedChips = [];
  List<String> _selectedChipsValue = [];
  String? _selectedGoalType = "Track Cycle";
  Map<String, int> goalTypeIndices = {
    "Track Cycle": 0,
    // "Get Pregnancy": 1,
    "Track Pregnancy": 1
  };

  XFile? imageMain;
  String? blogImagePath;
  Uint8List? blogImage;
  String? imageName;

  @override
  void initState() {
    super.initState();
    if (widget.article != null) {
      _nameController.text = widget.article!.name ?? '';
      BlogDescriptionHtml = widget.article!.description ?? '';
      _selectedChips = widget.article!.tags!
          .map((e) => e.name ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      _selectedGoalType = goalTypeIndices.entries
          .firstWhere((element) => element.value == widget.article!.goalType,
              orElse: () => MapEntry("Track Cycle", 0))
          .key;
      _reference = widget.article!.articleReference!
          .map((ref) => ref.referenceName ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      blogImagePath = widget.article!.articleImage;
    }
  }

  Future getImage() async {
    imageMain = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 100);
    blogImagePath = imageMain!.path;
    blogImage = await imageMain!.readAsBytes();
    imageName = imageMain!.name;

    setState(() {});
  }

  Future save() async {
    hideKeyboard(context);
    appStore.setLoading(true);
    if (_reference.isEmpty) {
      _reference.add('Default Reference');
    }
    String referencesJson = jsonEncode(_reference);
    MultipartRequest multipartRequest = await getMultiPartRequest(
        widget.article == null
            ? 'article-create'
            : 'article-update/${widget.article!.id}');

    if (widget.article != null) {
      multipartRequest.fields['id'] = widget.article!.id.toString();
    }

    multipartRequest.fields['name'] = _nameController.text;
    multipartRequest.fields['description'] = BlogDescriptionHtml.toString();
    multipartRequest.fields['reference'] = referencesJson;
    multipartRequest.fields['tags_id'] = _selectedChipsValue.toString();
    if (_selectedGoalType != null) {
      multipartRequest.fields['goal_type'] =
          goalTypeIndices[_selectedGoalType].toString();
    }
    multipartRequest.fields['status'] = "1";
    if (imageMain != null) {
      multipartRequest.files.add(await MultipartFile.fromPath(
          'article_image', imageMain!.path.toString()));
    }

    multipartRequest.headers.addAll(buildHeaderTokens());

    try {
      final response = await sendMultiPartRequest(multipartRequest);
      Navigator.pop(context, true);
    } catch (e) {
      toast(e.toString());
    } finally {
      appStore.setLoading(false);
    }
  }

  void _addReference() {
    if (_referenceController.text.isNotEmpty) {
      setState(() {
        _reference.add(_referenceController.text);
        _referenceController.clear();
      });
    }
  }

  bool validateInputs() {
    if (_nameController.text.isEmpty) {
      toast(language.NameIsRequired);
      return false;
    }
    if (_selectedChips.isEmpty) {
      toast(language.AtLeastOneTagIsRequired);
      return false;
    }
    if (_selectedGoalType == null) {
      toast(language.GoalTypeIsRequired);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              widget.article == null ? language.createBlog : language.blogEdit,
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
              delegate: SliverChildListDelegate([
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Blog Name

                    10.height,
                    RequiredValidationText(
                      required: true,
                      titleText: language.blogName,
                    ),
                    10.height,
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: Colors.white,
                        borderRadius: radius(8),
                      ),
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: language.addNameYourBlog,
                          hintStyle: primaryTextStyle(
                              size: textFontSize_16,
                              color: mainColorBodyText,
                              weight: FontWeight.w400),
                          border: InputBorder.none,
                        ),
                        style: boldTextStyle(size: textFontSize_14),
                      ),
                    ),

                    ///Blog tags
                    20.height,
                    RequiredValidationText(
                      required: true,
                      titleText: language.blogTags,
                    ),
                    10.height,
                    Wrap(
                      spacing: 10.0,
                      children: List<Widget>.generate(
                        _tags.length,
                        (int index) {
                          return ChoiceChip(
                            label: Text(
                              _tags[index],
                              style: primaryTextStyle(
                                  color: _selectedChips.contains(_tags[index])
                                      ? Colors.white
                                      : Colors.black,
                                  size: textFontSize_14),
                            ),
                            selected: _selectedChips.contains(_tags[index]),
                            backgroundColor: bgColor,
                            selectedColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: radius(8),
                              side: BorderSide(
                                color: _selectedChips.contains(_tags[index])
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                            ),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _selectedChips.add(_tags[index]);
                                  _selectedChipsValue.add(
                                      _tagsIndices[_tags[index]]!.toString());
                                } else {
                                  _selectedChips.remove(_tags[index]);
                                  _selectedChipsValue.remove(
                                      _tagsIndices[_tags[index]]!.toString());
                                }
                              });
                            },
                          );
                        },
                      ).toList(),
                    ),

                    /// Goal types

                    20.height,
                    RequiredValidationText(
                      required: true,
                      titleText: language.goalType,
                    ),
                    10.height,
                    Container(
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: Colors.white,
                        borderRadius: radius(8),
                      ),
                      child: DropdownButtonFormField<String>(
                        iconDisabledColor: primaryColor,
                        iconEnabledColor: primaryColor,
                        items: goalTypeIndices.keys
                            .map(
                              (value) => DropdownMenuItem<String>(
                                child: Text(
                                  value,
                                  style: boldTextStyle(
                                    size: textFontSize_16,
                                    weight: FontWeight.w500,
                                    color: mainColorText,
                                  ),
                                ),
                                value: value,
                              ),
                            )
                            .toList(),
                        isExpanded: false,
                        isDense: true,
                        borderRadius: radius(8),
                        decoration: InputDecoration(
                          border: InputBorder.none, // Remove the border
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onChanged: (String? value) {
                          setState(() {
                            _selectedGoalType = value;
                          });
                        },
                        value: _selectedGoalType ?? goalTypeIndices.keys.first,
                      ),
                    ),

                    /// Blog image
                    20.height,
                    RequiredValidationText(
                      required: false,
                      titleText: language.blogImage,
                    ),
                    10.height,
                    if (blogImagePath != null)
                      Stack(
                        children: [
                          blogImagePath!.contains('https')
                              ? cachedImage(
                                      height: context.height() * 0.25,
                                      width: context.width(),
                                      blogImagePath.validate())
                                  .cornerRadiusWithClipRRect(10)
                              : Image.file(
                                  File(blogImagePath.validate()),
                                  height: context.height() * 0.25,
                                  width: context.width(),
                                  fit: BoxFit.cover,
                                ).cornerRadiusWithClipRRect(8).center(),
                          Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: boxDecorationWithRoundedCorners(
                                      boxShape: BoxShape.circle),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 12,
                                  ).onTap(() {
                                    blogImagePath = null;
                                    setState(() {});
                                  }))),
                        ],
                      ),
                    if (blogImagePath.isEmptyOrNull) 10.height,
                    if (blogImagePath.isEmptyOrNull)
                      GestureDetector(
                        onTap: () {
                          getImage();
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: DottedBorder(
                            color: Colors.grey,
                            dashPattern: [6, 3],
                            child: Container(
                              height: 50,
                              decoration: boxDecorationWithRoundedCorners(
                                  borderRadius: BorderRadius.circular(8),
                                  backgroundColor: Colors.white),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(ic_camera,
                                      height: 24,
                                      width: 24,
                                      color: mainColorBodyText),
                                  10.width,
                                  Text(language.addImage,
                                      style: boldTextStyle(
                                          size: textFontSize_16,
                                          weight: FontWeight.w500,
                                          color: mainColorBodyText)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    20.height,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RequiredValidationText(
                          required: false,
                          titleText: language.references,
                        ),
                        Icon(
                          Icons.add,
                          color: primaryColor,
                        ).onTap(() {
                          _addReference();
                        })
                      ],
                    ),
                    10.height,
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: Colors.white,
                        borderRadius: radius(8),
                      ),
                      child: TextField(
                        controller: _referenceController,
                        decoration: InputDecoration(
                          hintText: language.addReferences,
                          hintStyle: boldTextStyle(
                              size: textFontSize_16,
                              weight: FontWeight.w500,
                              color: mainColorBodyText),
                          border: InputBorder.none,
                        ),
                        style: boldTextStyle(size: textFontSize_14),
                      ),
                    ),
                    Wrap(
                      spacing: 8.0,
                      children: List<Widget>.generate(
                        _reference.length,
                        (int index) {
                          return Chip(
                            label: Text(
                              _reference[index],
                              style: primaryTextStyle(size: textFontSize_14),
                            ),
                            deleteIcon: Icon(Icons.close),
                            onDeleted: () {
                              setState(() {
                                _reference.removeAt(index);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    10.height,
                    HtmlFieldWidget(
                      title: language.blogDescription,
                      content: BlogDescriptionHtml,
                      onUpdate: (newContent) {
                        setState(() {
                          BlogDescriptionHtml = newContent;
                        });
                      },
                      context: context,
                    ),
                    40.height,
                    AppButton(
                      disabledColor: ColorUtils.colorPrimary,
                      text: language.save,
                      color: primaryColor,
                      textStyle: primaryTextStyle(color: white),
                      width: context.width(),
                      onTap: () {
                        if (validateInputs()) {
                          save();
                        }
                      },
                    ),
                  ],
                ).paddingSymmetric(horizontal: 16),
              ),
            )
          ]))
        ],
      ),
    );
    //   Scaffold(
    //   appBar: appBarWidget(widget.article == null ? language.createBlog : language.blogEdit,
    //       context1: context,
    //       showBack: true,
    //       elevation: 1,
    //       titleTextStyle: boldTextStyle(
    //           size: textFontSize_18, isHeader: true, color: Colors.white),
    //       color: primaryColor,
    //       textColor: Colors.white),
    //   body: SingleChildScrollView(
    //     child:
    //     Column(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         /// Blog Name
    //
    //         10.height,
    //         RequiredValidationText(
    //           required: true,
    //           titleText: language.blogName,
    //         ),
    //         4.height,
    //         Container(
    //           padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    //           decoration: boxDecorationWithRoundedCorners(
    //             backgroundColor: fifthColor,
    //             borderRadius: radius(defaultRadius),
    //           ),
    //           child: TextField(
    //             controller: _nameController,
    //             decoration: InputDecoration(
    //               hintText: language.addNameYourBlog,
    //               hintStyle: primaryTextStyle(size: textFontSize_16),
    //               border: InputBorder.none,
    //             ),
    //             style: boldTextStyle(size: textFontSize_14),
    //           ),
    //         ),
    //
    //         ///Blog tags
    //         18.height,
    //         RequiredValidationText(
    //           required: true,
    //           titleText: language.blogTags,
    //         ),
    //         4.height,
    //         Wrap(
    //           spacing: 10.0,
    //           children: List<Widget>.generate(
    //             _tags.length,
    //             (int index) {
    //               return ChoiceChip(
    //                 label: Text(
    //                   _tags[index],
    //                   style: primaryTextStyle(
    //                       color: _selectedChips.contains(_tags[index])
    //                           ? Colors.white
    //                           : Colors.black,
    //                       size: textFontSize_14),
    //                 ),
    //                 selected: _selectedChips.contains(_tags[index]),
    //                 backgroundColor: Colors.white,
    //                 selectedColor: primaryColor,
    //                 shape: RoundedRectangleBorder(
    //                   borderRadius: radius(defaultRadius),
    //                   side: BorderSide(
    //                     color: _selectedChips.contains(_tags[index])
    //                         ? primaryColor
    //                         : Colors.grey,
    //                   ),
    //                 ),
    //                 onSelected: (bool selected) {
    //                   setState(() {
    //                     if (selected) {
    //                       _selectedChips.add(_tags[index]);
    //                       _selectedChipsValue
    //                           .add(_tagsIndices[_tags[index]]!.toString());
    //                     } else {
    //                       _selectedChips.remove(_tags[index]);
    //                       _selectedChipsValue
    //                           .remove(_tagsIndices[_tags[index]]!.toString());
    //                     }
    //                   });
    //                 },
    //               );
    //             },
    //           ).toList(),
    //         ),
    //
    //         /// Goal types
    //
    //         18.height,
    //         RequiredValidationText(
    //           required: true,
    //           titleText: language.goalType,
    //         ),
    //         4.height,
    //         Container(
    //           decoration: boxDecorationWithRoundedCorners(
    //               backgroundColor: fifthColor,
    //               borderRadius: radius(defaultRadius)),
    //           child: DropdownButtonFormField<String>(
    //             items: goalTypeIndices.keys
    //                 .map(
    //                   (value) => DropdownMenuItem<String>(
    //                     child: Text(value, style: primaryTextStyle()),
    //                     value: value,
    //                   ),
    //                 )
    //                 .toList(),
    //             isExpanded: false,
    //             isDense: true,
    //             borderRadius: radius(),
    //             decoration: defaultInputDecoration(context),
    //             onChanged: (String? value) {
    //               setState(() {
    //                 _selectedGoalType = value;
    //               });
    //             },
    //             value: _selectedGoalType ?? goalTypeIndices.keys.first,
    //           ),
    //         ),
    //
    //         /// Blog image
    //         18.height,
    //         RequiredValidationText(
    //           required: false,
    //           titleText: language.blogImage,
    //         ),
    //         4.height,
    //         if (blogImagePath != null)
    //           Stack(
    //             children: [
    //               blogImagePath!.contains('https')
    //                   ? cachedImage(
    //                           height: context.height() * 0.25,
    //                           width: context.width(),
    //                           blogImagePath.validate())
    //                       .cornerRadiusWithClipRRect(10)
    //                   : Image.file(
    //                       File(blogImagePath.validate()),
    //                       height: context.height() * 0.25,
    //                       width: context.width(),
    //                       fit: BoxFit.cover,
    //                     ).cornerRadiusWithClipRRect(8).center(),
    //               Positioned(
    //                   top: 2,
    //                   right: 2,
    //                   child: Container(
    //                       padding: EdgeInsets.all(4),
    //                       decoration: boxDecorationWithRoundedCorners(
    //                           boxShape: BoxShape.circle),
    //                       child: Icon(
    //                         Icons.close,
    //                         color: Colors.red,
    //                         size: 12,
    //                       ).onTap(() {
    //                         blogImagePath = null;
    //                         setState(() {});
    //                       }))),
    //             ],
    //           ),
    //         if (blogImagePath.isEmptyOrNull) 10.height,
    //         if (blogImagePath.isEmptyOrNull)
    //           GestureDetector(
    //             onTap: () {
    //               getImage();
    //             },
    //             child: ClipRRect(
    //               borderRadius: BorderRadius.circular(8),
    //               child: DottedBorder(
    //                 color: Colors.grey,
    //                 dashPattern: [6, 3],
    //                 child: Container(
    //                   height: 50,
    //                   decoration: boxDecorationWithRoundedCorners(
    //                       borderRadius: BorderRadius.circular(8),
    //                       backgroundColor: fifthColor),
    //                   child: Row(
    //                     mainAxisAlignment: MainAxisAlignment.center,
    //                     children: [
    //                       Image.asset(ic_camera,
    //                           height: 24, width: 24, color: grayColor),
    //                       10.width,
    //                       Text(language.addImage, style: secondaryTextStyle()),
    //                     ],
    //                   ),
    //                 ),
    //               ),
    //             ),
    //           ),
    //         18.height,
    //         Row(
    //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //           children: [
    //             RequiredValidationText(
    //               required: false,
    //               titleText: language.references,
    //             ),
    //             Icon(
    //               Icons.add,
    //               color: primaryColor,
    //             ).onTap(() {
    //               _addReference();
    //             })
    //           ],
    //         ),
    //         4.height,
    //         Container(
    //           padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    //           decoration: boxDecorationWithRoundedCorners(
    //             backgroundColor: fifthColor,
    //             borderRadius: radius(defaultRadius),
    //           ),
    //           child: TextField(
    //             controller: _referenceController,
    //             decoration: InputDecoration(
    //               hintText: language.addReferences,
    //               hintStyle: primaryTextStyle(size: textFontSize_16),
    //               border: InputBorder.none,
    //             ),
    //             style: boldTextStyle(size: textFontSize_14),
    //           ),
    //         ),
    //         Wrap(
    //           spacing: 8.0,
    //           children: List<Widget>.generate(
    //             _reference.length,
    //             (int index) {
    //               return Chip(
    //                 label: Text(
    //                   _reference[index],
    //                   style: primaryTextStyle(size: textFontSize_14),
    //                 ),
    //                 deleteIcon: Icon(Icons.close),
    //                 onDeleted: () {
    //                   setState(() {
    //                     _reference.removeAt(index);
    //                   });
    //                 },
    //               );
    //             },
    //           ),
    //         ),
    //         HtmlFieldWidget(
    //           title: language.blogDescription,
    //           content: BlogDescriptionHtml,
    //           onUpdate: (newContent) {
    //             setState(() {
    //               BlogDescriptionHtml = newContent;
    //             });
    //           },
    //           context: context,
    //         ),
    //         40.height,
    //         AppButton(
    //           disabledColor: ColorUtils.colorPrimary,
    //           text: language.save,
    //           color: primaryColor,
    //           textStyle: primaryTextStyle(color: white),
    //           width: context.width(),
    //           onTap: () {
    //             if (validateInputs()) {
    //               save();
    //             }
    //           },
    //         ),
    //       ],
    //     ).paddingSymmetric(horizontal: 16),
    //   ),
    // );
  }
}
