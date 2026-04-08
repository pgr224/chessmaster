import 'package:flutter/material.dart';

class EngagementFeedItem {
  final String title;
  final String body;
  final DateTime createdAt;
  final Color accent;

  const EngagementFeedItem({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.accent,
  });
}

class EngagementNotifier {
  final int maxItems;
  bool _notifyEnabled;
  final List<EngagementFeedItem> _feed = <EngagementFeedItem>[];

  EngagementNotifier({int maxItems = 8, bool notifyEnabled = true})
      : maxItems = maxItems,
        _notifyEnabled = notifyEnabled;

  bool get notifyEnabled => _notifyEnabled;
  List<EngagementFeedItem> get feed => List<EngagementFeedItem>.unmodifiable(_feed);

  void setNotifyEnabled(bool enabled) {
    _notifyEnabled = enabled;
  }

  void toggleNotify() {
    _notifyEnabled = !_notifyEnabled;
  }

  void push({
    required BuildContext context,
    required bool globalNotificationsEnabled,
    required String title,
    required String body,
    required Color accent,
    Duration snackDuration = const Duration(seconds: 3),
    bool snackAlwaysSilent = false,
  }) {
    _feed.insert(
      0,
      EngagementFeedItem(
        title: title,
        body: body,
        createdAt: DateTime.now(),
        accent: accent,
      ),
    );

    if (_feed.length > maxItems) {
      _feed.removeRange(maxItems, _feed.length);
    }

    final canNotify = !snackAlwaysSilent && globalNotificationsEnabled && _notifyEnabled;
    if (canNotify) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$title • $body'),
            duration: snackDuration,
          ),
        );
    }
  }

  String timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }
    return '${diff.inHours}h';
  }
}
