import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/conversation.dart';
import '../../services/story_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../config/api_config.dart';
import 'story_detail_screen.dart';

class StoryHistoryScreen extends StatefulWidget {
  const StoryHistoryScreen({super.key});

  @override
  State<StoryHistoryScreen> createState() => _StoryHistoryScreenState();
}

class _StoryHistoryScreenState extends State<StoryHistoryScreen> {
  late StoryService _storyService;
  bool _isLoading = true;
  List<Conversation> _conversations = [];
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create a new instance of StoryService and set the context
    _storyService = StoryService();
    _storyService.setContext(context);
    // Load conversations after setting the context
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversations = await _storyService.getConversations();
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
          ),
        ],
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
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
        child: _buildBody(),
      ),
    );
  }

  // Fetch child accounts for the current user
  Future<List<Map<String, dynamic>>> _fetchChildAccounts() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getIdToken();

      if (token == null) {
        throw Exception('Failed to get authentication token');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/get_child_accounts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['child_accounts']);
      } else {
        throw Exception(
            'Failed to fetch child accounts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching child accounts: $e');
      return [];
    }
  }

  // Show dialog to assign a story to a child
  Future<void> _showAssignStoryDialog(Conversation conversation) async {
    final childAccounts = await _fetchChildAccounts();

    if (childAccounts.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to create child accounts first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedChildUsername;
    final titleController = TextEditingController();

    // Extract a title from the preview
    final previewWords = conversation.preview.split(' ');
    final suggestedTitle = previewWords.length > 3
        ? '${previewWords.take(3).join(' ')}...'
        : conversation.preview;
    titleController.text = suggestedTitle;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Story to Child'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Story Title:'),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    hintText: 'Enter a title for this story',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Child:'),
                const SizedBox(height: 8),
                ...childAccounts.map((account) => RadioListTile<String>(
                      title: Text(account['display_name'] ?? 'Child'),
                      subtitle: Text('Username: ${account['username']}'),
                      value: account['username'],
                      groupValue: selectedChildUsername,
                      onChanged: (value) {
                        setState(() {
                          selectedChildUsername = value;
                        });
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  selectedChildUsername == null || titleController.text.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);

                          try {
                            final result = await _storyService.assignStory(
                              conversation.id,
                              selectedChildUsername!,
                              titleController.text,
                            );

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Story assigned to ${selectedChildUsername}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to assign story: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading stories',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadConversations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_stories,
                color: Colors.deepPurple,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Bookshelf',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your stories will appear here as books',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a new story to see it here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: Colors.deepPurple,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 books per row
          childAspectRatio: 0.75, // Taller books
          crossAxisSpacing: 8, // Reduced horizontal spacing
          mainAxisSpacing: 12, // Reduced vertical spacing
        ),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _buildConversationCard(conversation, index);
        },
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation, int index) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final formattedDate = dateFormat.format(conversation.createdAt);

    // Generate a random appearance for each book
    final List<Color> bookColors = [
      Colors.red[400]!,
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
      Colors.indigo[400]!,
      Colors.pink[400]!,
      Colors.amber[400]!,
      Colors.cyan[400]!,
      Colors.deepOrange[400]!,
      Colors.lightBlue[400]!,
    ];

    // Use a combination of index and conversation ID for randomization
    final colorIndex = (conversation.id.hashCode + index) % bookColors.length;
    final bookColor = bookColors[colorIndex.abs()];

    // Random rotation for a more natural bookshelf look
    final rotationAngle =
        (index % 3 - 1) * 0.02; // Slight tilt: -0.02, 0, or 0.02 radians

    // Random height variation
    final heightVariation =
        130.0 + (index % 3) * 10; // Heights: 130, 140, or 150

    // Extract a title from the preview
    final previewWords = conversation.preview.split(' ');
    final title = previewWords.length > 5
        ? '${previewWords.take(5).join(' ')}...'
        : conversation.preview;

    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryDetailScreen(
                conversationId: conversation.id,
              ),
            ),
          );
        },
        child: Column(
          children: [
            // Book cover with random appearance
            Transform.rotate(
              angle: rotationAngle,
              child: Container(
                height: heightVariation,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      bookColor,
                      bookColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(4),
                    topRight: const Radius.circular(12),
                    bottomLeft: const Radius.circular(4),
                    bottomRight: const Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(3, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Book spine
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: bookColor.withOpacity(0.8),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    // Book content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Book title
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 2,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const Spacer(),

                          // Date and message count
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${conversation.messageCount} messages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Book icon
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Icon(
                        Icons.auto_stories,
                        color: Colors.white.withOpacity(0.7),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons - more compact and aligned
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Assign button
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showAssignStoryDialog(conversation),
                        icon: const Icon(Icons.child_care, size: 20),
                        color: Colors.deepPurple,
                        tooltip: 'Assign to Child',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // View button
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryDetailScreen(
                                conversationId: conversation.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 20),
                        color: Colors.deepPurple,
                        tooltip: 'View Story',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
