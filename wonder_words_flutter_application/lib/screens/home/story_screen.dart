import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/story_service.dart';
import 'story_history_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Message {
  final String content;
  final bool isUser;

  Message({required this.content, required this.isUser});
}

class StoryScreen extends StatefulWidget {
  const StoryScreen({Key? key}) : super(key: key);

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final TextEditingController _promptController = TextEditingController();
  final StoryService _storyService = StoryService();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();

  String? _conversationId;
  bool _isLoading = false;
  bool _needsConfirmation = false;
  bool _isSpeaking = false;
  String _pendingQuery = '';

  final List<Message> _messages = [
    Message(
      content: 'Welcome to Wonder Words! Ask me to tell you a story.',
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  String _selectedVoice = '';
  List<String> _availableVoices = [];

  Future<void> _initTts() async {
    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setErrorHandler((error) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    // Set language to English
    await _flutterTts.setLanguage("en-US");

    // Get available voices
    try {
      // First try to get all voices
      var voices = await _flutterTts.getVoices;
      List<String> voiceNames = [];

      if (voices != null) {
        for (var voice in voices) {
          if (voice is Map && voice.containsKey('name')) {
            voiceNames.add(voice['name']);
          }
        }
      }

      // Try to set language to get language-specific voices
      if (voiceNames.isEmpty) {
        await _flutterTts.setLanguage("en-US");
        // Wait a moment for language to be set
        await Future.delayed(const Duration(milliseconds: 100));
        // Try to get voices again
        voices = await _flutterTts.getVoices;
        if (voices != null) {
          for (var voice in voices) {
            if (voice is Map && voice.containsKey('name')) {
              voiceNames.add(voice['name']);
            }
          }
        }
      }

      // If still no voices, add some default voice names that might be available
      if (voiceNames.isEmpty) {
        voiceNames = [
          "Microsoft David - English (United States)",
          "Microsoft Zira - English (United States)",
          "Microsoft Mark - English (United States)",
          "Google US English",
          "Google UK English Female",
          "Google UK English Male",
          "en-US-language",
          "en-US-x-sfg#female_1-local",
          "en-US-x-sfg#male_1-local",
        ];
      }

      setState(() {
        _availableVoices = voiceNames;
        if (voiceNames.isNotEmpty) {
          _selectedVoice = voiceNames.first;
          _flutterTts.setVoice({"name": _selectedVoice});
        }
      });

      // Debug voice information
      print("Available voices: $_availableVoices");
      var engines = await _flutterTts.getEngines;
      print("Available engines: $engines");
    } catch (e) {
      print("Failed to get voices: $e");
    }

    // Set speech rate and pitch for better quality
    await _flutterTts.setSpeechRate(0.9); // More natural speech rate
    await _flutterTts.setPitch(1.0); // Normal pitch
    await _flutterTts.setVolume(1.0); // Full volume
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      if (_isSpeaking) {
        await _flutterTts.stop();
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      } else {
        await _flutterTts.speak(text);
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
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

    _scrollToBottom();

    try {
      if (_needsConfirmation) {
        // Handle confirmation for new story when there's an existing conversation
        await _handleConfirmation(userMessage);
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
      _scrollToBottom();
    }
  }

  Future<void> _handleNormalMessage(String userMessage) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userData?.uid ?? 'anonymous_user';

    Map<String, dynamic> response;

    if (_conversationId == null) {
      // New conversation
      response = await _storyService.getNewStory(userMessage, userId);
    } else {
      // Existing conversation
      response =
          await _storyService.addToStory(userMessage, userId, _conversationId!);
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
        final storyContent =
            response['response'] ?? response['message'] ?? 'No response';
        _messages.add(Message(
          content: storyContent,
          isUser: false,
        ));
        if (response['conversation_id'] != null) {
          _conversationId = response['conversation_id'].toString();
        }

        // Automatically speak the story
        _speak(storyContent);
      }
    });

    _scrollToBottom();
  }

  Future<void> _handleConfirmation(String userInput) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userData?.uid ?? 'anonymous_user';

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
      _scrollToBottom();
      return;
    }

    final response = await _storyService.confirmNewStory(
        _pendingQuery, userId, _conversationId!, confirmation);

    setState(() {
      _isLoading = false;
      _needsConfirmation = false;
      _pendingQuery = '';

      if (confirmation == 'y') {
        final storyContent = response['response'] ?? 'New story created';
        _messages.add(Message(
          content: storyContent,
          isUser: false,
        ));
        if (response['conversation_id'] != null) {
          _conversationId = response['conversation_id'].toString();
        }

        // Automatically speak the story
        _speak(storyContent);
      } else {
        _messages.add(Message(
          content: 'New story request canceled.',
          isUser: false,
        ));
      }
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showVoiceSelectionDialog() {
    if (_availableVoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No voices available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Voice'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableVoices.length,
            itemBuilder: (context, index) {
              final voice = _availableVoices[index];
              return RadioListTile<String>(
                title: Text(voice),
                value: voice,
                groupValue: _selectedVoice,
                onChanged: (value) async {
                  if (value != null) {
                    try {
                      // Try different ways to set the voice
                      await _flutterTts.setVoice({"name": value});

                      // Also try setting by language
                      await _flutterTts.setLanguage("en-US");

                      // Debug voice selection
                      print("Selected voice: $value");

                      // Speak a test phrase to confirm voice change
                      await _flutterTts.speak("Voice selected");

                      setState(() {
                        _selectedVoice = value;
                      });
                      Navigator.pop(context);
                    } catch (e) {
                      print("Error setting voice: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error setting voice: $e')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isChild = authProvider.isChild;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wonder Words'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            onPressed: _showVoiceSelectionDialog,
            tooltip: 'Select Voice',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StoryHistoryScreen(),
                ),
              );
            },
            tooltip: 'View Story History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(Message(
                  content:
                      'Welcome to Wonder Words! Ask me to tell you a story.',
                  isUser: false,
                ));
                _conversationId = null;
                _needsConfirmation = false;
                _pendingQuery = '';
              });
            },
            tooltip: 'Start New Conversation',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple[50]!,
              Colors.purple[100]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // Story suggestions for children
            if (isChild)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                color: Colors.white.withOpacity(0.7),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildSuggestionChip('Tell me a story about a dragon'),
                      _buildSuggestionChip('Tell me a fairy tale'),
                      _buildSuggestionChip('Tell me a space adventure'),
                      _buildSuggestionChip('Tell me a story about animals'),
                      _buildSuggestionChip('Tell me a funny story'),
                    ],
                  ),
                ),
              ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
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
                  return _buildMessageBubble(message);
                },
              ),
            ),

            // Input area
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      decoration: InputDecoration(
                        hintText: 'Ask for a story...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    heroTag: 'sendButton',
                    onPressed: _sendMessage,
                    backgroundColor: Colors.deepPurple,
                    child: const Icon(Icons.send),
                    mini: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ActionChip(
        label: Text(
          suggestion,
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: Colors.deepPurple[100],
        onPressed: () {
          _promptController.text = suggestion;
          _sendMessage();
        },
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            if (!message.isUser) // Only show speak button for AI messages
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(
                    _isSpeaking ? Icons.stop : Icons.volume_up,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                  onPressed: () => _speak(message.content),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
