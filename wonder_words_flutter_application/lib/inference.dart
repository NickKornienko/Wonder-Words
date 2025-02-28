import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonder_words_flutter_application/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';



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
      _ => throw const FormatException('Failed to load story.'),
    };
  }
}

class OpenAI {
  final String baseURL;
  final String apiKey;

  OpenAI({required this.baseURL, required this.apiKey});

  Future<dynamic> chatCompletionsCreate(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse("$baseURL/completions"), headers: {"Authorization": "Bearer $apiKey", "Content-Type":"application/json"}, body: jsonEncode(body));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
      // print response body and status code
    } else {
      throw Exception('Failed to load story. Status code: ${response.statusCode}. Response: ${response.body}');
      
    }
    

  }
}