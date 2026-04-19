import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart' as model;
import '../providers/api_key_provider.dart';
import '../providers/database_provider.dart';
import '../providers/fertilizer_provider.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';

class _UiMessage {
  final String text;
  final bool isUser;
  _UiMessage({required this.text, required this.isUser});
}

class ChatScreen extends ConsumerStatefulWidget {
  final List<File> images;
  final String plantName;
  final String diagnosis;
  final String? plantId;

  const ChatScreen({
    super.key,
    required this.images,
    required this.plantName,
    required this.diagnosis,
    this.plantId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_UiMessage>[];
  bool _loading = false;

  // Conversation history for Claude API (keeps context)
  final _conversationHistory = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  void _initConversation() {
    // Seed conversation with identification + diagnosis context
    _conversationHistory.add({
      'role': 'user',
      'content':
          'Ich habe eine Pflanze fotografiert. Sie wurde als "${widget.plantName}" identifiziert.\n\n'
              'Diagnose:\n${widget.diagnosis}\n\n'
              'Ich möchte dir jetzt Fragen zu dieser Pflanze stellen.',
    });
    _conversationHistory.add({
      'role': 'assistant',
      'content':
          'Klar, frag mich gerne alles zu deiner ${widget.plantName}! '
              'Ich habe die Diagnose im Blick und kann dir weiterhelfen.',
    });

    // Load persisted messages if plant is saved
    if (widget.plantId != null) {
      final saved = ref.read(plantChatProvider(widget.plantId!));
      for (final msg in saved) {
        _messages.add(_UiMessage(text: msg.content, isUser: msg.role == 'user'));
        _conversationHistory.add({
          'role': msg.role,
          'content': msg.content,
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    _controller.clear();
    setState(() {
      _messages.add(_UiMessage(text: text, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final apiKey = ref.read(apiKeyProvider).value;
      if (apiKey == null) throw Exception('Kein API Key');

      final service = ClaudeService(apiKey);
      final fertilizers = ref.read(fertilizersProvider);
      final response = await service.askQuestion(
        conversationHistory: _conversationHistory,
        question: text,
        availableFertilizers: fertilizers.isNotEmpty ? fertilizers : null,
      );

      // Update conversation history
      _conversationHistory.add({'role': 'user', 'content': text});
      _conversationHistory.add({'role': 'assistant', 'content': response});

      setState(() {
        _messages.add(_UiMessage(text: response, isUser: false));
      });

      // Persist messages if plant is saved
      if (widget.plantId != null) {
        final db = DatabaseService.instance;
        await db.saveChatMessage(model.ChatMessage(
          id: db.generateId(),
          plantId: widget.plantId!,
          role: 'user',
          content: text,
          timestamp: DateTime.now(),
        ));
        await db.saveChatMessage(model.ChatMessage(
          id: db.generateId(),
          plantId: widget.plantId!,
          role: 'assistant',
          content: response,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      setState(() {
        _messages.add(_UiMessage(
          text: 'Fehler: $e',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plantName, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return _buildMessage(_messages[index], theme);
                    },
                  ),
          ),
          _buildInput(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Frag mich was!',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Stelle Fragen zu deiner Pflanze.\nz.B. "Wie oft gießen?" oder\n"Welcher Standort ist ideal?"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(_UiMessage message, ThemeData theme) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: isUser ? const Radius.circular(4) : null,
              bottomLeft: !isUser ? const Radius.circular(4) : null,
            ),
          ),
          child: SelectableText(
            message.text,
            style: TextStyle(
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Frage stellen...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _loading ? null : _sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
