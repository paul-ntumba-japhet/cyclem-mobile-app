import 'package:cached_network_image/cached_network_image.dart';
import 'package:crisp_chat/crisp_chat.dart';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/screens/common/ask_question_widget.dart';
import 'package:era_flutter/screens/doctor/pending_questions_screen.dart';
import 'package:era_flutter/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import '../../extensions/animated_list/animated_list_view.dart';
import '../../main.dart';
import '../../model/doctor/doctor_models/doctor_dashboard_model.dart';
import '../../network/rest_api.dart';
import '../../utils/dynamic_theme.dart';
import '../common/expandable_text.dart';

class DoctorHomeScreen extends StatefulWidget {
  static String tag = '/DoctorHomeScreen';

  @override
  DoctorHomeScreenState createState() => DoctorHomeScreenState();
}

class DoctorHomeScreenState extends State<DoctorHomeScreen> {
  DoctorDashboardResponseData? mDoctorDashboardData;
  late List<Map<String, dynamic>> gridData = [];
  Map<int, bool> showTextFieldMap = {};
  Map<int, TextEditingController> answerControllers = {};
  bool? isCrispChatEnabled = false;
  bool? isChatgptEnabled = false;
  String? crispChatIcon;

  late CrispConfig configData;

  @override
  void initState() {
    super.initState();
    checkIfAppIsUpdate(context);
    getDoctorDashboardApiCall();
  }

  Future<void> getDoctorDashboardApiCall() async {
    // Early return if widget is disposed
    if (!mounted) return;

    appStore.setLoading(true);

    try {
      final value = await getDoctorDashboard();

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 200));

      userStore.setDoctorData(value.data!);
      // Safely handle all possible null values
      isCrispChatEnabled =
          value.isCrispChatEnabled ?? value.isChatgptEnabled ?? false;

      crispChatIcon = value.crispChatIcon ?? '';
      isChatgptEnabled = value.isChatgptEnabled ?? false;
      chatgptKey = value.chatgptKey ?? '';
      mDoctorDashboardData = value;
      appStore.setAskExpertStatus(value.futureaskexpert ?? false);

      if (value.crispChatWebsiteId != null &&
          value.crispChatWebsiteId!.isNotEmpty &&
          userStore.doctor != null &&
          userStore.doctor!.id != null) {
        final user = User(
          email: userStore.doctor!.email ?? '',
          nickName: userStore.doctor!.name ?? 'Doctor',
          avatar: userStore.doctor?.healthExpertsImage ?? "",
        );

        await Future.delayed(const Duration(milliseconds: 500));

        configData = CrispConfig(
          user: user,
          tokenId: userStore.doctor!.id!.toString(),
          enableNotifications: true,
          websiteID: value.crispChatWebsiteId!,
        );
      }

      // Safely build grid data with null checks
      gridData = [
        {
          "title": language.newQuestions,
          "count": value.newQution ?? 0,
          "color": Colors.green.shade400
        },
        {
          "title": language.myAnswers,
          "count": value.myAnswers ?? 0,
          "color": Colors.redAccent.shade200
        },
      ];

      setState(() {});
    } catch (error) {
      if (mounted) {
        toast("Something went wrong");
      }
    } finally {
      if (mounted) {
        appStore.setLoading(false);
      }
    }
  }

  void updateGridData() {
    if (mounted) {
      setState(() {
        gridData = [
          {
            "title": language.newQuestions,
            "count": mDoctorDashboardData!.newQution ?? 0,
            "color": Colors.green.shade200
          },
          {
            "title": language.myAnswers,
            "count": mDoctorDashboardData!.myAnswers ?? 0,
            "color": Colors.deepPurpleAccent.shade200
          },
        ];
      });
    }
  }

  /// Save Question Answer
  saveQuestionAnswer(int index, String questionId) async {
    final answer = answerControllers[index]?.text.trim();
    if (answer == null || answer.isEmpty) {
      toast('Please enter an answer.');
      return;
    }

    if (mounted) {
      setState(() {
        showTextFieldMap[index] = false;
        answerControllers[index]?.clear();
      });
    }

    hideKeyboard(context);

    appStore.setLoading(true);

    Map<String, dynamic> req = {
      "expert_answer": answer,
      "id": questionId,
    };

    await saveQuestionToExpertApi(req).then((value) {
      if (value.status == true) {
        toast(value.message);
        mDoctorDashboardData!.askexpertList!
            .remove(mDoctorDashboardData!.askexpertList?[index]);

        /// Update the count of my Questions
        mDoctorDashboardData!.myAnswers =
            (mDoctorDashboardData!.myAnswers ?? 0) + 1;
        updateGridData();
        appStore.setLoading(false);
      } else {
        toast(value.message);
        appStore.setLoading(false);
        return;
      }
    }).catchError((error) {
      appStore.setLoading(false);
      toast('Failed to save answer: ${error.toString()}');
    });
  }

  ScrollController scrollController = ScrollController();

  void navigateToScreen(String title) {
    Widget screen;

    if (title == language.newQuestions) {
      screen = PendingQuestionsScreen(initialTabIndex: 0);
    } else if (title == language.myAnswers) {
      screen = PendingQuestionsScreen(initialTabIndex: 1);
    } else {
      screen = PendingQuestionsScreen(initialTabIndex: 0);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  configureCrispChat() async {
    FlutterCrispChat.setSessionString(
      key: userStore.doctor!.id!.toString(),
      value: userStore.doctor!.id!.toString(),
    );
  }

  @override
  void dispose() {
    answerControllers.forEach((_, controller) => controller.dispose());
    scrollController.dispose();
    super.dispose();
  }

  int calculateDayCount(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 0;
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      return end.difference(start).inDays + 1;
    } catch (e) {
      return 0;
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String formatDateForEducation(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '';
    try {
      final date = DateTime.parse(dateTime);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return dateTime;
    }
  }

  String formatTimeForEducation(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '';
    try {
      final date = DateTime.parse(dateTime);
      return DateFormat('hh:mm a').format(date);
    } catch (e) {
      return dateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: kPrimaryColor,
        appBar: appBarWidget(
          '${language.hey} 👋🏼 , ${getStringAsync(DR_NAME)}',
          showBack: false,
          textColor: Colors.black,
          context1: context,
          color: kPrimaryColor,
          // elevation: 1,
        ),
        floatingActionButton: isCrispChatEnabled != null && isCrispChatEnabled!
            ? FloatingActionButton(
                onPressed: () async {
                  configureCrispChat();
                  String? sessionId =
                      await FlutterCrispChat.getSessionIdentifier();
                  // LiveChatScreen().launch(context);
                  await FlutterCrispChat.openCrispChat(config: configData);
                },
                backgroundColor: ColorUtils.colorPrimary,
                // Use your app's primary color
                child: CachedNetworkImage(
                  imageUrl: crispChatIcon ?? "",
                  errorWidget: (context, url, error) =>
                      Image.asset(ic_crisp_chat),
                ))
            : SizedBox.shrink(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Observer(
          builder: (context) {
            return Stack(
              children: [
                SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      8.height,
                      GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.45,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        cacheExtent: 2.0,
                        shrinkWrap: true,
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                        itemCount: gridData.length,
                        itemBuilder: (context, index) {
                          final item = gridData[index];

                          return GestureDetector(
                            onTap: () {
                              navigateToScreen(item['title']);
                            },
                            child: Container(
                              decoration: boxDecorationWithRoundedCorners(
                                borderRadius:
                                    BorderRadius.circular(defaultRadius),
                                backgroundColor: item['color'],
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '${item['count']}',
                                    style: boldTextStyle(
                                        size: 30, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  4.height,
                                  Text(
                                    item['title'],
                                    style: primaryTextStyle(
                                        size: 14, color: Colors.white),
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                  ).paddingSymmetric(horizontal: 32)
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      /// Appointment list

                      20.height,
                      Container(
                          decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.only(
                                topLeft: radiusCircular(20),
                                topRight: radiusCircular(20),
                              )),
                          child: Column(
                            children: [
                              20.height,
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(language.pendingQuestions,
                                      style: boldTextStyle(
                                          size: textFontSize_16,
                                          weight: FontWeight.w500,
                                          isHeader: true,
                                          color: scaffoldDarkColor)),
                                  Text(
                                    language.ViewAll,
                                    style: boldTextStyle(
                                        color: primaryColor,
                                        weight: FontWeight.w500,
                                        size: textFontSize_14),
                                  ).onTap(() {
                                    PendingQuestionsScreen().launch(context);
                                  })
                                ],
                              ).paddingSymmetric(horizontal: 16).visible(
                                  mDoctorDashboardData != null &&
                                      mDoctorDashboardData!.askexpertList !=
                                          null &&
                                      mDoctorDashboardData!
                                          .askexpertList!.isNotEmpty),
                              8.height,
                              mDoctorDashboardData != null &&
                                      mDoctorDashboardData?.askexpertList !=
                                          null &&
                                      mDoctorDashboardData!
                                          .askexpertList!.isNotEmpty
                                  ? AnimatedListView(
                                      shrinkWrap: true,
                                      itemCount: mDoctorDashboardData!
                                          .askexpertList!.length,
                                      itemBuilder: (context, index) {
                                        final singleData = mDoctorDashboardData!
                                            .askexpertList![index];
                                        final showTextField =
                                            showTextFieldMap[index] ?? false;
                                        final data = mDoctorDashboardData!
                                            .askexpertList![index];
                                        if (!answerControllers
                                            .containsKey(index)) {
                                          answerControllers[index] =
                                              TextEditingController();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0, horizontal: 16.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        defaultRadius)),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: () {
                                                if (mounted) {
                                                  setState(() {
                                                    showTextFieldMap[index] =
                                                        !showTextFieldMap[
                                                            index]!;
                                                  });
                                                }
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // User Info Row
                                                    Row(
                                                      children: [
                                                        cachedImage(
                                                          data.user
                                                                  ?.profileImage ??
                                                              '',
                                                          height: 50,
                                                          width: 50,
                                                          fit: BoxFit.cover,
                                                        ).cornerRadiusWithClipRRect(
                                                            50),
                                                        SizedBox(width: 12),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              data.user
                                                                      ?.displayName ??
                                                                  "Anonymous",
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            SizedBox(height: 4),
                                                            Text(
                                                              //"Asked on ${DateFormat('MMMM d, y - hh:mm a').format(data.createdAt)}",
                                                              "${language.askedOn} ${convertUtcToLocal(formatDateToTimezone(dateString: singleData.createdAt.toString()))}",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 16),
                                                    Divider(
                                                      color: Colors.grey[300],
                                                      height: 1,
                                                    ),
                                                    SizedBox(height: 16),
                                                    // Question Description
                                                    ExpandableText(
                                                      text: data.description,
                                                    ),
                                                    SizedBox(height: 16),
                                                    ScrollableNetworkImageRow(
                                                      imageFiles: singleData
                                                              .askexpertImage ??
                                                          [],
                                                      title: singleData.user
                                                              ?.displayName ??
                                                          '',
                                                    ),

                                                    SizedBox(height: 16),
                                                    // Divider
                                                    Divider(
                                                      color: Colors.grey[300],
                                                      height: 1,
                                                    ),
                                                    SizedBox(height: 16),
                                                    // Text Field (Conditionally Rendered)
                                                    if (showTextField)
                                                      AnimatedContainer(
                                                        duration: Duration(
                                                            milliseconds: 300),
                                                        curve: Curves.easeInOut,
                                                        child: TextField(
                                                          controller:
                                                              answerControllers[
                                                                  index],
                                                          decoration:
                                                              InputDecoration(
                                                            hintText: language
                                                                .typeYourAnswer,
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            filled: true,
                                                            fillColor: Colors
                                                                .grey[100],
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                              vertical: 12,
                                                              horizontal: 16,
                                                            ),
                                                          ),
                                                          maxLines: 3,
                                                          readOnly: appStore
                                                              .isLoading,
                                                        ),
                                                      ),
                                                    SizedBox(
                                                        height: showTextField
                                                            ? 16
                                                            : 0),

                                                    // Answer Button
                                                    Center(
                                                      child: AnimatedSwitcher(
                                                        duration: Duration(
                                                            milliseconds: 300),
                                                        child: showTextField
                                                            ? Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  ElevatedButton
                                                                      .icon(
                                                                    onPressed:
                                                                        () {
                                                                      if (showTextField) {
                                                                        saveQuestionAnswer(
                                                                          index,
                                                                          singleData
                                                                              .id
                                                                              .toString(),
                                                                        );
                                                                      }
                                                                    },
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                      backgroundColor:
                                                                          ColorUtils
                                                                              .colorPrimary,
                                                                      foregroundColor:
                                                                          Colors
                                                                              .white,
                                                                      padding:
                                                                          EdgeInsets
                                                                              .symmetric(
                                                                        vertical:
                                                                            12,
                                                                        horizontal:
                                                                            24,
                                                                      ),
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(12),
                                                                      ),
                                                                      elevation:
                                                                          0,
                                                                    ),
                                                                    icon: Icon(
                                                                        Icons
                                                                            .send,
                                                                        size:
                                                                            18),
                                                                    label: Text(
                                                                      language
                                                                          .submitAnswer,
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.w500),
                                                                    ),
                                                                  ),
                                                                  ElevatedButton
                                                                      .icon(
                                                                    onPressed:
                                                                        () {
                                                                      if (mounted) {
                                                                        setState(
                                                                            () {
                                                                          showTextFieldMap[index] =
                                                                              false;
                                                                          answerControllers[index]
                                                                              ?.clear();
                                                                        });
                                                                      }
                                                                    },
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                      backgroundColor:
                                                                          Colors
                                                                              .grey[400],
                                                                      foregroundColor:
                                                                          Colors
                                                                              .white,
                                                                      padding:
                                                                          EdgeInsets
                                                                              .symmetric(
                                                                        vertical:
                                                                            12,
                                                                        horizontal:
                                                                            24,
                                                                      ),
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(12),
                                                                      ),
                                                                      elevation:
                                                                          0,
                                                                    ),
                                                                    icon: Icon(
                                                                        Icons
                                                                            .cancel,
                                                                        size:
                                                                            18),
                                                                    label: Text(
                                                                      language
                                                                          .cancel,
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.w500),
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            : AppButton(
                                                                shapeBorder:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                height: 40,
                                                                text: "Answer",
                                                                width: context
                                                                    .width(),
                                                                elevation: 0,
                                                                color:
                                                                    primaryColor,
                                                                textColor:
                                                                    Colors
                                                                        .white,
                                                                onTap: () {
                                                                  setState(() {
                                                                    showTextFieldMap[
                                                                            index] =
                                                                        true;
                                                                  });
                                                                },
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      })
                                  : SizedBox.shrink(),
                              8.height,
                            ],
                          )),
                    ],
                  ),
                ),
                Loader().center().visible(appStore.isLoading)
              ],
            );
          },
        ));
  }
}

class Event {
  final String title;

  Event(this.title);

  @override
  String toString() => title;
}
