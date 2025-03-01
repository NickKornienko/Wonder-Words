import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonder_words_flutter_application/storyDetailsForm.dart';

Future<String> _loadApiKeyFromConfigFile(String configFileName) async {
  try {
    // using rootBundle to access the config file
    final content = await rootBundle.loadString('tokens/hf_token.json');
    final jsonObject = jsonDecode(content);
    return jsonObject["hf_token"];
  } catch (e) {
    throw Exception('Error reading API key from file: $e');
  }
}

void main() async {
  runApp(StoryDetailsForm());

}