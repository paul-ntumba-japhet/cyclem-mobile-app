import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import '../../extensions/animated_list/animated_list_view.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../model/common/article_models/article_list_model.dart';
import '../../model/common/article_models/article_model.dart';
import '../../network/rest_api.dart';
import '../../utils/utils.dart';
import '../user/blog_detail_screen.dart';
import 'edit_blog_screen.dart';

class DoctorBlogScreen extends StatefulWidget {
  String? flow;
  final bool isFromTabs;

  DoctorBlogScreen({super.key, required this.isFromTabs, this.flow});

  @override
  State<DoctorBlogScreen> createState() => _DoctorBlogScreenState();
}

class _DoctorBlogScreenState extends State<DoctorBlogScreen> {
  List<Article>? mArticleList = [];
  List<Article>? filteredArticleList = [];
  TextEditingController mSearchCont = TextEditingController();
  FocusNode search = FocusNode();
  bool isInitialLoading = true;
  bool isLoadingMore = false;
  bool isUpdatingBookmark = false;
  String? mSearchValue = '';
  int currentPage = 1;
  bool hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    getArticleList(page: 1);
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
        hasMorePages) {
      getArticleList(page: currentPage + 1);
    }
  }

  Future<void> getArticleList({int? page}) async {
    page ??= 1;
    if (page == 1) {
      setState(() {
        isInitialLoading = true;
        mArticleList?.clear();
        filteredArticleList?.clear();
      });
    } else {
      setState(() {
        isLoadingMore = true;
      });
    }
    appStore.setLoading(true);

    try {
      ArticleList response =
          await getHealthExpertArticleListApi(page: page).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw 'Request timed out';
        },
      );
      if (mounted) {
        setState(() {
          if (response.status == 'true' && response.data != null) {
            if (page == 1) {
              mArticleList = response.data;
              filteredArticleList = mArticleList;
            } else {
              mArticleList?.addAll(response.data!);
              filteredArticleList = mArticleList;
            }
            currentPage = page!;
            hasMorePages = response.data!.isNotEmpty;
            if (mSearchValue != null && mSearchValue!.isNotEmpty) {
              searchBlogs(mSearchValue!);
            }
          } else {
            hasMorePages = false;
            if (page == 1) {
              mArticleList = [];
              filteredArticleList = [];
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (page == 1) {
            mArticleList = [];
            filteredArticleList = [];
          }
          hasMorePages = false;
        });
        toast('Failed to load articles: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isInitialLoading = false;
          isLoadingMore = false;
        });
      }
      appStore.setLoading(false);
    }
  }

  void searchBlogs(String query) {
    setState(() {
      mSearchValue = query.trim();
      if (mSearchValue!.isEmpty) {
        filteredArticleList = mArticleList;
      } else {
        filteredArticleList = mArticleList
            ?.where((article) =>
                article.name
                    ?.toLowerCase()
                    .contains(mSearchValue!.toLowerCase()) ??
                false)
            .toList();
      }
    });
  }

  String formatDate(String dateString) {
    DateTime dateTime = DateTime.parse(dateString);
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  Future<bool> deleteArticle(int id) async {
    try {
      await deleteArticleDataApi(id);
      return true;
    } catch (e) {
      toast('Error deleting article: $e');
      return false;
    }
  }

  Future<void> updateBookmarkStatusApiCall(int index) async {
    if (filteredArticleList![index].id == null) {
      toast("Invalid article ID");
      return;
    }
    bool newBookmarkStatus = filteredArticleList![index].bookmark != 1;
    Map req = {
      "is_bookmark": newBookmarkStatus ? "1" : "0",
      "article_id": filteredArticleList![index].id.toString(),
    };
    setState(() {
      isUpdatingBookmark = true;
    });
    try {
      var value = await updateBookMarkStatus(req);
      if (mounted) {
        setState(() {
          filteredArticleList![index].bookmark = newBookmarkStatus ? 1 : 0;
          int originalIndex = mArticleList!.indexWhere(
              (article) => article.id == filteredArticleList![index].id);
          if (originalIndex != -1) {
            mArticleList![originalIndex].bookmark = newBookmarkStatus ? 1 : 0;
          }
        });
        toast(value.message);
      }
    } catch (e) {
      toast("Error updating bookmark");
    } finally {
      setState(() {
        isUpdatingBookmark = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.flow == "mainScreen") {
          Navigator.pop(context);
          return true;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add, color: Colors.white, size: 30),
          backgroundColor: primaryColor,
          onPressed: () async {
            var result = await EditBlogScreen().launch(context);
            if (result == true) {
              getArticleList(page: 1);
            }
          },
        ),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              backgroundColor: mainColorLight,
              pinned: true,
              automaticallyImplyLeading: false,
              leading: widget.isFromTabs
                  ? null
                  : IconButton(
                      icon: Icon(CupertinoIcons.back, color: mainColorText),
                      onPressed: () => pop(),
                    ),
              titleSpacing: 0,
              title: Padding(
                padding: EdgeInsets.only(left: widget.isFromTabs ? 16 : 0),
                child: Text(
                  language.yourBlog,
                  style: boldTextStyle(
                    color: mainColorText,
                    size: 18,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              expandedHeight: 0,
              elevation: 0,
              surfaceTintColor: mainColorLight,
              forceElevated: true,
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                [
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          20.height,
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            decoration: boxDecorationWithRoundedCorners(
                              borderRadius: radius(10),
                              backgroundColor: Colors.white,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(ic_magnifer, height: 30, width: 20),
                                10.width,
                                AppTextField(
                                  focus: search,
                                  controller: mSearchCont,
                                  textStyle: primaryTextStyle(),
                                  textFieldType: TextFieldType.OTHER,
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.all(0),
                                    border: InputBorder.none,
                                    hintText: language.SearchBlog,
                                    hintStyle: primaryTextStyle(
                                      color: grey,
                                      size: textFontSize_12,
                                    ),
                                  ),
                                  onFieldSubmitted: (v) {
                                    searchBlogs(v);
                                  },
                                  onChanged: (v) {
                                    searchBlogs(v);
                                  },
                                ).expand(),
                              ],
                            ),
                          ).paddingSymmetric(horizontal: 16),
                          10.height,
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              children: [
                                WidgetSpan(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Icon(Icons.arrow_back,
                                        size: 16, color: Colors.blue),
                                  ),
                                ),
                                TextSpan(
                                  text: language.SwipeLeftToEdit,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12),
                                ),
                                TextSpan(text: "   |   "),
                                WidgetSpan(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Icon(Icons.arrow_forward,
                                        size: 16, color: Colors.red),
                                  ),
                                ),
                                TextSpan(
                                  text: language.SwipeRightToDelete,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ).paddingSymmetric(horizontal: 16),
                          10.height,
                          Observer(
                            builder: (context) {
                              if (isInitialLoading && appStore.isLoading) {
                                return SizedBox(
                                  height: context.height() * 0.55,
                                  child: Loader().center(),
                                );
                              }
                              if (filteredArticleList != null &&
                                  filteredArticleList!.isNotEmpty) {
                                return Column(
                                  children: [
                                    AnimatedListView(
                                      padding: EdgeInsets.zero,
                                      primary: false,
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: filteredArticleList!.length,
                                      itemBuilder: (context, index) {
                                        return Slidable(
                                          closeOnScroll: true,
                                          key: ValueKey(
                                              filteredArticleList![index].id),
                                          startActionPane: ActionPane(
                                            motion: BehindMotion(),
                                            children: [
                                              Container(
                                                alignment: Alignment.center,
                                                decoration:
                                                    boxDecorationWithRoundedCorners(
                                                        backgroundColor:
                                                            Colors.blue),
                                                child: Icon(Icons.edit,
                                                    color: Colors.white),
                                              ).onTap(() async {
                                                final slidableState =
                                                    Slidable.of(context);
                                                slidableState?.close();
                                                bool? confirmEdit =
                                                    await showConfirmDialogCustom(
                                                  context,
                                                  image: ic_edit_profile,
                                                  title: language.editBlog,
                                                  primaryColor: primaryColor,
                                                  positiveText: language.edit,
                                                  negativeText: language.cancel,
                                                  onAccept: (BuildContext) {},
                                                );
                                                if (confirmEdit == true) {
                                                  var result =
                                                      await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          EditBlogScreen(
                                                        article:
                                                            filteredArticleList![
                                                                index],
                                                      ),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    getArticleList(page: 1);
                                                  }
                                                }
                                              }).expand(),
                                            ],
                                          ),
                                          endActionPane: ActionPane(
                                            motion: BehindMotion(),
                                            children: [
                                              Container(
                                                alignment: Alignment.center,
                                                decoration:
                                                    boxDecorationWithRoundedCorners(
                                                        backgroundColor:
                                                            Colors.red),
                                                child: Icon(Icons.delete,
                                                    color: Colors.white),
                                              ).onTap(() async {
                                                final slidableState =
                                                    Slidable.of(context);
                                                slidableState?.close();
                                                showConfirmDialogCustom(
                                                  image: ic_delete_ac,
                                                  context,
                                                  title:
                                                      language.deleteThisBlog,
                                                  primaryColor: primaryColor,
                                                  positiveText: language.delete,
                                                  negativeText: language.cancel,
                                                  onAccept: (c) async {
                                                    bool deleted =
                                                        await deleteArticle(
                                                            filteredArticleList![
                                                                    index]
                                                                .id!
                                                                .toInt());
                                                    if (deleted && mounted) {
                                                      setState(() {
                                                        filteredArticleList!
                                                            .removeAt(index);
                                                        mArticleList!.removeWhere(
                                                            (article) =>
                                                                article.id ==
                                                                filteredArticleList![
                                                                        index]
                                                                    .id);
                                                      });
                                                    }
                                                  },
                                                );
                                              }).expand(),
                                            ],
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      defaultRadius),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                cachedImage(
                                                  filteredArticleList![index]
                                                          .articleImage ??
                                                      'assets/images/placeholder.png',
                                                  height: 100,
                                                  width: 100,
                                                  fit: BoxFit.cover,
                                                ).cornerRadiusWithClipRRect(12),
                                                10.width,
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          filteredArticleList![
                                                                  index]
                                                              .name
                                                              .toString(),
                                                          style: boldTextStyle(
                                                            weight:
                                                                FontWeight.w500,
                                                            size:
                                                                textFontSize_14,
                                                            isHeader: true,
                                                            color:
                                                                mainColorText,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ).expand(),
                                                        Container(
                                                          height: 40,
                                                          width: 40,
                                                          decoration: BoxDecoration(
                                                              color:
                                                                  kPrimaryColor,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20)),
                                                          child: Image.asset(
                                                            filteredArticleList![
                                                                            index]
                                                                        .bookmark ==
                                                                    1
                                                                ? ic_bookmark_filled
                                                                : ic_bookmark2,
                                                            width: 18,
                                                            height: 18,
                                                            fit: BoxFit.contain,
                                                          ).center(),
                                                        ).onTap(() async {
                                                          await updateBookmarkStatusApiCall(
                                                              index);
                                                        }),
                                                      ],
                                                    ),
                                                    10.height,
                                                    Row(
                                                      children: [
                                                        Image.asset(ic_user,
                                                            width: 16,
                                                            height: 16,
                                                            color:
                                                                mainColorText),
                                                        4.width,
                                                        Text(
                                                          filteredArticleList![
                                                                      index]
                                                                  .expertData
                                                                  ?.name
                                                                  .toString() ??
                                                              language.Unknown,
                                                          style: primaryTextStyle(
                                                              color:
                                                                  mainColorText,
                                                              size:
                                                                  textFontSize_12),
                                                        ),
                                                      ],
                                                    ),
                                                    10.height,
                                                    Row(
                                                      children: [
                                                        Image.asset(ic_clock2,
                                                            width: 16,
                                                            height: 16,
                                                            color:
                                                                mainColorText),
                                                        4.width,
                                                        Text(
                                                          "${language.publishedDate} : ${formatDate(filteredArticleList![index].createdAt.toString())}",
                                                          style: primaryTextStyle(
                                                              color:
                                                                  mainColorText,
                                                              size:
                                                                  textFontSize_12),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ).expand(),
                                              ],
                                            ),
                                          ).onTap(() async {
                                            await BlogDetailScreen(
                                              article:
                                                  filteredArticleList![index],
                                              onBookmarkUpdated:
                                                  (updatedArticle) {
                                                if (mounted) {
                                                  setState(() {
                                                    filteredArticleList![index]
                                                            .bookmark =
                                                        updatedArticle.bookmark;
                                                    int originalIndex = mArticleList!
                                                        .indexWhere((article) =>
                                                            article.id ==
                                                            filteredArticleList![
                                                                    index]
                                                                .id);
                                                    if (originalIndex != -1) {
                                                      mArticleList![
                                                                  originalIndex]
                                                              .bookmark =
                                                          updatedArticle
                                                              .bookmark;
                                                    }
                                                  });
                                                }
                                              },
                                            ).launch(context);
                                          }),
                                        ).paddingSymmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        );
                                      },
                                    ),
                                    if (isLoadingMore) Loader().paddingAll(16)
                                  ],
                                ).paddingBottom(16);
                              }
                              return SizedBox(
                                height: context.height() * 0.55,
                                child: emptyWidget().center(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
