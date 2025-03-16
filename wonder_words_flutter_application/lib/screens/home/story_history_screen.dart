import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/conversation.dart';
import '../../services/story_service.dart';
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
