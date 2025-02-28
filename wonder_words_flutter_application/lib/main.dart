import 'package:flutter/material.dart';
import 'services/story_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wonder Words',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StorytellingScreen(),
    );
  }
}

class StorytellingScreen extends StatefulWidget {
  const StorytellingScreen({super.key});

  @override
  State<StorytellingScreen> createState() => _StorytellingScreenState();
}

class _StorytellingScreenState extends State<StorytellingScreen> {
  final TextEditingController _promptController = TextEditingController();
  final StoryService _storyService = StoryService();
  final String _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
  String? _conversationId;
  bool _isLoading = false;
  bool _needsConfirmation = false;
  String _pendingQuery = '';
  
  final List<Message> _messages = [
    Message(
      content: 'Welcome to Wonder Words! Ask me to tell you a story.',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_promptController.text.trim().isEmpty) return;

    final userMessage = _promptController.text.trim();
    setState(() {
      _messages.add(Message(content: userMessage, isUser: true));
      _isLoading = true;
      _promptController.clear();
    });

    try {
      if (_needsConfirmation) {
        // Handle confirmation for new story when there's an existing conversation
        _handleConfirmation(userMessage);
      } else {
        // Normal message handling
        await _handleNormalMessage(userMessage);
      }
    } catch (e) {
      setState(() {
        _messages.add(Message(
          content: 'Error: ${e.toString()}',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  Future<void> _handleNormalMessage(String userMessage) async {
    Map<String, dynamic> response;
    
    if (_conversationId == null) {
      // New conversation
      response = await _storyService.getNewStory(userMessage, _userId);
    } else {
      // Existing conversation
      response = await _storyService.addToStory(
        userMessage, 
        _userId, 
        _conversationId!
      );
    }

    setState(() {
      _isLoading = false;
      
      // Check if we need confirmation for a new story
      if (response.containsKey('confirmation')) {
        _messages.add(Message(
          content: response['confirmation'],
          isUser: false,
        ));
        _needsConfirmation = true;
        _pendingQuery = userMessage;
        _conversationId = response['conversation_id'].toString();
      } else {
        // Normal response
        _messages.add(Message(
          content: response['response'] ?? response['message'] ?? 'No response',
          isUser: false,
        ));
        _conversationId = response['conversation_id'];
      }
    });
  }

  Future<void> _handleConfirmation(String userInput) async {
    final lowerInput = userInput.toLowerCase();
    String confirmation;
    
    if (lowerInput.contains('yes') || lowerInput.contains('y')) {
      confirmation = 'y';
    } else if (lowerInput.contains('no') || lowerInput.contains('n')) {
      confirmation = 'n';
    } else {
      setState(() {
        _messages.add(Message(
          content: 'Please respond with "yes" or "no".',
          isUser: false,
        ));
        _isLoading = false;
      });
      return;
    }

    final response = await _storyService.confirmNewStory(
      _pendingQuery, 
      _userId, 
      _conversationId!, 
      confirmation
    );

    setState(() {
      _isLoading = false;
      _needsConfirmation = false;
      _pendingQuery = '';
      
      if (confirmation == 'y') {
        _messages.add(Message(
          content: response['response'] ?? 'New story created',
          isUser: false,
        ));
        _conversationId = response['conversation_id'];
      } else {
        _messages.add(Message(
          content: 'New story request canceled.',
          isUser: false,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Wonder Words Storytelling'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  // Show loading indicator
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                final message = _messages[index];
                return MessageBubble(message: message);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: 'Ask for a story...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String content;
  final bool isUser;

  Message({required this.content, required this.isUser});
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
