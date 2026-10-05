import 'package:flutter/material.dart';
import '../models/queue_token.dart';
import '../repositories/queue_repository.dart';
import '../main.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  final Map<int, String> _lastNotifiedState = {};

  NotificationService._internal();

  /// Clears notification history. Call this on user logout.
  void clearState() {
    _lastNotifiedState.clear();
  }

  /// Processes fresh tokens to determine if any notification should be triggered.
  Future<void> processTokens(List<QueueToken> tokens) async {
    final currentIds = tokens.map((t) => t.id!).toSet();

    // 1. Check for tokens that disappeared from the active list
    final previouslyTrackedIds = _lastNotifiedState.keys.toList();
    for (final id in previouslyTrackedIds) {
      if (!currentIds.contains(id)) {
        final lastState = _lastNotifiedState[id];
        // If it's already marked as terminal, skip
        if (lastState == 'completed' || lastState == 'cancelled' || lastState == 'missing') {
          continue;
        }

        // Fetch authoritative final status
        try {
          final QueueRepository repo = QueueRepository();
          final token = await repo.getQueueTokenById(id);
          
          if (token != null) {
            if (token.status == 'completed') {
              _notify(id, 'completed', '✓ Your appointment in the queue has been completed.');
            } else if (token.status == 'cancelled') {
              _lastNotifiedState[id] = 'cancelled';
            } else {
              _lastNotifiedState[id] = token.status;
            }
          } else {
            _lastNotifiedState[id] = 'missing';
          }
        } catch (e) {
          // If fetch fails (offline), do nothing so we can retry when online
        }
      }
    }

    // 2. Evaluate current active tokens
    for (var token in tokens) {
      final id = token.id;
      if (id == null) continue;

      if (token.status == 'serving') {
        _notify(id, 'serving', '🎉 It\'s your turn! Please proceed to the service counter.');
      } else if (token.status == 'waiting' && token.peopleAhead == 1) {
        _notify(id, 'approaching', '🔔 You\'re next! Only 1 person is ahead of you.');
      } else {
        // Track the token if not already tracked so disappearance checks work
        if (!_lastNotifiedState.containsKey(id)) {
          _lastNotifiedState[id] = 'waiting';
        }
      }
    }
  }

  void _notify(int tokenId, String state, String message) {
    if (_lastNotifiedState[tokenId] != state) {
      _lastNotifiedState[tokenId] = state;
      
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    }
  }
}
