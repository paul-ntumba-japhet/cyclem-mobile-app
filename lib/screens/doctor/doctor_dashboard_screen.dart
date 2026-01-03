import 'dart:io';

import 'package:era_flutter/main.dart';
import 'package:era_flutter/screens/doctor/doctor_blog_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extensions.dart';
import '../../utils/dynamic_theme.dart';
import 'doctor_home_screen.dart';
import 'doctor_profile_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  static String tag = '/DoctorDashboardScreen';
  final int initialIndex;

  DoctorDashboardScreen({super.key, this.initialIndex = 0});

  @override
  DoctorDashboardScreenState createState() => DoctorDashboardScreenState();
}

class DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  late int currentIndex;

  final tab = [
    DoctorHomeScreen(),
    DoctorBlogScreen(isFromTabs: true),
    DoctorProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  Future<bool> onWillPop() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(language.confirmExit),
              content: Text(language.AreYouSureYouWantToExit),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(language.cancel),
                ),
                TextButton(
                  onPressed: () {
                    pop();
                    exit(0);
                  },
                  child: Text(language.exit),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        body: tab[currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          showSelectedLabels: true,
          enableFeedback: false,
          selectedLabelStyle: secondaryTextStyle(size: textFontSize_12),
          unselectedLabelStyle: secondaryTextStyle(size: textFontSize_12),
          backgroundColor: context.cardColor,
          unselectedItemColor: Colors.grey,
          currentIndex: currentIndex,
          selectedItemColor: ColorUtils.colorPrimary,
          onTap: (index) {
            if (mounted) {
              setState(() {
                currentIndex = index;
              });
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.calendar_today, size: 20),
              activeIcon: Icon(
                CupertinoIcons.calendar_today,
                size: 20,
                color: ColorUtils.colorPrimary,
              ),
              label: language.dashboard,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb_outline, size: 20),
              activeIcon: Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: ColorUtils.colorPrimary,
              ),
              label: language.blog,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle, size: 20),
              activeIcon: Icon(
                Icons.account_circle,
                size: 20,
                color: ColorUtils.colorPrimary,
              ),
              label: language.profile,
            ),
          ],
        ),
      ),
    );
  }
}
