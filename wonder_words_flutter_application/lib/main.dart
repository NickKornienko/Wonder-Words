import 'package:flutter/material.dart';
import 'package:wonder_words_flutter_application/inference.dart';
import 'dart:io';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('My App'),
        ),
        body: Center(
          child: Text('Hello, world!'),
        ),
      ),
    );
  }
}

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
  runApp(MyApp());

  WidgetsFlutterBinding.ensureInitialized();
  //Future<String> apiKey= _loadApiKeyFromConfigFile('hf_token.json');
  final hfKey = await _loadApiKeyFromConfigFile('hf_token.json');

  final openai = OpenAI(baseURL: 'https://zq0finoawyna397e.us-east-1.aws.endpoints.huggingface.cloud/v1/chat', apiKey: hfKey); // Replace with your actual key

  final response = await openai.chatCompletionsCreate({
    "model": "tgi",
    "messages": [
      {"role": "user", "content": "Hi!"}
    ],
    'max_tokens': 150,
    'stream': false
  });

  // Process the response (assuming it's a stream-like structure)
  print(response);

}