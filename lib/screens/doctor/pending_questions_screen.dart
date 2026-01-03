import 'package:era_flutter/extensions/common.dart';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extension_util/int_extensions.dart';
import 'package:era_flutter/extensions/extension_util/string_extensions.dart';
import 'package:era_flutter/extensions/extension_util/widget_extensions.dart';
import 'package:era_flutter/screens/common/ask_question_widget.dart';
import 'package:era_flutter/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../extensions/app_button.dart';
import '../../extensions/colors.dart';
import '../../extensions/constants.dart';
import '../../extensions/decorations.dart';
import '../../extensions/loader_widget.dart';
import '../../extensions/new_colors.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../model/user/dashboard_response.dart';
import '../../network/rest_api.dart';
import '../../utils/dynamic_theme.dart';
import '../common/expandable_text.dart';

class PendingQuestionsScreen extends StatefulWidget {
  final int initialTabIndex;

  PendingQuestionsScreen({this.initialTabIndex = 0});

  @override
  _PendingQuestionsScreenState createState() => _PendingQuestionsScreenState();
}

class _PendingQuestionsScreenState extends State<PendingQuestionsScreen> {
  List<AskExpertList> pendingQuestions = [];
  List<AskExpertList> answeredQuestions = [];
  Map<int, bool> showTextFieldMap = {};
  Map<int, TextEditingController> answerControllers = {};
  Map<int, bool> showEditTextFieldMap = {};
  Map<int, TextEditingController> editAnswerControllers = {};
  List<String> tabList = ['Pending', 'My Answered'];
  int currentTabIndex = 0;
  bool isInitialLoading = true;
  bool isLoadingMore = false;
  int currentPagePending = 1;
  int currentPageAnswered = 1;
  bool hasMorePagesPending = true;
  bool hasMorePagesAnswered = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    currentTabIndex = widget.initialTabIndex;
    _loadQuestions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        (currentTabIndex == 0 ? hasMorePagesPending : hasMorePagesAnswered)) {
      if (currentTabIndex == 0) {
        _loadQuestions(pagePending: currentPagePending + 1);
      } else {
        _loadQuestions(pageAnswered: currentPageAnswered + 1);
      }
    }
  }

  Future<void> _loadQuestions({int? pagePending, int? pageAnswered}) async {
    pagePending ??= 1;
    pageAnswered ??= 1;
    if (pagePending == 1 && pageAnswered == 1) {
      setState(() {
        isInitialLoading = true;
        pendingQuestions.clear();
        answeredQuestions.clear();
      });
    } else {
      setState(() {
        isLoadingMore = true;
      });
    }
    appStore.setLoading(true);
    try {
      await Future.wait([
        getPendingQuestionListApi(page: pagePending),
        getAnsweredQuestionListApi(page: pageAnswered),
      ]);
    } catch (error) {
      toast(error.toString());
    } finally {
      setState(() {
        isInitialLoading = false;
        isLoadingMore = false;
      });
      appStore.setLoading(false);
    }
  }

  Future<void> getPendingQuestionListApi({int? page}) async {
    page ??= 1;
    try {
      final value = await getPendingQuestionToExpertApi(page: page);
      if (mounted) {
        setState(() {
          if (page == 1) {
            pendingQuestions =
                value.data?.where((q) => q.expertAnswer == null).toList() ?? [];
          } else {
            pendingQuestions.addAll(
                value.data?.where((q) => q.expertAnswer == null).toList() ??
                    []);
          }
          currentPagePending = page!;
          hasMorePagesPending = (value.data?.length ?? 0) >= 10;
        });
      }
    } catch (e) {
      toast(e.toString());
      setState(() {
        hasMorePagesPending = false;
      });
    }
  }

  Future<void> getAnsweredQuestionListApi({int? page}) async {
    page ??= 1;
    try {
      final value = await getQuestionToExpertApi(page: page);
      if (mounted) {
        setState(() {
          if (page == 1) {
            answeredQuestions =
                value.data?.where((q) => q.expertAnswer != null).toList() ?? [];
          } else {
            answeredQuestions.addAll(
                value.data?.where((q) => q.expertAnswer != null).toList() ??
                    []);
          }
          currentPageAnswered = page!;
          hasMorePagesAnswered = (value.data?.length ?? 0) >= 10;
        });
      }
    } catch (e) {
      toast(e.toString());
      setState(() {
        hasMorePagesAnswered = false;
      });
    }
  }

  Future<void> saveQuestionAnswer(int index, String questionId) async {
    final answer = answerControllers[index]?.text.trim();
    if (answer == null || answer.isEmpty) {
      return;
    }
    hideKeyboard(context);
    setState(() {
      showTextFieldMap[index] = false;
      answerControllers[index]?.clear();
    });
    appStore.setLoading(true);

    Map<String, dynamic> req = {
      "expert_answer": answer,
      "id": questionId,
    };

    try {
      final value = await saveQuestionToExpertApi(req);
      appStore.setLoading(false);
      if (value.status == true) {
        toast(value.message);
        setState(() {
          pendingQuestions.removeAt(index);
          getAnsweredQuestionListApi(page: 1);
        });
      } else {
        toast(value.message);
      }
    } catch (e) {
      appStore.setLoading(false);
    }
  }

  Future<void> SaveEditAnswer(int index, String questionId) async {
    final answer = editAnswerControllers[index]?.text.trim();
    if (answer == null || answer.isEmpty) {
      toast('Please enter an answer.');
      return;
    }
    hideKeyboard(context);
    setState(() {
      showEditTextFieldMap[index] = false;
      editAnswerControllers[index]?.clear();
    });
    appStore.setLoading(true);

    Map<String, dynamic> req = {
      "expert_answer": answer,
    };

    try {
      final value = await updateAskDataApi(questionId, req);
      appStore.setLoading(false);
      if (value.status == true) {
        toast(value.message);
        await getAnsweredQuestionListApi(page: 1);
      } else {
        toast(value.message);
      }
    } catch (e) {
      appStore.setLoading(false);
    }
  }

  Widget _buildPendingQuestionsContent() {
    if (isInitialLoading) {
      return SizedBox.shrink();
    }
    if (pendingQuestions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          emptyWidget(),
          Center(child: Text(language.noPendingQuestions)),
        ],
      ).paddingTop(context.height() * 0.22);
    }

    return Column(
      children: [
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: pendingQuestions.length,
          itemBuilder: (context, index) {
            final singleData = pendingQuestions[index];
            final showTextField = showTextFieldMap[index] ?? false;

            if (!answerControllers.containsKey(index)) {
              answerControllers[index] = TextEditingController();
            }

            return _buildQuestionCard(singleData, index, showTextField);
          },
        ),
        if (isLoadingMore)
          Padding(
            padding: EdgeInsets.all(16),
            child: Loader(),
          ),
      ],
    );
  }

  Widget _buildAnsweredQuestionsContent() {
    if (isInitialLoading) {
      return SizedBox.shrink();
    }
    if (answeredQuestions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          emptyWidget(),
          Center(child: Text(language.NoAnsweredQuestions)),
        ],
      );
    }

    return Column(
      children: [
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: answeredQuestions.length,
          itemBuilder: (context, index) {
            final singleData = answeredQuestions[index];
            final showEditTextField = showEditTextFieldMap[index] ?? false;

            if (!editAnswerControllers.containsKey(index)) {
              editAnswerControllers[index] =
                  TextEditingController(text: singleData.expertAnswer);
            }

            return QuestionAnswerCard(
              title: singleData.title,
              description: singleData.description,
              expertAnswer: singleData.expertAnswer,
              user: singleData.user,
              expert: singleData.expert,
              askedOn: formatDateToTimezone(
                  dateString: singleData.createdAt.toString()),
              ansOnDoctor: formatDateToTimezone(
                  dateString: singleData.updatedAt.toString()),
              images: singleData.askexpertImage,
              showEditTextField: showEditTextField,
              editAnswerController: editAnswerControllers[index],
              onEditTap: () {
                setState(() {
                  showEditTextFieldMap[index] = true;
                });
              },
              onSave: () {
                SaveEditAnswer(index, singleData.id.toString());
              },
              onCancel: () {
                setState(() {
                  showEditTextFieldMap[index] = false;
                  editAnswerControllers[index]?.text =
                      singleData.expertAnswer ?? '';
                });
              },
            ).paddingSymmetric(horizontal: 16, vertical: 8);
          },
        ),
        if (isLoadingMore)
          Padding(
            padding: EdgeInsets.all(16),
            child: Loader(),
          ),
      ],
    );
  }

  Widget _buildQuestionCard(
      AskExpertList singleData, int index, bool showTextField) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (mounted) {
              setState(() {
                showTextFieldMap[index] = !showTextFieldMap[index]!;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                10.height,
                Row(
                  children: [
                    cachedImage(
                      singleData.user?.profileImage ?? '',
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                    ).cornerRadiusWithClipRRect(50),
                    12.width,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          singleData.user?.displayName ?? "Anonymous",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        4.height,
                        Text(
                          "${language.askedOn} ${convertUtcToLocal(formatDateToTimezone(dateString: singleData.createdAt.toString()))}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                10.height,
                Divider(
                  color: Colors.grey[300],
                  height: 1,
                ),
                16.height,
                ExpandableText(
                  text: singleData.description,
                  style: boldTextStyle(
                      size: textFontSize_14,
                      weight: FontWeight.w400,
                      color: mainColorText),
                ),
                16.height,
                ScrollableNetworkImageRow(
                  imageFiles: singleData.askexpertImage,
                  title: singleData.user?.displayName,
                ),
                10.height,
                if (showTextField)
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: bgColor,
                        borderRadius: radius(defaultRadius),
                      ),
                      child: TextField(
                        maxLines: 4,
                        controller: answerControllers[index],
                        decoration: InputDecoration(
                          hintText:
                              language.typeYourAnswer,
                          hintStyle: boldTextStyle(
                            size: textFontSize_14,
                            weight: FontWeight.w400,
                            color: mainColorBodyText,
                          ),
                          border: InputBorder.none,
                        ),
                        style: boldTextStyle(size: textFontSize_14),
                      ),
                    ),
                  ),
                SizedBox(height: showTextField ? 16 : 0),
                Center(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: showTextField
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (showTextField) {
                                    saveQuestionAnswer(
                                      index,
                                      singleData.id.toString(),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ColorUtils.colorPrimary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: Icon(Icons.send, size: 18),
                                label: Text(
                                  language.submitAnswer,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      showTextFieldMap[index] = false;
                                      answerControllers[index]?.clear();
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: Icon(Icons.cancel, size: 18),
                                label: Text(
                                  language.cancel,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          )
                        : AppButton(
                            shapeBorder: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                            height: 40,
                            text: language.answerQuestion,
                            width: context.width(),
                            elevation: 0,
                            color: kPrimaryColor,
                            textColor: primaryColor,
                            onTap: () {
                              setState(() {
                                showTextFieldMap[index] = true;
                              });
                            },
                          ),
                  ),
                ),
                8.height,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _loadQuestions(pagePending: 1, pageAnswered: 1),
            child: CustomScrollView(
              controller: _scrollController,
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
                    language.pendingQuestions,
                    style: boldTextStyle(
                        color: mainColorText,
                        size: 18,
                        weight: FontWeight.w500),
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
                        Container(height: 40, color: mainColorLight),
                      ],
                    ),
                    Transform.translate(
                      offset: Offset(0, -30),
                      child: Container(
                        width: context.width(),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        constraints:
                            BoxConstraints(minHeight: context.height() - 100),
                        child: Observer(
                          builder: (context) {
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  20.height,
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: EdgeInsets.all(4),
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children:
                                          List.generate(tabList.length, (i) {
                                        final isSelected = currentTabIndex == i;
                                        return Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                currentTabIndex = i;
                                                if (i == 0 &&
                                                    pendingQuestions.isEmpty) {
                                                  _loadQuestions(
                                                      pagePending: 1);
                                                } else if (i == 1 &&
                                                    answeredQuestions.isEmpty) {
                                                  _loadQuestions(
                                                      pageAnswered: 1);
                                                }
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              margin: EdgeInsets.symmetric(
                                                  horizontal: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? ColorUtils.colorPrimary
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12),
                                              child: Text(
                                                tabList[i].validate(),
                                                textAlign: TextAlign.center,
                                                style: boldTextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : mainColorText,
                                                  size: textFontSize_14,
                                                  weight: FontWeight.w500,
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
                                  10.height,
                                  currentTabIndex == 0
                                      ? _buildPendingQuestionsContent()
                                      : _buildAnsweredQuestionsContent(),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Observer(
            builder: (context) => Loader()
                .visible(appStore.isLoading && isInitialLoading)
                .center(),
          ),
        ],
      ),
    );
  }
}
