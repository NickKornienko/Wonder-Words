import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonder_words_flutter_application/storyInference.dart';
import 'package:wonder_words_flutter_application/storyRequest.dart';

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

class StoryDetails extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final String model;
  List<String> models = ['gpt', 'llama'];
  StoryDetails({required this.onSubmit, required this.model}) {
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
    if (model == 'llama') {
      WidgetsFlutterBinding.ensureInitialized();
      final hfKey = await _loadApiKeyFromConfigFile('hf_token.json');

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
      print(response);
      // else if model == 'gpt':
      // to-do: call the gpt API
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
          onPressed: () => _handleSubmit('llama'),
          child: Text('Submit'),
        )
      ],
    );
  }
}