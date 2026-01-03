import 'dart:async';
import 'dart:io';
import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/screens/user/user_dashboard_screen.dart';
import 'package:era_flutter/utils/dynamic_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../ads/facebook_ads_manager.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../utils/app_common.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_images.dart';
import '../widgets/disclaimer_widget.dart';
import 'menstrual_report_screen.dart';
import 'home_screen.dart';

class GraphsAndReportScreen extends StatefulWidget {
  final bool? shouldShowBackButton;

  const GraphsAndReportScreen({super.key, this.shouldShowBackButton});

  @override
  State<GraphsAndReportScreen> createState() => _GraphsAndReportScreenState();
}

class _GraphsAndReportScreenState extends State<GraphsAndReportScreen> {
  bool hasCycleTrend = false;
  bool hasPeriodGraph = false;
  bool hasCycleHistory = false;
  bool hasSleepGraph = false;
  bool hasBodyTemp = false;
  bool hasWaterGraph = false;
  bool hasMeditationGraph = false;
  bool hasWeightGraphData = false;
  bool isLoadingCompleted = false;
  File? filemain;

  @override
  void initState() {
    super.initState();
    initializeGraph();
    logScreenView("Graph & Report screen");
  }

  initializeGraph() async {
    final results = await Future.wait([
      instance.hasCycleTrendsGraphData(),
      instance.hasPeriodGraphData(),
      instance.hasCycleHistoryGraphData(),
      instance.hasBodyTemperatureGraphData(),
      instance.hasWaterGraphData(),
      instance.hasMeditationGraphData(),
      instance.hasWeightGraphData(),
      instance.hasSleepGraphData(),
    ]);
    hasCycleTrend = results[0];
    hasPeriodGraph = results[1];
    hasCycleHistory = results[2];
    hasBodyTemp = results[3];
    hasWaterGraph = results[4];
    hasMeditationGraph = results[5];
    hasWeightGraphData = results[6];
    hasSleepGraph = results[7];

    setState(() {
      isLoadingCompleted = true;
    });
  }

  bool areAllGraphsNotInitialized() {
    return !hasCycleTrend &&
        !hasPeriodGraph &&
        !hasCycleHistory &&
        !hasBodyTemp &&
        !hasWaterGraph &&
        !hasMeditationGraph &&
        !hasWeightGraphData &&
        !hasSleepGraph;
  }

  Widget textView(String title) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(left: 5),
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.rectangle,
        border: Border.all(width: 1.0, color: Colors.blue),
        borderRadius: const BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      child: Text(
        title,
        style:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Future<void> _downloadFile(File file, String type, String title) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = type == 'Image' ? 'png' : 'pdf';
      final fileName = '${title.replaceAll(' ', '_')}_$timestamp.$extension';
      final newPath = '${directory.path}/$fileName';
      final newFile = await file.copy(newPath);

      await Share.shareXFiles(
        [XFile(newFile.path)],
        text: 'Sharing $type graph',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: mainColorLight,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (!isLoadingCompleted) {
      return Text("Loading...").center();
    }

    if (areAllGraphsNotInitialized()) {
      return _buildNoDataView();
    }

    return _buildGraphsView();
  }

  String formatForAnalytics(String fileName) {
    return fileName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<void> handleFileDownload(
    File file, {
    required String fileType,
    required String fileName,
  }) async {
    try {
      filemain = file;

      if (!(appStore.adsConfig?.adsconfigAccess ?? false)) {
        await _downloadFile(file, fileType, fileName);
        return;
      }

      final shouldShowAd = (fileType == "Image")
          ? appStore.showAdsBasedOnConfig?.downloadImageData ?? false
          : appStore.showAdsBasedOnConfig?.downloadPdfData ?? false;

      if (!shouldShowAd) {
        await _downloadFile(file, fileType, fileName);
        return;
      }

      final completer = Completer<void>();
      showAdLoadingDialog(context, completer);

      FacebookAdsManager.showRewardedVideoAd(
        onRewardedVideoCompleted: () async {
          completer.complete();
          if (Navigator.canPop(context)) Navigator.pop(context);
          await _downloadFile(file, fileType, fileName);
          logAnalyticsEvent(
            category: "download",
            action: "${formatForAnalytics(fileName)}_downloaded",
          );
        },
        onError: () async {
          completer.complete();
          //  if (Navigator.canPop(context)) Navigator.pop(context);
          await _downloadFile(file, fileType, fileName);
        },
      );
    } catch (e) {
      //if (Navigator.canPop(context)) Navigator.pop(context);
      await _downloadFile(file, fileType, fileName);
      debugPrint('File download error: $e');
    }
  }

  void showAdLoadingDialog(BuildContext context, Completer<void> completer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: FutureBuilder(
          future: completer.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
            }

            return AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Loading Ads...'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Future<void> handleFileDownload(
  //     File file, {
  //       required String fileType,
  //       required String fileName,
  //     }) async {
  //   filemain = file;
  //   if (appStore.adsConfig?.adsconfigAccess ?? false) {
  //     FacebookAdsManager.showRewardedVideoAd(
  //       onRewardedVideoCompleted: () async {
  //         pop();
  //         await _downloadFile(file, fileType, fileName);
  //       },
  //       onError: () async {
  //         pop();
  //         await _downloadFile(file, fileType, fileName);
  //       },
  //     );
  //   } else {
  //     await _downloadFile(file, fileType, fileName);
  //   }
  // }

  Widget _buildNoDataView() {
    return IntrinsicHeight(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(defaultRadius),
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  ic_woman_with_flower,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
                16.height,
                Text(
                  language.noSataAvailableToGenerateYourGraph,
                  textAlign: TextAlign.center,
                  style: boldTextStyle(
                    weight: FontWeight.w500,
                    size: textFontSize_16,
                  ),
                ),
                16.height,
                CustomListTile(
                  icon: Icons.check,
                  normalText1: language.pleaseLogYourData,
                  boldText: "",
                  normalText2: language.toGenerateDetailedGraphs,
                ),
                16.height,
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: ColorUtils.colorPrimary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        language.logPreviousCycle,
                        style: boldTextStyle(
                          color: Colors.white,
                          isHeader: true,
                        ),
                      ),
                    ],
                  ),
                ).center().onTap(() {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MenstrualCycleMonthlyCalenderView(
                        themeColor: Colors.black,
                        isShowCloseIcon: true,
                        onDataChanged: (value) {
                          if (value) {
                            setState(() {
                              DashboardScreen(currentIndex: 2).launch(context);
                            });
                          }
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ).center();
  }

  Widget _buildGraphsView() {
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight;
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: kToolbarHeight + MediaQuery.of(context).padding.top,
            width: double.infinity,
            decoration: BoxDecoration(
              color: kPrimaryColor,
            ),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                IconButton(
                        onPressed: () {
                          pop();
                        },
                        icon: Icon(CupertinoIcons.back))
                    .visible(widget.shouldShowBackButton ?? false),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    language.graphsAndReport,
                    style: boldTextStyle(
                      color: Colors.black,
                      size: 20,
                      weight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: Offset(0, 0),
            child: Container(
              padding: EdgeInsets.zero,
              width: context.width(),
              decoration: BoxDecoration(
                color: mainBgLightGrey,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.only(left: 16),
                          height: kToolbarHeight +
                              MediaQuery.of(context).padding.top,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(defaultRadius),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Expanded text column
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${language.ReportForADoctor} ❤️",
                                    style: boldTextStyle(
                                        size: textFontSize_16,
                                        color: textPrimaryColor),
                                  ),
                                  4.height,
                                  Text(
                                    language.ShareYourSymptoms,
                                    style: primaryTextStyle(
                                        size: textFontSize_14,
                                        color: Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ).expand(),
                              Image.asset(
                                ic_nurse,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ).paddingSymmetric(horizontal: 16).onTap(() {
                          showAdBeforeNavigation(
                              context: context,
                              showAd: (appStore.adsConfig?.adsconfigAccess ??
                                      false) &&
                                  (appStore.showAdsBasedOnConfig
                                          ?.downloadDoctorReport ??
                                      false),
                              postAction: () async {},
                              screen: MenstrualReportScreen());
                        }),
                        10.height,
                        Text(
                          language.cycleTrends,
                          style: boldTextStyle(
                              size: textFontSize_16,
                              color: mainColorText,
                              weight: FontWeight.w500),
                        ).paddingSymmetric(horizontal: 16),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Container(
                                    width: double.infinity,
                                    height: GRAPH_HEIGHT,
                                    child: MenstrualCycleTrendsGraph(
                                      onPdfDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'PDF',
                                              fileName: 'Cycle Trends'),
                                      onImageDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'Image',
                                              fileName: 'Cycle Trends'),
                                      isShowMoreOptions: true,
                                      isShowXAxisTitle: true,
                                      isShowSeriesColor: true,
                                      isShowYAxisTitle: true,
                                    ),
                                  ).cornerRadiusWithClipRRect(16),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).paddingSymmetric(horizontal: 16),
                      ],
                    ),
                  ).visible(hasCycleTrend && userStore.goalIndex == 0),
                  20.height.visible(hasCycleTrend && userStore.goalIndex == 0),
                  // Period Length
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              language.periodLength,
                              style: boldTextStyle(
                                  size: textFontSize_16,
                                  color: mainColorText,
                                  weight: FontWeight.w500),
                            ),
                          ],
                        ),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            defaultRadius)),
                                    height: GRAPH_HEIGHT,
                                    child: Padding(
                                      padding: const EdgeInsets.all(0),
                                      child: MenstrualCyclePeriodsGraph(
                                        onPdfDownloadCallback: (file) =>
                                            handleFileDownload(file,
                                                fileType: 'PDF',
                                                fileName: 'Period Length'),
                                        onImageDownloadCallback: (file) =>
                                            handleFileDownload(file,
                                                fileType: 'Image',
                                                fileName: 'Period Length'),
                                        isShowMoreOptions: true,
                                        isShowXAxisTitle: true,
                                        isShowYAxisTitle: true,
                                      ),
                                    ),
                                  ).cornerRadiusWithClipRRect(defaultRadius),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).paddingSymmetric(horizontal: 16),
                  ).visible(hasPeriodGraph && userStore.goalIndex == 0),
                  20.height.visible(hasPeriodGraph && userStore.goalIndex == 0),
                  // Water Chart
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              language.waterInformation,
                              style: boldTextStyle(
                                  size: textFontSize_16,
                                  color: mainColorText,
                                  weight: FontWeight.w500),
                            ),
                          ],
                        ),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(defaultRadius),
                                    ),
                                    height: 250,
                                    child: MenstrualCycleWaterGraph(
                                      onPdfDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'PDF',
                                              fileName: 'Water Information'),
                                      onImageDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'Image',
                                              fileName: 'Water Information'),
                                      graphColor: ColorUtils.colorPrimary
                                          .withOpacity(0.5),
                                      isShowMoreOptions: true,
                                      isShowXAxisTitle: true,
                                      isShowYAxisTitle: true,
                                    ),
                                  ).cornerRadiusWithClipRRect(defaultRadius),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).visible(hasWaterGraph),
                  20.height.visible(hasWaterGraph),
                  // Temperature Information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              language.bodyTemperature,
                              style: boldTextStyle(
                                  size: textFontSize_16,
                                  color: mainColorText,
                                  weight: FontWeight.w500),
                            ),
                          ],
                        ),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(defaultRadius),
                                    ),
                                    height: GRAPH_HEIGHT,
                                    child: MenstrualBodyTemperatureGraph(
                                      onPdfDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'PDF',
                                              fileName: 'Body Temperature'),
                                      onImageDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'Image',
                                              fileName: 'Body Temperature'),
                                      bodyTemperatureUnits:
                                          BodyTemperatureUnits.celsius,
                                      isShowMoreOptions: true,
                                    ),
                                  ).cornerRadiusWithClipRRect(defaultRadius),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).visible(hasBodyTemp),
                  20.height.visible(hasBodyTemp),
                  // Meditation
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              language.meditation,
                              style: boldTextStyle(
                                  size: textFontSize_16,
                                  color: mainColorText,
                                  weight: FontWeight.w500),
                            ),
                          ],
                        ),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(defaultRadius),
                                    ),
                                    height: GRAPH_HEIGHT,
                                    child: MenstrualMeditationGraph(
                                      onPdfDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'PDF',
                                              fileName: 'Meditation'),
                                      onImageDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'Image',
                                              fileName: 'Meditation'),
                                      graphColor: Colors.pink,
                                      isShowMoreOptions: true,
                                      isShowXAxisTitle: true,
                                      isShowYAxisTitle: true,
                                    ),
                                  ).cornerRadiusWithClipRRect(defaultRadius),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).visible(hasMeditationGraph),
                  20.height.visible(hasMeditationGraph),
                  // Weight Information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              language.weight,
                              style: boldTextStyle(
                                  size: textFontSize_16,
                                  color: mainColorText,
                                  weight: FontWeight.w500),
                            ),
                          ],
                        ),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(defaultRadius),
                                    ),
                                    height: GRAPH_HEIGHT,
                                    child: MenstrualWeightGraph(
                                      onPdfDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'PDF',
                                              fileName: 'Weight'),
                                      onImageDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'Image',
                                              fileName: 'Weight'),
                                      graphColor: Colors.pinkAccent,
                                      isShowMoreOptions: true,
                                      isShowXAxisTitle: true,
                                      isShowYAxisTitle: true,
                                    ),
                                  ).cornerRadiusWithClipRRect(defaultRadius),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).visible(hasWeightGraphData),
                  20.height.visible(hasWeightGraphData),
                  // Cycle History
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.cycleHistory,
                          style: boldTextStyle(
                              size: textFontSize_16,
                              color: mainColorText,
                              weight: FontWeight.w500),
                        ),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 24.0, left: 8.0, right: 8.0),
                                  child: Container(
                                    width: double.infinity,
                                    height: 320,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(defaultRadius),
                                    ),
                                    child: MenstrualCycleHistoryGraph(
                                        headerTitle: ""),
                                  ).cornerRadiusWithClipRRect(defaultRadius),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        8.height,
                      ],
                    ),
                  ).visible(hasCycleHistory && userStore.goalIndex == 0),
                  20
                      .height
                      .visible(hasCycleHistory && userStore.goalIndex == 0),
                  // Sleep
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.sleep,
                          style: boldTextStyle(
                              size: textFontSize_16,
                              color: mainColorText,
                              weight: FontWeight.w500),
                        ),
                        10.height,
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(defaultRadius),
                          ),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(defaultRadius),
                                    ),
                                    height: GRAPH_HEIGHT,
                                    child: MenstrualSleepGraph(
                                      onPdfDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'PDF',
                                              fileName: 'Sleep Graph'),
                                      onImageDownloadCallback: (file) =>
                                          handleFileDownload(file,
                                              fileType: 'Image',
                                              fileName: 'Sleep Graph'),
                                      isShowMoreOptions: true,
                                      isShowXAxisTitle: true,
                                      isShowYAxisTitle: true,
                                      graphColor: ColorUtils.colorPrimary,
                                    ),
                                  ).cornerRadiusWithClipRRect(defaultRadius),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: buildDisclaimerWidget(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).visible(hasSleepGraph),
                ],
              ).paddingSymmetric(vertical: 16),
            ),
          ),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}
