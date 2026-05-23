import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../extensions/extensions.dart';
import '../../../extensions/new_colors.dart';
import '../../../main.dart';

class YesNoQuestionWidget extends StatefulWidget {
  final String question;
  final bool? initialAnswer;
  final Function(bool) onAnswerSelected;
  final Function()? onCompleted;
  /// When true, "No" uses green and "Yes" uses red (e.g. for "Are you breastfeeding?").
  final bool invertSelectionColor;
  /// When true, Yes/No answer icons are swapped (e.g. breastfeeding question).
  final bool swapAnswerIcons;

  const YesNoQuestionWidget({
    Key? key,
    required this.question,
    this.initialAnswer,
    required this.onAnswerSelected,
    this.onCompleted,
    this.invertSelectionColor = false,
    this.swapAnswerIcons = false,
  }) : super(key: key);

  @override
  State<YesNoQuestionWidget> createState() => _YesNoQuestionWidgetState();
}

class _YesNoQuestionWidgetState extends State<YesNoQuestionWidget> {
  bool? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = widget.initialAnswer;
  }

  void _selectAnswer(bool answer) {
    setState(() {
      _selectedAnswer = answer;
    });
    widget.onAnswerSelected(answer);
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        // Access appStore.selectedLanguage to ensure Observer tracks language changes
        appStore.selectedLanguage;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Text
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  widget.question,
                  style: boldTextStyle(
                    color: mainColorText,
                    weight: FontWeight.w500,
                    size: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              32.height,

              // Yes Button (green normally; red when inverted)
              _buildAnswerButton(
                text: language.yes,
                isSelected: _selectedAnswer == true,
                onTap: () => _selectAnswer(true),
                icon: widget.swapAnswerIcons
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
                color: widget.invertSelectionColor ? Colors.red : Colors.green,
              ),
              16.height,

              // No Button (red normally; green when inverted)
              _buildAnswerButton(
                text: language.no,
                isSelected: _selectedAnswer == false,
                onTap: () => _selectAnswer(false),
                icon: widget.swapAnswerIcons
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: widget.invertSelectionColor ? Colors.green : Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnswerButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: boxDecorationWithRoundedCorners(
          borderRadius: BorderRadius.circular(16),
          backgroundColor: isSelected
              ? color.withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? color : gray.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? color.withOpacity(0.2)
                    : gray.withOpacity(0.1),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : gray,
                size: 28,
              ),
            ),
            20.width,
            Expanded(
              child: Text(
                text,
                style: boldTextStyle(
                  size: 18,
                  color: isSelected ? color : mainColorText,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}

