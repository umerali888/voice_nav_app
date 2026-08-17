import 'dart:convert';
import 'package:http/http.dart' as http;

class AIResponse {
  final String replyText;
  final String? destination;

  AIResponse({required this.replyText, this.destination});
}

class AIService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static Future<AIResponse> processVoiceCommand(String userQuery) async {
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey');
      
      final prompt = '''
      You are a smart Pakistani navigation assistant. User query: "$userQuery".
      Provide a short, polite answer in Urdu script.
      If user mentions routes or locations (e.g. Chishtian, Gujranwala, Lahore), extract the target city name in English.
      Respond strictly in JSON:
      {
        "reply": "Urdu response",
        "destination": "City Name or null"
      }
      ''';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data['candidates'][0]['content']['parts'][0]['text'];
        rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
        final jsonResponse = jsonDecode(rawText);

        return AIResponse(
          replyText: jsonResponse['reply'] ?? "جی، میں آپ کی بات سمجھ گیا ہوں۔",
          destination: jsonResponse['destination'],
        );
      }
    } catch (e) {
      print("Error: $e");
    }

    return AIResponse(
      replyText: "معذرت، میں آپ کا راستہ تلاش نہیں کر سکا۔",
      destination: null,
    );
  }
}
