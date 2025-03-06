import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:http/http.dart';
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

Future log_message(int conversationId, String senderType, int code, String content) async {
  String url = 'http://192.168.1.241:5001/log_message';
  Map<String, dynamic> data = {
    'conversation_id': conversationId,
    'sender_type': senderType,
    'code': code,
    'content': content,
  };

  Response response = await post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(data),
  );

  if (response.statusCode == 200) {
    return response.body;
  } else {
    print(response.body);
    print(response.statusCode);
    throw Exception('Failed to send data');
  }
}


class StoryDetails extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final Function(String, String, String) onResponse; // Modify the callback function to accept three parameters
  final String model;
  final String taskType;
  List<String> models = ['gpt', 'llama'];
  List<String> taskTypes = ['story-generation', 'prompt-generation'];
  StoryDetails({required this.onSubmit, required this.model, required this.taskType, required this.onResponse}) {
    if (!models.contains(model)) {
      throw ArgumentError('Invalid model: $model. Valid models are: ${models.join(', ')}');
    }
    if (!taskTypes.contains(taskType)) {
      throw ArgumentError('Invalid task type: $taskType. Valid task types are: ${taskTypes.join(', ')}');
    }
  }

  @override
  _StoryDetailsState createState() => _StoryDetailsState();
}

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

  void _handleSubmit(String model, String taskType) async {
    setState(() {
      _submittedData = {
        'title': _titleController.text,
        'prompt': _promptController.text,
        'vocabulary': _vocabularyController.text,
      };
    });

    StoryRequest storyRequest = StoryRequest.fromJson(_submittedData);
    print("Using model: $model");
    print("Using task type: $taskType");
    if (model == 'llama') {
      WidgetsFlutterBinding.ensureInitialized();
      final hfKey = await _loadApiKeyFromConfigFile('tokens.json', 'hf_token');

      final openai = OpenAI(baseURL: 'https://zq0finoawyna397e.us-east-1.aws.endpoints.huggingface.cloud/v1/chat', apiKey: hfKey); // Replace with your actual key

      final response = await openai.chatCompletionsCreate({
        "model": "tgi",
        "messages": [
          {"role": "user", "content": storyRequest.formatStoryRequest(taskType)}
        ],
        'max_tokens': 150,
        'stream': false
      });

      // Process the response (assuming it's a stream-like structure)
      // the response should be sent to the storyDetailsForm.dart class build widget for inclusion in textbox
      if (taskType == 'story-generation') {
        widget.onResponse(response['choices'][0]['message']['content'], storyRequest.formatStoryRequest(taskType), '');
      } else if (taskType == 'prompt-generation') {
        widget.onResponse('', storyRequest.formatStoryRequest(taskType), response['choices'][0]['message']['content']);
      }

      var data = await log_message(1, 'USER', 1, storyRequest.formatStoryRequest(taskType));
      var decodedData = jsonDecode(data);
      print('data: $decodedData');
      print('response: $response');
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
          {"role": "user", "content": storyRequest.formatStoryRequest(taskType)}
        ],
        'max_tokens': 150,
        'stream': false
      });
      // Process the response (assuming it's a stream-like structure)
      // the response should be sent to the storyDetailsForm.dart class build widget for inclusion in textbox
      if (taskType == 'story-generation') {
        widget.onResponse(response['choices'][0]['message']['content'], storyRequest.formatStoryRequest(taskType), '');
      } else if (taskType == 'prompt-generation') {
        widget.onResponse('', storyRequest.formatStoryRequest(taskType), response['choices'][0]['message']['content']);
      }

      var data = await log_message(1, 'USER', 1, storyRequest.formatStoryRequest(taskType));
      var decodedData = jsonDecode(data);
      print('data: $decodedData');
      print('response: $response');
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
        const SizedBox(height: 20),
        TextField(
          controller: _promptController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'What do you want this story to be?',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _vocabularyController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'What are some vocabulary words related to your story?',
          ),
        ),
        SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () => _handleSubmit(widget.model, widget.taskType),
          child: Text('Submit'),
        )
      ],
    );
  }
}