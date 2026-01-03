import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quill_html_editor/quill_html_editor.dart';

class HtmlEditScreen extends StatefulWidget {
  final String field;
  final String content;
  final Function(String) onUpdate;

  HtmlEditScreen({
    required this.field,
    required this.content,
    required this.onUpdate,
  });

  @override
  _HtmlEditScreenState createState() => _HtmlEditScreenState();
}

class _HtmlEditScreenState extends State<HtmlEditScreen> {
  final QuillEditorController editorController = QuillEditorController();
  bool isEditorLoaded = false;

  @override
  void initState() {
    super.initState();
    editorController.setText(widget.content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Fixed AppBar
          Container(
            color: Color(0xFFFCE4EC),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(CupertinoIcons.back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    widget.field,
                    style: boldTextStyle(
                      color: Colors.black,
                      size: 18,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    String updatedContent = await editorController.getText();
                    widget.onUpdate(updatedContent);
                    Navigator.pop(context);
                  },
                  child: Text(
                    language.Done,
                    style: boldTextStyle(
                      color: Color(0xFFF06292),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Fixed Toolbar
          Container(
            color: Color(0xFFFCE4EC),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(12),
                right: Radius.circular(12),
              ),
              child: Container(
                color: Colors.white, // White background for toolbar
                padding: EdgeInsets.symmetric(vertical: 4),
                child: ToolBar(
                  iconSize: 20,
                  activeIconColor: primaryColor,
                  controller: editorController,
                  toolBarConfig: [
                    ToolBarStyle.bold,
                    ToolBarStyle.italic,
                    ToolBarStyle.underline,
                    ToolBarStyle.strike,
                    ToolBarStyle.listBullet,
                    ToolBarStyle.listOrdered,
                    ToolBarStyle.align,
                    ToolBarStyle.link,
                    ToolBarStyle.image,
                    ToolBarStyle.undo,
                    ToolBarStyle.redo,
                  ],
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  spacing: 4.0,
                  runSpacing: 4.0,
                ),
              ),
            ),
          ),
          // Scrollable Editor Area
          CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(
                        Radius.circular(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: QuillHtmlEditor(
                      text: widget.content,
                      controller: editorController,
                      isEnabled: true,
                      minHeight: context.height(),
                      hintText: language.TypeYourBlogDescriptionHere,
                      hintTextStyle: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 16,
                      ),
                      hintTextAlign: TextAlign.start,
                      hintTextPadding: EdgeInsets.only(left: 16, top: 16),
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.all(8),
                    ),
                  ),
                ]),
              ),
            ],
          ).expand()
        ],
      ),
    );
  }
}
