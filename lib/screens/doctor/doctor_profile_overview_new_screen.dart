import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/int_extensions.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/extensions/extension_util/widget_extensions.dart';
import 'package:era_flutter/utils/app_images.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../../extensions/colors.dart';
import '../../extensions/common.dart';
import '../../extensions/constants.dart';
import '../../extensions/new_colors.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../model/doctor/doctor_models/health_expert_model.dart';
import '../../utils/app_common.dart';
import '../../utils/dynamic_theme.dart';

class DoctorProfileOverviewNewScreen extends StatefulWidget {
  const DoctorProfileOverviewNewScreen({super.key, required this.doctorData});
  final HealthExpertData doctorData;

  @override
  State<DoctorProfileOverviewNewScreen> createState() =>
      _DoctorProfileOverviewNewScreenState();
}

class _DoctorProfileOverviewNewScreenState
    extends State<DoctorProfileOverviewNewScreen> {
  List<String> goalList = [
    language.details,
    // language.reviews,
  ];
  int currentGoalIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  Widget _buildStarRating(double rating) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    double decimalPart = rating - fullStars;
    int emptyStars = 5 - fullStars - (decimalPart >= 0.5 ? 1 : 0);

    for (int i = 0; i < fullStars; i++) {
      stars.add(Icon(Icons.star, color: Colors.amber, size: 16));
      stars.add(SizedBox(width: 2));
    }

    if (decimalPart >= 0.5) {
      stars.add(Icon(Icons.star_half, color: Colors.amber, size: 16));
      stars.add(SizedBox(width: 2));
    }

    for (int i = 0; i < emptyStars; i++) {
      stars.add(Icon(Icons.star_border, color: Colors.amber, size: 16));
      stars.add(SizedBox(width: 2));
    }

    return Row(children: stars);
  }

  Widget _buildDetailsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.zero,
          child: HtmlWidget(
            widget.doctorData.shortDescritpion ?? "",
            // size: 16,
          ),
        ),
        20.height,
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Contact",
                style: boldTextStyle(
                  size: textFontSize_16,
                  weight: FontWeight.w500,
                  color: mainColorText,
                ),
              ),
              10.height,
              Divider(height: 1, color: mainColorStroke),
              10.height,
              Row(
                children: [
                  Image.asset(ic_phone, width: 18, height: 18),
                  SizedBox(width: 4),
                  Text(
                    "+1 (123) 456-7890",
                    style: boldTextStyle(
                      size: textFontSize_14,
                      weight: FontWeight.w400,
                      color: mainColorBodyText,
                    ),
                  ),
                ],
              ),
              8.height,
              Row(
                children: [
                  Image.asset(ic_letter, width: 18, height: 18),
                  SizedBox(width: 4),
                  Text(
                    widget.doctorData.email ?? "No email provided",
                    style: boldTextStyle(
                      size: textFontSize_14,
                      weight: FontWeight.w400,
                      color: mainColorBodyText,
                    ),
                  ),
                ],
              ),
            ],
          ).paddingSymmetric(horizontal: 16, vertical: 10),
        ),
        20.height,
        // Container(
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(12),
        //   ),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Text(
        //         language.Availability,
        //         style: boldTextStyle(
        //           size: textFontSize_16,
        //           weight: FontWeight.w500,
        //           color: mainColorText,
        //         ),
        //       ),
        //       10.height,
        //       Divider(height: 1, color: mainColorStroke),
        //       10.height,
        //     ],
        //   ).paddingSymmetric(horizontal: 16, vertical: 10),
        // ),
        // 20.height,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              language.career,
              style:
                  boldTextStyle(size: textFontSize_16, weight: FontWeight.w500),
            ),
            10.height,
            Divider(height: 1, color: Colors.grey[200]),
            10.height,
            Container(
              padding: EdgeInsets.zero,
              child: HtmlWidget(
                widget.doctorData.career ?? "",
              ),
            ),
          ],
        ).visible(widget.doctorData.career != null &&
            widget.doctorData.career!.isNotEmpty)
      ],
    );
  }

  // Widget for Reviews tab content
  Widget _buildReviewsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              language.AllReviews,
              style: boldTextStyle(
                  size: textFontSize_14,
                  weight: FontWeight.w500,
                  color: mainColorText),
            ),
            4.width,
          ],
        ),
        10.height,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: kPrimaryColor,
            body: SafeArea(
              child: Column(
                children: [
                  // Fixed Header
                  Container(
                    padding: EdgeInsets.only(
                      bottom: 20,
                    ),
                    color: kPrimaryColor,
                    child: Column(
                      children: [
                        10.height,
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                pop();
                              },
                              icon: Icon(CupertinoIcons.back,
                                  color: mainColorText),
                            ),
                            Text(
                              language.doctorProfile,
                              style: boldTextStyle(
                                color: mainColorText,
                                size: textFontSize_18,
                                weight: FontWeight.w500,
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
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            20.height,
                            _buildProfileHeader(),
                            20.height,
                            Divider(height: 1, color: Colors.grey[200]),
                            20.height,
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: EdgeInsets.all(4),
                              child: Row(
                                children: List.generate(goalList.length, (i) {
                                  final isSelected = currentGoalIndex == i;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          currentGoalIndex = i;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
                                        margin:
                                            EdgeInsets.symmetric(horizontal: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? ColorUtils.colorPrimary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                        padding:
                                            EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          goalList[i].validate(),
                                          textAlign: TextAlign.center,
                                          style: boldTextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black,
                                            size: textFontSize_14,
                                            weight: FontWeight.normal,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            20.height,
                            currentGoalIndex == 0
                                ? _buildDetailsContent()
                                : _buildReviewsContent(),
                            20.height, // Bottom spacing
                          ],
                        ).paddingSymmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: cachedImage(
              widget.doctorData.healthExpertsImage,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.doctorData.name ?? "Unknown Doctor",
              style: boldTextStyle(
                  color: black, size: textFontSize_18, weight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            4.height,
            Text(
              widget.doctorData.tagLine ?? "Tagline",
              style: secondaryTextStyle(
                  size: textFontSize_12, weight: FontWeight.w400),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            4.height,
            widget.doctorData.ratingAverage != null &&
                    widget.doctorData.ratingAverage! > 0 &&
                    widget.doctorData.ratingTotalCount != null &&
                    widget.doctorData.ratingTotalCount! > 0
                ? Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      8.width,
                      Text(
                        widget.doctorData.ratingAverage!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      8.width,
                      Text(
                        "(${widget.doctorData.ratingTotalCount} ${language.reviews})",
                        style: primaryTextStyle(
                            color: mainColorBodyText, size: textFontSize_14),
                      ),
                    ],
                  )
                : Text(
                    language.NoRatings,
                    style: primaryTextStyle(
                        color: mainColorBodyText, size: textFontSize_14),
                  ),
          ],
        ).paddingAll(10).expand(),
      ],
    );
  }
}
