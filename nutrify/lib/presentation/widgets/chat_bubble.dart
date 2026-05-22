import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final String? time;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 220,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.userBubble : AppColors.aiBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('NutriFy AI',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            _buildParsedMessage(
              message,
              isUser ? AppTextStyles.chatUser : AppTextStyles.chatAi,
            ),
            if (time != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  time!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isUser ? Colors.white60 : AppColors.textLight,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedMessage(String message, TextStyle baseStyle) {
    if (message.trim().isEmpty) {
      return const SizedBox();
    }

    final List<String> lines = message.split('\n');
    final List<Widget> children = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        if (i < lines.length - 1) {
          children.add(const SizedBox(height: 8));
        }
        continue;
      }

      // Check if it's a bullet item starting with '-'
      // e.g. "- item" or "  - item"
      final bulletMatch = RegExp(r'^(\s*)-\s*(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1) ?? '';
        final content = bulletMatch.group(2) ?? '';
        final indentWidth = indent.length * 8.0;

        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (indentWidth > 0) SizedBox(width: indentWidth),
                Text(
                  '• ',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: baseStyle,
                      children: _parseInlineSpans(content, baseStyle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Normal paragraph/line
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RichText(
              text: TextSpan(
                style: baseStyle,
                children: _parseInlineSpans(line, baseStyle),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<InlineSpan> _parseInlineSpans(String text, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the bold tag
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: baseStyle,
        ));
      }

      // Add the bold tag content
      final boldText = match.group(1) ?? '';
      final double baseSize = baseStyle.fontSize ?? 14.0;
      spans.add(TextSpan(
        text: boldText,
        style: baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: baseSize * 1.2,
        ),
      ));

      start = match.end;
    }

    // Add remaining trailing text
    if (start < text.length) {
      spans.add(TextSpan(text: "\n", style: baseStyle));
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
