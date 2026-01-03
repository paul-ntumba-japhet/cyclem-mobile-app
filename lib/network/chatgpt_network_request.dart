import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../model/user/chatgpt_insight_model.dart';

class ChatGptService {
  static final String? _apiKey = "$chatgptKey";
  static const String _endpoint = "https://api.openai.com/v1/chat/completions";

  static Future<ChatGptInsight> getCycleDayInfo(
      int day, int cycleLength, int periodLength, String lang) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "user",
            "content": _buildPrompt(day, cycleLength, periodLength, lang)
          }
        ],
        "temperature": 0.7
      }),
    );

    if (response.statusCode == 200) {
      final utf8Response = utf8.decode(response.bodyBytes);
      try {
        final responseJson = jsonDecode(utf8Response) as Map<String, dynamic>;
        final content =
            responseJson['choices'][0]['message']['content'] as String;
        final contentJson = jsonDecode(content) as Map<String, dynamic>;
        return ChatGptInsight.fromJson(contentJson);
      } catch (e) {
        throw Exception('Failed to parse API response: $e');
      }
    } else {
      throw Exception(
          'Failed to load data: ${response.body}, API KEY => ${_apiKey}');
    }
  }

  static String _buildPrompt(
      int day, int cycleLength, int periodLength, String language) {
    return """
Provide detailed information about day $day of the 
menstrual cycle  with cycle length of $cycleLength days 
with $periodLength days of  periods in JSON format with these exact keys in $language language:
{
  "overview": "Brief overview of this cycle day",
  "status": "Brief status",
  "hormones": {
    "estrogen": "Details about estrogen levels",
    "progesterone": "Details about progesterone levels"
  },
  "health_tips": ["Array", "of", "health", "tips"],
  "nutrition": ["Array", "of", "nutrition", "tips"],
  "physical_symptoms": ["Array", "of", "symptoms"],
  "mood_changes": ["Array", "of", "mood", "changes"],
  "exercise": ["Array", "of", "exercise", "recommendations"],
  "self_care": ["Array", "of", "self-care", "tips"]
  "skin": ["Array", "of", "skin", "tips"]
  "hydration": ["Array", "of", "hydration", "tips"]
  "energy": ["Array", "of", "energy booster", "tips"]
  "motivation": ["Array", "of", "motivational", "tips"]
  "fitness": ["Array", "of", "fitness", "tips"]
  "social": ["Array", "of", "social", "tips"]
  "calm": ["Array", "of", "calm", "tips"]
  "sleep": ["Array", "of", "sleeping", "tips"]
}

Important:
1. Keep responses medically accurate
2. Format must be valid JSON
3. Each array should contain 3-5 items
4. Use simple language understandable to non-experts
""";
  }

  static Future<ChatGptInsight> getPregnancyWeekInfo(
      int week, String lang) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": _buildPregnancyPrompt(week, lang)}
        ],
        "temperature": 0.7
      }),
    );

    if (response.statusCode == 200) {
      final utf8Response = utf8.decode(response.bodyBytes);
      try {
        final responseJson = jsonDecode(utf8Response) as Map<String, dynamic>;
        final content =
            responseJson['choices'][0]['message']['content'] as String;
        final contentJson = jsonDecode(content) as Map<String, dynamic>;
        return ChatGptInsight.fromJson(contentJson);
      } catch (e) {
        throw Exception('Failed to parse API response: $e');
      }
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  static String _buildPregnancyPrompt(int week, String language) {
    return """
Provide detailed information about week $week of pregnancy in JSON format with these exact keys in $language language:
{
  "pregnancy_checklist": ["Array", "of", "checklist", "items"],
  "pregnancy_symptoms": ["Array", "of", "symptoms"],
  "mass_of_baby": "Description of baby's size and weight",
  "baby_growth": "Detailed description of baby's growth",
  "highlights_of_week": ["Array", "of", "key", "highlights"]
}

Important:
1. Keep responses medically accurate
2. Format must be valid JSON
3. Each array should contain 3-5 items
4. Use simple language understandable to non-experts
5. Size & weight should be in both metric and imperial units
6. Baby growth should include developmental milestones
""";
  }
}
