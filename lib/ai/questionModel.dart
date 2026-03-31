class Questionmodel {
  final String text;
  final String askAi;

  Questionmodel({required this.text, required this.askAi});
}

class QuestionAnswerModel {
  String? question;
  StringBuffer? answer;
  bool? isLoading;
  String? smartCompose;
  List<String>? smartReplies;

  QuestionAnswerModel({
    this.question,
    this.answer,
    this.isLoading,
    this.smartCompose,
    this.smartReplies,
  });
}
