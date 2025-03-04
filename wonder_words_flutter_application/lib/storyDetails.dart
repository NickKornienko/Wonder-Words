import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonder_words_flutter_application/storyInference.dart';
import 'package:wonder_words_flutter_application/storyRequest.dart';

Future<String> _loadApiKeyFromConfigFile(String configFileName, String tokenKey) async {
  try {
    // using rootBundle to access the config file
    final content = await rootBundle.loadString('tokens/$configFileName');
    final jsonObject = jsonDecode(content);
    return jsonObject[tokenKey];
  } catch (e) {
    throw Exception('Error reading API key from file: $e');
  }
}

class StoryDetails extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final Function(String) onResponse;
  final String model;
  List<String> models = ['gpt', 'llama'];
  StoryDetails({required this.onSubmit, required this.model, required this.onResponse}) {
    if (!models.contains(model)) {
      throw ArgumentError('Invalid model: $model. Valid models are: ${models.join(', ')}');
    }
  }

  @override
  _StoryDetailsState createState() => _StoryDetailsState();
}
//   to-do: final TextEditingController _idController = TextEditingController();
// to-do: final TextEditingController _userPromptController = TextEditingController();
class _StoryDetailsState extends State<StoryDetails> {
  final _formKey = GlobalKey<FormState>();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onSubmit(_submittedData);
    }
  }
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _vocabularyController = TextEditingController();
  Map<String, dynamic> _submittedData = {};
  StoryRequest? storyRequest;

// to-do: read from user db table 'userId': _userIdController.text to _handleSubmit / buildContext
// to-do: read  from a request db table 'id': _idController.text, to _handleSubmit/buildContext
// to-do: write to the training/RLHF db a 'userPrompt' from template for inference input based on the user's input to the buildContext controller text


  void _handleSubmit(String model) async {
    setState(() {
      _submittedData = {
        'title': _titleController.text,
        'prompt': _promptController.text,
        'vocabulary': _vocabularyController.text,
      };
    });
    StoryRequest storyRequest = StoryRequest.fromJson(_submittedData);
    print("Using model: $model");
    if (model == 'llama') {
      WidgetsFlutterBinding.ensureInitialized();
      final hfKey = await _loadApiKeyFromConfigFile('tokens.json', 'hf_token');

      final openai = OpenAI(baseURL: 'https://zq0finoawyna397e.us-east-1.aws.endpoints.huggingface.cloud/v1/chat', apiKey: hfKey); // Replace with your actual key

      final response = await openai.chatCompletionsCreate({
        "model": "tgi",
        "messages": [
          {"role": "user", "content": storyRequest.formatStoryRequest(model)}
        ],
        'max_tokens': 150,
        'stream': false
      });

      // Process the response (assuming it's a stream-like structure)
      // the response should be sent to the storyDetailsForm.dart class build widget for inclusion in textbox
      widget.onResponse(response['choices'][0]['message']['content']);
    }

    if (model == 'gpt') {
      // to-do: call the gpt API
      print('gpt model selected');
      WidgetsFlutterBinding.ensureInitialized();
      final openaiKey = await _loadApiKeyFromConfigFile('tokens.json', 'openai_token');

      final openai = OpenAI(baseURL: 'https://api.openai.com/v1/chat/', apiKey: openaiKey); // Replace with your actual key
      print(storyRequest.formatStoryRequest(model));
      final response = await openai.chatCompletionsCreate({
        "model": "gpt-4o-mini",
        "messages": [
          {"role": "user", "content": storyRequest.formatStoryRequest(model)}
        ],
        'max_tokens': 150,
        'stream': false
      });
      print(response['choices'][0]['message']['content']);
      // Process the response (assuming it's a stream-like structure)
      // the response should be sent to the storyDetailsForm.dart class build widget for inclusion in textbox
      widget.onResponse(response['choices'][0]['message']['content']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Whats the title of your new story?',
          ),
        ),
        TextField(
          controller: _promptController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'What do you want this story to be?',
          ),
        ),
        TextField(
          controller: _vocabularyController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'What are some vocabulary words related to your story?',
          ),
        ),
        SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () => _handleSubmit(widget.model),
          child: Text('Submit'),
        )
      ],
    );
  }
}