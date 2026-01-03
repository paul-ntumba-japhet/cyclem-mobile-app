import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/main.dart';
import 'package:era_flutter/screens/user/sign_in_screen.dart';
import 'package:era_flutter/screens/user/sign_up_screen.dart';
import 'package:era_flutter/utils/app_common.dart';
import 'package:era_flutter/utils/app_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../extensions/new_colors.dart';
import '../../model/user/question_model.dart';
import '../../utils/dynamic_theme.dart';
import '../doctor/doctor_login_screen.dart';
import '../../utils/app_images.dart';

class QuestionsListScreen extends StatefulWidget {
  @override
  State<QuestionsListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionsListScreen> {
  int currentStep = 1;

  DateTime? _selectedDay;
  DateTime? _focusedDay;
  // Map<DateTime, List<Event>> events = {};

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    logScreenView("Question List screen");
  }

  String buildTitle() {
    switch (currentStep) {
      case 1:
        return questionsModel.step1.title.toString();
      case 2:
        return questionsModel.step2.title.toString();
      case 3:
        return questionsModel.step3.title.toString();
      case 4:
        return questionsModel.step4.title.toString();
      case 5:
        return questionsModel.step5.title.toString();
      default:
        return questionsModel.step7.title.toString();
    }
  }

  bool validateStep7() {
    if (currentStep == 6) {
      if (questionsModel.step7.answerToQuestion1.isEmptyOrNull) {
        toast("Please enter your name");
        return false;
      }
      if (questionsModel.step7.answerToQuestion2.isEmptyOrNull) {
        toast("Please select your age");
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && currentStep > 1) {
          setState(() => currentStep--);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          physics: NeverScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: mainColorLight,
              pinned: true,
              toolbarHeight: 80,
              automaticallyImplyLeading: false,
              leading: currentStep > 1
                  ? IconButton(
                      icon: Icon(CupertinoIcons.back, color: mainColorText),
                      onPressed: () {
                        if (currentStep == 1) {
                          finish(context);
                        } else {
                          currentStep--;
                          setState(() {});
                        }
                      })
                  : null,
              titleSpacing: currentStep == 1 ? null : 0,
              title: Text(
                buildTitle(),
                maxLines: 4,
                style: boldTextStyle(
                  color: mainColorText,
                  size: 18,
                  weight: FontWeight.w500,
                ),
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: progressIndicator(),
                )
              ],
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
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.top -
                          35,
                      child: Stack(
                        children: [
                          step1().visible(currentStep == 1),
                          step2().visible(currentStep == 2),
                          step3().visible(currentStep == 3),
                          step4().visible(currentStep == 4),
                          step5().visible(currentStep == 5),
                          step7(context, setState).visible(currentStep == 6),
                          Positioned(
                            bottom: 35,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                AppButton(
                                    disabledColor: ColorUtils.colorPrimary,
                                    text: language.continueText,
                                    width: context.width() * 0.88,
                                    onTap: () async {
                                      if (currentStep == 4 &&
                                          userStore.cycleLength == 0) {
                                        userStore.setCycleLength(
                                            DEFAULT_CYCLE_LENGTH);
                                      }
                                      if (currentStep == 5) {
                                        if (userStore.periodsLength == 0) {
                                          userStore.setPeriodsLength(
                                              DEFAULT_PERIOD_LENGTH);
                                        }
                                        setValue(KEY_QUESTION_DATA,
                                            questionsModel.toJson());
                                        currentStep++;
                                        setState(() {});
                                      } else if (currentStep == 6) {
                                        if (validateStep7()) {
                                          setValue(IS_USER_COMPLETED_QUE, true);
                                          SignUpScreen().launch(context);
                                          setValue(KEY_QUESTION_DATA,
                                              questionsModel.toJson());
                                        }
                                      } else {
                                        currentStep++;
                                        setState(() {});
                                      }
                                    }).visible(currentStep >= 2),
                                14.height,
                                skipButton(() {
                                  if (currentStep == 6) {
                                    setValue(IS_USER_COMPLETED_QUE, true);
                                    setValue(KEY_QUESTION_DATA,
                                        questionsModel.toJson());
                                    SignUpScreen().launch(context);
                                  } else {
                                    currentStep++;
                                    setState(() {});
                                  }
                                }).visible(currentStep > 2),
                                14.height,
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 30,
                            left: 0,
                            right: 0,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent,
                              ),
                              onPressed: () {
                                UserSignInScreen().launch(context);
                              },
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: language.alreadyHaveAnAccount,
                                      style: boldTextStyle(
                                        size: 16,
                                        weight: FontWeight.w400,
                                        color: mainColorText,
                                      ),
                                    ),
                                    // TextSpan(
                                    //   text: 'Login now',
                                    //   style: boldTextStyle(
                                    //     size: 16,
                                    //     weight: FontWeight.w400,
                                    //     color: mainColor,
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                            ),
                          ).visible(currentStep <= 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Skip button
  Widget skipButton(Function onTap) {
    return Text(
      language.skip,
      style: secondaryTextStyle(size: textFontSize_16),
    ).onTap(() {
      if (currentStep == 4) {
        questionsModel.step4.selectedOption = DEFAULT_CYCLE_LENGTH;
        userStore.setCycleLength(DEFAULT_CYCLE_LENGTH);
      } else if (currentStep == 5) {
        questionsModel.step5.selectedOption = DEFAULT_PERIOD_LENGTH;
        userStore.setPeriodsLength(DEFAULT_PERIOD_LENGTH);
      }
      setValue(KEY_QUESTION_DATA, questionsModel.toJson());
      onTap();
    });
  }

  Widget step1() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: questionsModel.step1.options.length,
      physics: NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            if (index == 1) {
              DoctorLoginScreen().launch(context);
            } else {
              questionsModel.step1.selectedOption = index;
              currentStep = 2;
              setState(() {});
            }
          },
          child: Container(
            width: context.width(),
            height: 80,
            padding: EdgeInsets.symmetric(vertical: 18),
            margin: EdgeInsets.all(8),
            decoration: boxDecorationWithRoundedCorners(
              borderRadius: BorderRadius.circular(defaultRadius),
              backgroundColor: Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: mainBgLightGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    index == 0 ? ic_anchor : ic_doctor_image,
                    width: 25,
                    height: 25,
                    fit: BoxFit.cover,
                  ),
                ).paddingLeft(8),
                Expanded(
                  child: Text(
                    questionsModel.step1.options[index],
                    style: boldTextStyle(
                        size: 18,
                        weight: FontWeight.w400,
                        color: mainColorText),
                    textAlign: TextAlign.center, // Center text horizontally
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: primaryColor,
                    size: 20,
                  ),
                  onPressed: () {
                    if (index == 1) {
                      DoctorLoginScreen().launch(context);
                    } else {
                      questionsModel.step1.selectedOption = index;
                      currentStep = 2;
                      setState(() {});
                    }
                  },
                ).paddingRight(8),
              ],
            ),
          ),
        );
      },
    ).paddingAll(8);
  }

  Widget step2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        8.height,
        Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            questionsModel.step2.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
          ),
        ),
        10.height,
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: questionsModel.step2.options.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  questionsModel.step2.selectedOption = index;
                });
              },
              child: Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: boxDecorationWithRoundedCorners(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 1,
                    color: questionsModel.step2.selectedOption == index
                        ? mainColor
                        : gray,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(
                          questionsModel.step2.options[index].img.validate(),
                          height: 40,
                          width: 40,
                          fit: BoxFit.contain,
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  questionsModel.step2.selectedOption == index
                                      ? Colors.transparent
                                      : gray,
                            ),
                          ),
                          child: questionsModel.step2.selectedOption == index
                              ? Image.asset(ic_checkmark)
                              : null,
                        ),
                      ],
                    ),
                    8.height,
                    Text(
                      questionsModel.step2.options[index].title.validate(),
                      style: boldTextStyle(
                          size: 18,
                          weight: FontWeight.w400,
                          color: mainColorText),
                    ),
                    4.height,
                    Text(
                      questionsModel.step2.options[index].desc.validate(),
                      style: boldTextStyle(
                          size: 14,
                          weight: FontWeight.w400,
                          color: mainColorBodyText),
                      maxLines: 4,
                    ),
                  ],
                ),
              ).paddingOnly(bottom: 16),
            );
          },
        ),
      ],
    ).paddingAll(10);
  }

  Widget step3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        8.height,
        Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            questionsModel.step3.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
          ),
        ),
        10.height,
        TableCalendar(
          firstDay: DateTime.utc(2020, 10, 16),
          lastDay: DateTime.utc(2030, 3, 14),
          focusedDay: _focusedDay!,
          calendarFormat: CalendarFormat.month,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            questionsModel.step3.selectedLastPeriodDate = _selectedDay != null
                ? DateFormat('yyyy-MM-dd').format(_selectedDay!)
                : "";
          },
          enabledDayPredicate: (day) {
            return day.isBefore(DateTime.now().add(Duration(days: 0)));
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: HeaderStyle(
            titleTextStyle: boldTextStyle(),
            titleCentered: true,
            formatButtonVisible: false,
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            markersAlignment: Alignment.bottomCenter,
            todayDecoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ).paddingSymmetric(horizontal: 16);
  }

  Widget step4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            questionsModel.step3.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
            textAlign: TextAlign.start,
          ),
        ),
        SizedBox(
          height: context.height() * 0.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CupertinoPicker(
                squeeze: 0.8,
                selectionOverlay: SizedBox(),
                itemExtent: 34.0,
                onSelectedItemChanged: (int selectedItem) {
                  setState(() {
                    String selectedValue = questionsModel
                        .step4.cycleLengthList![selectedItem]
                        .toString();
                    if (selectedValue != "Select") {
                      questionsModel.step4.selectedOption =
                          int.parse(selectedValue);
                      userStore.setCycleLength(int.parse(selectedValue));
                    } else {
                      questionsModel.step4.selectedOption =
                          DEFAULT_CYCLE_LENGTH;
                      userStore.setCycleLength(DEFAULT_CYCLE_LENGTH);
                    }
                    setValue(KEY_QUESTION_DATA, questionsModel.toJson());
                  });
                },
                children: getCycleLengthList().map((Object item) {
                  return Center(
                    child: Text(
                      item.toString(),
                      style: boldTextStyle(
                          size: textFontSize_28, weight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 25),
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 18),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget step5() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            questionsModel.step5.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
            textAlign: TextAlign.start,
          ),
        ),
        SizedBox(
          height: context.height() * 0.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CupertinoPicker(
                squeeze: 0.8,
                selectionOverlay: SizedBox(),
                itemExtent: 34.0,
                onSelectedItemChanged: (int selectedItem) {
                  setState(() {
                    String selectedValue = questionsModel
                        .step5.periodLengthList![selectedItem]
                        .toString();
                    if (selectedValue != "Select") {
                      questionsModel.step5.selectedOption =
                          int.parse(selectedValue);
                      userStore.setPeriodsLength(int.parse(selectedValue));
                    } else {
                      questionsModel.step5.selectedOption =
                          DEFAULT_PERIOD_LENGTH;
                      userStore.setPeriodsLength(DEFAULT_PERIOD_LENGTH);
                    }
                    setValue(KEY_QUESTION_DATA, questionsModel.toJson());
                  });
                },
                children: getPeriodLengthList().map((Object item) {
                  return Center(
                    child: Text(
                      item.toString(),
                      style: boldTextStyle(size: textFontSize_28),
                    ),
                  );
                }).toList(),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 25),
                  Container(height: 2, width: 100, color: primaryColor)
                      .paddingSymmetric(vertical: 18),
                ],
              ),
            ],
          ),
        ),
        16.height,
      ],
    );
  }

  Widget step7(BuildContext context, StateSetter setState) {
    final ageOptions = generateBirthYearOptions();

    if (questionsModel.step7.answerToQuestion2.isEmptyOrNull) {
      questionsModel.step7.answerToQuestion2 = ageOptions.first;
      setValue(KEY_QUESTION_DATA, questionsModel.toJson());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionsModel.step7.desc.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 16),
            textAlign: TextAlign.start,
          ),
          24.height,
          Text(
            questionsModel.step7.question1.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 14),
          ),
          8.height,
          TextField(
            controller: TextEditingController(
              text: questionsModel.step7.answerToQuestion1,
            ),
            onChanged: (value) {
              questionsModel.step7.answerToQuestion1 = value;
              setValue(KEY_QUESTION_DATA, questionsModel.toJson());
            },
            decoration: InputDecoration(
              hintText: "Enter your name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          24.height,
          Text(
            questionsModel.step7.question2.toString(),
            style: boldTextStyle(
                color: mainColorText, weight: FontWeight.w400, size: 14),
          ),
          8.height,
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: CupertinoPicker(
              itemExtent: 40.0,
              onSelectedItemChanged: (int selectedIndex) {
                setState(() {
                  questionsModel.step7.answerToQuestion2 =
                      ageOptions[selectedIndex];
                  setValue(KEY_QUESTION_DATA, questionsModel.toJson());
                });
              },
              children: ageOptions.map((age) {
                return Center(
                  child: Text(
                    age,
                    style: boldTextStyle(
                        color: mainColorText,
                        weight: FontWeight.w500,
                        size: 22),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget progressIndicator() {
    return CircularPercentIndicator(
      radius: 28.0,
      lineWidth: 6.0,
      percent: (currentStep / 6) > 1 ? 1 : currentStep / 6,
      animation: true,
      center: Text(
        "${currentStep.toInt()} /6",
        style: boldTextStyle(size: textFontSize_14),
      ),
      backgroundColor: Colors.white,
      progressColor: primaryColor,
    );
  }
}
