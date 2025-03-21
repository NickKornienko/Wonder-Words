import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../services/auth/auth_provider.dart';
import '../../services/story_service.dart';
import '../../services/tts/google_tts_service.dart';
import 'story_history_screen.dart';

class Message {
  final String content;
  final bool isUser;

  Message({required this.content, required this.isUser});
}

class KidFriendlyStoryScreen extends StatefulWidget {
  const KidFriendlyStoryScreen({Key? key}) : super(key: key);

  @override
  State<KidFriendlyStoryScreen> createState() => _KidFriendlyStoryScreenState();
}

class _KidFriendlyStoryScreenState extends State<KidFriendlyStoryScreen>
    with TickerProviderStateMixin {
  final StoryService _storyService = StoryService();
  final GoogleTtsService _ttsService = GoogleTtsService();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _bounceController;
  late AnimationController _rotateController;
  late AnimationController _scaleController;

  String? _conversationId;
  bool _isLoading = false;
  bool _needsConfirmation = false;
  bool _isSpeaking = false;
  String _pendingQuery = '';
  String _currentStory =
      'Welcome to Wonder Words! Tap a story button to begin!';

  // Story theme options with icons
  final List<Map<String, dynamic>> _storyThemes = [
    {
      'name': 'Dragons',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
      'prompt': 'Tell me a story about a friendly dragon'
    },
    {
      'name': 'Space',
      'icon': Icons.rocket_launch,
      'color': Colors.blue,
      'prompt': 'Tell me a space adventure story'
    },
    {
      'name': 'Animals',
      'icon': Icons.pets,
      'color': Colors.green,
      'prompt': 'Tell me a story about talking animals'
    },
    {
      'name': 'Magic',
      'icon': Icons.auto_awesome,
      'color': Colors.purple,
      'prompt': 'Tell me a magical fairy tale'
    },
    {
      'name': 'Pirates',
      'icon': Icons.sailing,
      'color': Colors.amber,
      'prompt': 'Tell me a pirate adventure story'
    },
    {
      'name': 'Dinosaurs',
      'icon': Icons.landscape,
      'color': Colors.brown,
      'prompt': 'Tell me a story about dinosaurs'
    },
  ];

  // Story continuation options
  final List<Map<String, dynamic>> _continuationOptions = [
    {
      'name': 'What happens next?',
      'icon': Icons.arrow_forward,
      'color': Colors.blue,
    },
    {
      'name': 'Add a dragon!',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
    },
    {
      'name': 'Make it funny!',
      'icon': Icons.emoji_emotions,
      'color': Colors.amber,
    },
    {
      'name': 'Add magic!',
      'icon': Icons.auto_awesome,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

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
    // Set the context for the StoryService
    _storyService.setContext(context);
  }

  /// Speak the given text using Google Cloud TTS
  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _ttsService.speak(text);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ttsService.dispose();
    _bounceController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _requestStory(String prompt) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_needsConfirmation) {
        // Handle confirmation for new story when there's an existing conversation
        await _handleConfirmation('yes');
      } else {
        // Normal message handling
        await _handleNormalMessage(prompt);
      }
    } catch (e) {
      setState(() {
        _currentStory = 'Oops! Something went wrong. Try again!';
        _isLoading = false;
      });
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
        _currentStory = response['confirmation'];
        _needsConfirmation = true;
        _pendingQuery = userMessage;
        _conversationId = response['conversation_id'].toString();
      } else {
        // Normal response
        final storyContent =
            response['response'] ?? response['message'] ?? 'No response';
        _currentStory = storyContent;
        if (response['conversation_id'] != null) {
          _conversationId = response['conversation_id'].toString();
        }

        // Automatically speak the story
        _speak(storyContent);
      }
    });
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
        _currentStory = 'Please tap Yes or No!';
        _isLoading = false;
      });
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
        _currentStory = storyContent;
        if (response['conversation_id'] != null) {
          _conversationId = response['conversation_id'].toString();
        }

        // Automatically speak the story
        _speak(storyContent);
      } else {
        _currentStory = 'Okay! Let\'s try a different story!';
      }
    });
  }

  // Show information about the Google Cloud TTS voice and allow voice selection
  void _showVoiceSelectionDialog() {
    // Get the current selected voice
    final currentVoice = _ttsService.selectedVoice;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.record_voice_over, color: Colors.deepPurple, size: 30),
              SizedBox(width: 10),
              Text(
                'Choose a Voice!',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [Colors.purple[100]!, Colors.purple[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(15),
                child: Column(
                  children: [
                    Text(
                      'Who should tell your story?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepPurple,
                      ),
                    ),
                    SizedBox(height: 15),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple, width: 2),
                      ),
                      child: DropdownButton<GoogleTtsVoice>(
                        isExpanded: true,
                        value: currentVoice,
                        underline: Container(),
                        icon: Icon(Icons.arrow_drop_down_circle,
                            color: Colors.deepPurple),
                        items: _ttsService.voices.map((voice) {
                          return DropdownMenuItem<GoogleTtsVoice>(
                            value: voice,
                            child: Text(
                              voice.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (GoogleTtsVoice? newVoice) async {
                          if (newVoice != null) {
                            await _ttsService.setVoice(newVoice);
                            setState(() {}); // Update the dialog state
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 15),
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.play_circle_filled),
                  label: Text("Test Voice"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () =>
                      _speak("Hello! I'll be telling your stories today!"),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.check_circle, color: Colors.green),
              label: Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // More vibrant, kid-friendly gradient background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple[300]!,
              Colors.indigo[300]!,
              Colors.blue[300]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Animated app bar with bouncing elements
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Animated app icon
                        AnimatedBuilder(
                          animation: _bounceController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _bounceController.value * -5),
                              child: child,
                            );
                          },
                          child: Icon(
                            Icons.auto_stories,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Wonder Words',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 2,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Voice selection button
                        IconButton(
                          icon: AnimatedBuilder(
                            animation: _rotateController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotateController.value * 2 * math.pi,
                                child: child,
                              );
                            },
                            child: Icon(
                              Icons.record_voice_over,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          onPressed: _showVoiceSelectionDialog,
                          tooltip: 'Choose a Voice',
                        ),
                        // History button
                        IconButton(
                          icon: Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const StoryHistoryScreen(),
                              ),
                            );
                          },
                          tooltip: 'Story History',
                        ),
                        // New story button
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentStory =
                                  'Welcome to Wonder Words! Tap a story button to begin!';
                              _conversationId = null;
                              _needsConfirmation = false;
                              _pendingQuery = '';
                            });
                          },
                          tooltip: 'New Story',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Story display area with animated elements
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.purple[300]!,
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Story text with scroll
                      SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Story title with animated stars
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _rotateController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle:
                                          _rotateController.value * 2 * math.pi,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: Colors.amber,
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Your Story',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                SizedBox(width: 8),
                                AnimatedBuilder(
                                  animation: _rotateController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: -_rotateController.value *
                                          2 *
                                          math.pi,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: Colors.amber,
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Story content
                            Text(
                              _currentStory,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ),

                            // Add some space at the bottom for better scrolling
                            SizedBox(height: 60),
                          ],
                        ),
                      ),

                      // Play/Stop button (floating)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: AnimatedBuilder(
                          animation: _scaleController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_scaleController.value * 0.1),
                              child: child,
                            );
                          },
                          child: FloatingActionButton(
                            onPressed: () => _speak(_currentStory),
                            backgroundColor: Colors.deepPurple,
                            child: Icon(
                              _isSpeaking ? Icons.stop : Icons.play_arrow,
                              size: 32,
                            ),
                            tooltip: _isSpeaking ? 'Stop' : 'Play',
                          ),
                        ),
                      ),

                      // Loading indicator
                      if (_isLoading)
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.deepPurple,
                                  ),
                                  strokeWidth: 5,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Creating your story...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Story theme selection or continuation options
              Container(
                height: 180,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 8),
                      child: Text(
                        _needsConfirmation
                            ? 'Do you want a new story?'
                            : (_conversationId == null
                                ? 'Choose a story theme!'
                                : 'What happens next?'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _needsConfirmation
                          ? _buildConfirmationButtons()
                          : (_conversationId == null
                              ? _buildThemeButtons()
                              : _buildContinuationButtons()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeButtons() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 12),
      itemCount: _storyThemes.length,
      itemBuilder: (context, index) {
        final theme = _storyThemes[index];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              return Transform.translate(
                offset:
                    Offset(0, math.sin(_bounceController.value * math.pi) * 5),
                child: child,
              );
            },
            child: InkWell(
              onTap: () => _requestStory(theme['prompt']),
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: theme['color'],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      theme['icon'],
                      size: 40,
                      color: Colors.white,
                    ),
                    SizedBox(height: 8),
                    Text(
                      theme['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinuationButtons() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 12),
      itemCount: _continuationOptions.length,
      itemBuilder: (context, index) {
        final option = _continuationOptions[index];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                    0,
                    math.sin(
                            (_bounceController.value + index * 0.2) * math.pi) *
                        5),
                child: child,
              );
            },
            child: InkWell(
              onTap: () => _requestStory(option['name']),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: option['color'],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option['icon'],
                      size: 40,
                      color: Colors.white,
                    ),
                    SizedBox(height: 8),
                    Text(
                      option['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Yes button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_scaleController.value * 0.1),
                child: child,
              );
            },
            child: ElevatedButton.icon(
              icon: Icon(Icons.check_circle, size: 32),
              label: Text(
                'Yes!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _handleConfirmation('yes'),
            ),
          ),
        ),

        // No button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_scaleController.value * 0.1),
                child: child,
              );
            },
            child: ElevatedButton.icon(
              icon: Icon(Icons.cancel, size: 32),
              label: Text(
                'No!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _handleConfirmation('no'),
            ),
          ),
        ),
      ],
    );
  }
}
