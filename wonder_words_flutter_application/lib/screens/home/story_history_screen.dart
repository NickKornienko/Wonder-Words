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
import 'package:flutter/foundation.dart';

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
      // Get the AuthProvider to check if the user is a child
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Load conversations based on account type
      List<Conversation> conversations;
      if (authProvider.isChild) {
        // For child accounts, only show assigned stories and stories they created
        final assignedStories = await _storyService.getAssignedStories();
        final childConversations = await _storyService.getConversations();

        // Create a set of conversation IDs from assigned stories
        final Set<String> assignedConversationIds =
            assignedStories.map((story) => story.conversationId).toSet();

        // Filter conversations to only include assigned ones and ones created by the child
        conversations = childConversations.where((conversation) {
          // Include if it's in the assigned stories or if it was created by the child
          return assignedConversationIds.contains(conversation.id);
        }).toList();
      } else {
        // For parent accounts, show all conversations
        conversations = await _storyService.getConversations();
      }

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
    // Get the AuthProvider to check if the user is a child
    final authProvider = Provider.of<AuthProvider>(context);
    final isChild = authProvider.isChild;

    return Scaffold(
      appBar: AppBar(
        title: Text(isChild ? 'My Books' : 'My Stories'),
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

      // Call the backend API to authenticate the child
      // Use baseUrl from ApiConfig if running on web, and deviceUrl if running on a device
      const isWeb = kIsWeb;
      const url = isWeb ? ApiConfig.baseUrl : ApiConfig.deviceUrl;

      final response = await http.get(
        Uri.parse('$url/get_child_accounts'),
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

    // Extract title from the preview if it's in the TITLE: STORY: format
    String suggestedTitle;
    if (conversation.preview.contains("TITLE:") &&
        conversation.preview.contains("STORY:")) {
      final parts = conversation.preview.split("STORY:");
      final titlePart = parts[0].trim();
      suggestedTitle = titlePart.replaceFirst("TITLE:", "").trim();
    } else {
      // Fallback to the old method if the format is not found
      final previewWords = conversation.preview.split(' ');
      suggestedTitle = previewWords.length > 3
          ? '${previewWords.take(3).join(' ')}...'
          : conversation.preview;
    }
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
      child: Padding(
        padding:
            const EdgeInsets.all(4.0), // Add a small padding around the grid
        child: LayoutBuilder(builder: (context, constraints) {
          // Limit to maximum 8 books per row, minimum 3
          int crossAxisCount = 8;
          if (constraints.maxWidth < 800) {
            crossAxisCount = 6;
          }
          if (constraints.maxWidth < 600) {
            crossAxisCount = 4;
          }
          if (constraints.maxWidth < 400) {
            crossAxisCount = 3;
          }

          return GridView.builder(
            padding: const EdgeInsets.only(
                bottom: 16), // Add bottom padding to avoid overflow
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount, // Fixed number of books per row
              childAspectRatio: 0.75, // Taller than wide for book appearance
              crossAxisSpacing: 4, // Small horizontal spacing
              mainAxisSpacing: 4, // Small vertical spacing
            ),
            itemCount: _conversations.length,
            itemBuilder: (context, index) {
              final conversation = _conversations[index];
              return _buildConversationCard(conversation);
            },
          );
        }),
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final formattedDate = dateFormat.format(conversation.createdAt);

    // Generate a random color for the book cover
    final List<Color> bookColors = [
      Colors.red[400]!,
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
      Colors.indigo[400]!,
      Colors.pink[400]!,
    ];

    // Use the conversation ID to consistently select a color
    final colorIndex = conversation.id.hashCode % bookColors.length;
    final bookColor = bookColors[colorIndex.abs()];

    // Extract title from the preview if it's in the TITLE: STORY: format
    String title;
    if (conversation.preview.contains("TITLE:") &&
        conversation.preview.contains("STORY:")) {
      final parts = conversation.preview.split("STORY:");
      final titlePart = parts[0].trim();
      title = titlePart.replaceFirst("TITLE:", "").trim();
    } else {
      // Fallback to the old method if the format is not found
      final previewWords = conversation.preview.split(' ');
      title = previewWords.length > 5
          ? '${previewWords.take(5).join(' ')}...'
          : conversation.preview;
    }

    return Card(
      margin: const EdgeInsets.all(1), // Small margin
      elevation: 2, // Slight elevation for depth
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Slightly rounded corners
      ),
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
            // Book cover - with proportional sizing
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      bookColor,
                      bookColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(12),
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

            // Action buttons - more compact and better aligned
            Container(
              width: double.infinity,
              height: 30,
              color: Colors.grey[100],
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Assign button - only show for parent accounts
                      if (!authProvider.isChild)
                        Expanded(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showAssignStoryDialog(conversation),
                            icon: const Icon(Icons.child_care, size: 16),
                            color: Colors.deepPurple,
                            tooltip: 'Assign to Child',
                          ),
                        ),
                      // View button
                      Expanded(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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
                          icon: const Icon(Icons.visibility, size: 16),
                          color: Colors.deepPurple,
                          tooltip: 'View Story',
                        ),
                      ),
                      // Delete button - only show for parent accounts
                      if (!authProvider.isChild)
                        Expanded(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                _showDeleteConfirmationDialog(conversation),
                            icon: const Icon(Icons.delete, size: 16),
                            color: Colors.red,
                            tooltip: 'Delete Story',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show confirmation dialog before deleting a story
  Future<void> _showDeleteConfirmationDialog(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text(
          'Are you sure you want to delete this story? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Delete the conversation
        await _storyService.deleteConversation(conversation.id);

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Story deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Refresh the list
        _loadConversations();
      } catch (e) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete story: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
