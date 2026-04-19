class ChatMessage {
  final String id;
  final String plantId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.plantId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<dynamic, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        plantId: json['plantId'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
