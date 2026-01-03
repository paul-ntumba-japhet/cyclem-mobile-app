import 'package:era_flutter/extensions/common.dart';
import 'package:era_flutter/extensions/extension_util/widget_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../components/common/common_Scaffold_component.dart';
import '../../extensions/constants.dart';
import '../../extensions/loader_widget.dart';
import '../../extensions/text_styles.dart';
import '../../extensions/widgets.dart';
import '../../main.dart';
import '../../model/user/dashboard_response.dart';
import '../../network/rest_api.dart';
import '../../utils/app_common.dart';
import '../../utils/dynamic_theme.dart';
import '../common/ask_question_widget.dart';

class MyQuestionScreen extends StatefulWidget {
  @override
  _MyQuestionScreenState createState() => _MyQuestionScreenState();
}

class _MyQuestionScreenState extends State<MyQuestionScreen> {
  List<AskExpertList>? expertData = [];
  Map<int, bool> showTextFieldMap = {};
  Map<int, TextEditingController> answerControllers = {};

  @override
  void initState() {
    super.initState();
    getExpertQuestionListApi();
  }

  getExpertQuestionListApi() async {
    appStore.setLoading(true);
    await getQuestionToExpertApi().then(
      (value) {
        appStore.setLoading(false);
        setState(() {
          expertData = value.data;
        });
      },
    ).whenComplete(
      () {
        appStore.setLoading(false);
      },
    ).onError(
      (error, stackTrace) {
        toast(error.toString());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBar: appBarWidget('Expert Questions',
          context1: context,
          showBack: true,
          color: ColorUtils.colorPrimary,
          elevation: 1,
          titleTextStyle: boldTextStyle(
              size: textFontSize_18, isHeader: true, color: Colors.white),
          textColor: Colors.white),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: expertData?.length ?? 0,
                  itemBuilder: (context, index) {
                    final singleData = expertData![index];
                    final showTextField = showTextFieldMap[index] ?? false;

                    if (!answerControllers.containsKey(index)) {
                      answerControllers[index] = TextEditingController();
                    }
                    return QuestionAnswerCard(
                      user: singleData.user,
                      askedOn: formatDateToTimezone(
                          dateString: singleData.createdAt.toString()),
                      ansOnDoctor: formatDateToTimezone(
                          dateString: singleData.updatedAt.toString()),
                      description: singleData.description,
                      title: singleData.title,
                      expert: singleData.expert,
                      images: singleData.askexpertImage,
                      expertAnswer: singleData.expertAnswer,
                    ).paddingSymmetric(horizontal: 8);
                  },
                )
              ],
            ),
          ),
          Observer(
            builder: (context) {
              return Visibility(
                visible: appStore.isLoading,
                child: Center(
                  child: Loader(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
