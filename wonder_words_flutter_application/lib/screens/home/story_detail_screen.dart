import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/conversation.dart';
import '../../services/story_service.dart';
import '../../services/tts/google_tts_service.dart';


class StoryDetailScreen extends StatefulWidget {
  final String conversationId;

  StoryDetailScreen({
    super.key,
    required this.conversationId,
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late StoryService _storyService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GoogleTtsService _ttsService = GoogleTtsService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  bool _isLoading = true;
  List<Message> _messages = [];
  String? _error;
  bool _isSending = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    // Initialize StoryService and set the context
    _storyService = StoryService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _storyService.setContext(context);
      _loadMessages(); // Load messages after setting the context
    });

    // Listen for TTS state changes
    _ttsService.addStateListener((isSpeaking) {
      if (mounted) {
        setState(() {
          _isSpeaking = isSpeaking;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No longer initialize or set context here
    // previously '_storyService' and _loadMessages() were called here
    // it caused a context setting loop and graphical issues in ipad
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  /// Speak the given text using Google Cloud TTS
  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _ttsService.speak(text);
    }
  }

  // Show information about the Google Cloud TTS voice
  void _showVoiceInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Using Google Cloud Text-to-Speech',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This app uses Google\'s Neural2 voice technology for high-quality, natural-sounding narration.',
            ),
            SizedBox(height: 8),
            Text(
              'Voice: en-US-Neural2-F',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 8),
            Text(
              'If you\'re offline, the app will automatically switch to your device\'s built-in text-to-speech.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final messages =
          await _storyService.getConversationMessages(widget.conversationId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });
    _messageController.clear();
    final userID = await _storyService.getIdToken();
    try {
      // Use a placeholder user ID since the actual ID is retrieved from Firebase token
      final response = await _storyService.addToStory(
        message,
        userID,
        widget.conversationId,
      );

      // Reload messages to get the updated conversation
      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _messageController.text = result.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            onPressed: _showVoiceInfoDialog,
            tooltip: 'Voice Information',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading story',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.senderType == SenderType.USER;
    final dateFormat = DateFormat('MMM d, h:mm a');
    final formattedDate = dateFormat.format(message.createdAt);

    // Parse title and story if the message is in the TITLE: STORY: format
    String? title;
    String content = message.content;

    if (!isUser &&
        message.content.contains("TITLE:") &&
        message.content.contains("STORY:")) {
      final parts = message.content.split("STORY:");
      final titlePart = parts[0].trim();
      title = titlePart.replaceFirst("TITLE:", "").trim();
      content = parts[1].trim();
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
              : Theme.of(context).colorScheme.secondary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display title if available
            if (title != null && !isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  title,
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            // Display content
            Text(
              content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (!isUser) // Only show speak button for AI messages
                  IconButton(
                    icon: Icon(
                      _isSpeaking ? Icons.stop : Icons.volume_up,
                      color: isUser ? Colors.white70 : Colors.black54,
                      size: 16,
                    ),
                    onPressed: () => _speak(
                        content), // Speak only the story content, not the title
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
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
            heroTag: 'micButton',
            onPressed: _startListening,
            backgroundColor: _isListening ? Colors.red : Colors.deepPurple,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
            mini: true,
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
    );
  }
}
