import 'package:era_flutter/extensions/constants.dart';
import 'package:era_flutter/extensions/extension_util/int_extensions.dart';
import 'package:era_flutter/extensions/extension_util/widget_extensions.dart';
import 'package:flutter/material.dart';

import '../../extensions/text_styles.dart';
import '../../utils/app_images.dart';

class CommonActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color textColor;
  final double width;
  final bool isVisible;
  final VoidCallback onTap;

  const CommonActionButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
    this.backgroundColor = const Color(0xFF6200EE),
    this.textColor = Colors.white,
    this.width = 120,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 10, right: 20, bottom: 10, left: 20),
      width: width,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            child: Image.asset(
              ic_add_icon,
              width: 24,
              height: 24,
            ),
          ),
          10.width,
          Text(
            text,
            style: boldTextStyle(
              color: textColor,
              isHeader: true,
              size: textFontSize_16,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).center().onTap(onTap).visible(isVisible);
  }
}
