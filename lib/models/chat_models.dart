// Local chat models for the driver inbox / thread UI.
// Backend chat APIs can replace [ChatSeed] later without UI rewrites.

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.isMine,
  });

  final String id;
  final String text;
  final DateTime sentAt;
  final bool isMine;

  ChatMessage copyWith({
    String? id,
    String? text,
    DateTime? sentAt,
    bool? isMine,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isMine: isMine ?? this.isMine,
    );
  }
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.peerName,
    required this.lastMessage,
    required this.timeLabel,
    required this.messages,
    this.peerPhotoUrl,
    this.isActiveRide = false,
    this.statusLabel,
  });

  final String id;
  final String peerName;
  final String? peerPhotoUrl;
  final String lastMessage;
  final String timeLabel;
  final bool isActiveRide;

  /// e.g. "En route to DHA Phase 5" or "On the way to pickup"
  final String? statusLabel;
  final List<ChatMessage> messages;

  ChatThread copyWith({
    String? id,
    String? peerName,
    String? peerPhotoUrl,
    String? lastMessage,
    String? timeLabel,
    bool? isActiveRide,
    String? statusLabel,
    List<ChatMessage>? messages,
  }) {
    return ChatThread(
      id: id ?? this.id,
      peerName: peerName ?? this.peerName,
      peerPhotoUrl: peerPhotoUrl ?? this.peerPhotoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      timeLabel: timeLabel ?? this.timeLabel,
      isActiveRide: isActiveRide ?? this.isActiveRide,
      statusLabel: statusLabel ?? this.statusLabel,
      messages: messages ?? this.messages,
    );
  }
}

/// Demo conversations matching the product mockups (no chat API yet).
abstract final class ChatSeed {
  static List<ChatThread> demoThreads() {
    final now = DateTime.now();
    return [
      ChatThread(
        id: 'active-amara',
        peerName: 'Amara J.',
        peerPhotoUrl: null,
        isActiveRide: true,
        statusLabel: 'En route to DHA Phase 5',
        timeLabel: 'Just now',
        lastMessage:
            "I'm waiting near the main gate. Look for a blue jacket.",
        messages: [
          ChatMessage(
            id: 'm1',
            text: "Hi! I'm almost at the pickup point.",
            sentAt: now.subtract(const Duration(minutes: 4)),
            isMine: false,
          ),
          ChatMessage(
            id: 'm2',
            text: "I'm on my way — 3 minutes out.",
            sentAt: now.subtract(const Duration(minutes: 3)),
            isMine: true,
          ),
          ChatMessage(
            id: 'm3',
            text: "I'm waiting near the main gate. Look for a blue jacket.",
            sentAt: now.subtract(const Duration(minutes: 1)),
            isMine: false,
          ),
        ],
      ),
      ChatThread(
        id: 'michael',
        peerName: 'Michael Chang',
        peerPhotoUrl: null,
        timeLabel: 'Yesterday',
        lastMessage: 'Thanks for the ride! Five stars.',
        messages: [
          ChatMessage(
            id: 'm1',
            text: 'Thanks for the ride! Five stars.',
            sentAt: now.subtract(const Duration(days: 1)),
            isMine: false,
          ),
          ChatMessage(
            id: 'm2',
            text: 'Appreciate it — drive safe!',
            sentAt: now.subtract(const Duration(days: 1, minutes: -2)),
            isMine: true,
          ),
        ],
      ),
      ChatThread(
        id: 'sarah',
        peerName: 'Sarah Jenkins',
        peerPhotoUrl: null,
        timeLabel: 'Mon',
        lastMessage: 'I left a small bag in the back, can you check?',
        messages: [
          ChatMessage(
            id: 'm1',
            text: 'I left a small bag in the back, can you check?',
            sentAt: now.subtract(const Duration(days: 3)),
            isMine: false,
          ),
        ],
      ),
      ChatThread(
        id: 'david',
        peerName: 'David R.',
        peerPhotoUrl: null,
        timeLabel: 'Oct 12',
        lastMessage: 'Perfect, see you then.',
        messages: [
          ChatMessage(
            id: 'm1',
            text: 'Pickup at 9 AM works for me.',
            sentAt: DateTime(now.year, 10, 12, 9, 0),
            isMine: true,
          ),
          ChatMessage(
            id: 'm2',
            text: 'Perfect, see you then.',
            sentAt: DateTime(now.year, 10, 12, 9, 5),
            isMine: false,
          ),
        ],
      ),
    ];
  }
}
