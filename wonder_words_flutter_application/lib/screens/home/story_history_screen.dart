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
              'Error loading stories',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No stories yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Start a new story to see it here'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _buildConversationCard(conversation);
        },
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

  Widget _buildConversationCard(Conversation conversation) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final formattedDate = dateFormat.format(conversation.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${conversation.messageCount} messages',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                conversation.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showAssignStoryDialog(conversation),
                    icon: const Icon(Icons.child_care),
                    label: const Text('Assign to Child'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
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
                    child: const Text('View Story'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
