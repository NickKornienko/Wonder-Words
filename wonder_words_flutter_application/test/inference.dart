import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonder_words_flutter_application/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';


class StoryResponse {
  final int userId;
  final int id;
  final String title;

  const StoryResponse({required this.userId, required this.id, required this.title});

  factory StoryResponse.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'userId': int userId, 'id': int id, 'title': String title} => StoryResponse(
        userId: userId,
        id: id,
        title: title,
      ),
      _ => throw const FormatException('Failed to load album.'),
    };
  }
}

String _loadApiKeyFromConfigFile(String configFileName) {
    try {
      final file = File(join(Directory.current.path, configFileName));
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final jsonObject = jsonDecode(content);
        return jsonObject["hf_token"]; 
      } else {
        throw Exception('Configuration file "hf_token.json" not found!');
      }
    } catch (e) {
      throw Exception('Error reading API key from file: $e');
    }
  }

class OpenAI {
  final String baseURL;
  final String apiKey;

  OpenAI({required this.baseURL, required this.apiKey});

  Future<dynamic> chatCompletionsCreate(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseURL/completions'), headers: {'Authorization': 'Bearer $apiKey'}, body: jsonEncode(body));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create completions');
    }
  }
}

String apiKey= _loadApiKeyFromConfigFile('hf_token.json');
void main() async {
  final openai = OpenAI(baseURL: 'https://zq0finoawyna397e.us-east-1.aws.endpoints.huggingface.cloud/v1/', apiKey: apiKey); // Replace with your actual key

  final response = await openai.chatCompletionsCreate({
    'model': 'tgi',
    'messages': [
      {'role': 'user', 'content': 'Hi!'}
    ],
    'max_tokens': 150,
    'stream': true // Note: Stream handling is simplified here for brevity.  
  });

  // Process the response (assuming it's a stream-like structure)
  for (var chunk in response) {
    log(chunk['choices'][0]['delta']['content'] ?? ''); 
  }


}
