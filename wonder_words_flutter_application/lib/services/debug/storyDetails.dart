import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wonder_words_flutter_application/services/debug/storyInference.dart';
import 'package:wonder_words_flutter_application/services/debug/storyRequest.dart';
import 'package:wonder_words_flutter_application/services/story_service.dart';

String configFileName = 'ip_address.json';
String tokenKey = 'device_ip';
Future<String> deviceIP = _loadKeyFromConfigFile(configFileName, tokenKey);
final StoryService _storyService = StoryService();
bool _needsConfirmation = false;

Future<String> _loadKeyFromConfigFile(String configFileName, String tokenKey) async {
  try {
    // using rootBundle to access the config file
    final content = await rootBundle.loadString('secrets/$configFileName');
    final jsonObject = jsonDecode(content);
    print(jsonObject);
    return jsonObject[tokenKey];
  } catch (e) {
    throw Exception('Error reading API key from file: $e');
  }
}


class StoryDetails extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final Function(String, String, String) onResponse; // Modify the callback function to accept three parameters
  final String model;
  final String taskType;
  List<String> models = ['gpt', 'llama'];
  List<String> taskTypes = ['story-generation', 'prompt-generation', 'story-continuation'];
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
  int? conversationId;
  bool pendingConfirmation = false;
  String lastUserInput = "";
  bool isNewStory = true;

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

    if (!isNewStory && taskType == 'story-generation') {
      taskType = 'story-continuation';
    }

    if (model == 'llama') {
      WidgetsFlutterBinding.ensureInitialized();
      final hfKey = await _loadKeyFromConfigFile('tokens.json', 'hf_token');

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
        widget.onResponse(response['choices'][0]['message']['content'], '', '');
      } else if (taskType == 'prompt-generation') {
        widget.onResponse('', storyRequest.formatStoryRequest(taskType), response['choices'][0]['message']['content']);
      }
      
    }

    if (model == 'gpt') {
      final response = await _sendGptRequest(storyRequest.formatStoryRequest(taskType));

      if (response != null) {
        print(response);
        if (response.containsKey('confirmation')) {
          print('confirmation expected');
          setState(() {
            lastUserInput = storyRequest.formatStoryRequest(taskType);
            pendingConfirmation = true;
          });
        } else {
          print('In else');
          if (taskType == 'story-generation' || taskType == 'story-continuation') {
            widget.onResponse(response['response'], '', '');
          } else if (taskType == 'prompt-generation') {
            widget.onResponse('', storyRequest.formatStoryRequest(taskType), response['choices'][0]['message']['content']);
          } else {
            // handle the prompt generation task with the gpt model
            widget.onResponse('', storyRequest.formatStoryRequest(taskType), response['choices'][0]['message']['content']);
          }
        } 
      } else {
        print('Error: No response data received. The server might have encountered an error.');
      }
    }
  }


  Future<Map<String, dynamic>?> _sendGptRequest(String userInput) async {
    String ip = await deviceIP;
    String url = 'http://$ip:5000/handle_request';
    final String idToken = await _storyService.getIdToken();
    print('Sending GPT request to $url');

    //set last user input to the current user input
    setState(() {
      lastUserInput = userInput;
    });
  
    Map<String, dynamic> data = {
      'query': userInput,
      'user_id': 'test_user',
      if (conversationId != null) 'conversation_id': conversationId,
    };

    http.Response response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Failed to get response from GPT API');
      print(response.body);
      print(response.statusCode);
      return null;
    }
    
  }

  Future<Map<String, dynamic>?> _sendConfirmation(String confirmation) async {
    String ip = await deviceIP;
    String url = 'http://$ip:5000/confirm_new_story';
    final String idToken = await _storyService.getIdToken();
    print('Sending confirmation to $url');

    Map<String, dynamic> data = {
      'query': lastUserInput,
      'user_id': 'test_user',
      'confirmation': confirmation,
      if (conversationId != null) 'conversation_id': conversationId,
    };

    http.Response response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Failed to get confirmation response from GPT API');
      print(response.body);
      print(response.statusCode);
      return null;
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
        const SizedBox(height: 20),
        if (lastUserInput.isNotEmpty) // Only show the checkbox if lastUserInput is non-empty
          CheckboxListTile(
            title: Text('Is this a new story?'),
            value: isNewStory,
            onChanged: (bool? value) {
              setState(() {
                isNewStory = value ?? false;
              });
            },
          ),
        SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () async {

            // if the user is confirming a new story and the last user input is not empty
            if (isNewStory) {
              // calling handleSubmit function to log the user input
              _handleSubmit(widget.model, widget.taskType);
              print('Submitted user input');
              print('new story request');
              print('Last user input: $lastUserInput');
              final confirmResponse = await _sendConfirmation('y');
              if (confirmResponse != null) {
                setState(() {
                  conversationId = confirmResponse['conversation_id'] as int?;
                  pendingConfirmation = false;
                });
                // if the taskType is 'story-generation' or 'story-continuation'
                if (widget.taskType == 'story-generation' || widget.taskType == 'story-continuation') {
                  // send the response to the storyDetailsForm.dart class build widget for inclusion in textbox
                  widget.onResponse(confirmResponse['response'] ?? '', '', '');
                } else if (widget.taskType == 'prompt-generation') {
                  // send the response to the storyDetailsForm.dart class build widget for inclusion in textbox
                  widget.onResponse('', lastUserInput, confirmResponse['response'] ?? '');
                } 
              }
            } 
            if (!isNewStory) {
              // if this is not the first story and is continuation of a story
              // send the message as usual with confirmation set to 'n'
              //final response = await _sendConfirmation('y');
              //if (response != null) {
              //  setState(() {
              //    conversationId = response['conversation_id'] as int?;
              //    pendingConfirmation = false;
              //  });
              //  widget.onResponse(response['response'] ?? '', '', '');
              print('continued story request');
              print('Last user input: $lastUserInput');
              _handleSubmit(widget.model, widget.taskType);
              // }
            }
            
          },
          child: Text('Submit'),
        )
      ],
    );
  }
}