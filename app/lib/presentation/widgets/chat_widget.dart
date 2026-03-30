import 'package:flutter/material.dart';
import '../../../data/models/multiplayer_models.dart';
import '../../../core/theme/app_theme.dart';
import '../blocs/multiplayer/multiplayer_bloc.dart';

class ChatWidget extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;

  const ChatWidget({
    super.key,
    required this.messages,
    required this.onSendMessage,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didUpdateWidget(ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.midnight.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.chat_bubble_rounded,
                  color: AppTheme.goldPrimary, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Game Chat',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon:
                    const Icon(Icons.close_rounded, color: AppTheme.textMuted),
              ),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final msg = widget.messages[index];
                return _buildMessage(msg);
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildEmojiRow(),
          // Input field
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    return Column(
      crossAxisAlignment:
          msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isMe
                ? AppTheme.goldPrimary.withValues(alpha: 0.15)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: msg.isMe ? const Radius.circular(0) : null,
              bottomLeft: msg.isMe ? null : const Radius.circular(0),
            ),
            border: Border.all(
                color: msg.isMe
                    ? AppTheme.goldPrimary.withValues(alpha: 0.3)
                    : Colors.white10),
          ),
          child: Column(
            crossAxisAlignment:
                msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!msg.isMe)
                Text(
                  msg.username,
                  style: const TextStyle(
                      color: AppTheme.goldPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              if (!msg.isMe) const SizedBox(height: 4),
              Text(
                msg.message,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle:
                    TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: AppTheme.midnight.withValues(alpha: 0.5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.goldPrimary),
            child: IconButton(
              onPressed: _send,
              icon: const Icon(Icons.send_rounded, color: AppTheme.midnight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiRow() {
    final emojis = ['♟️', '🔥', '😂', '🤝', '👋', '🏆', '👀', '🤯'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: emojis.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () {
            _controller.text += emojis[index];
            _send();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Text(emojis[index], style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSendMessage(_controller.text.trim());
    _controller.clear();
  }
}
