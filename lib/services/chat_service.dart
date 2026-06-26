import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Send a new message
  Future<void> sendMessage({
    required String issueId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    final chatMessage = ChatMessage(
      id: _uuid.v4(),
      issueId: issueId,
      senderId: senderId,
      senderName: senderName,
      message: message,
    );

    await _firestore
        .collection('issues')
        .doc(issueId)
        .collection('messages')
        .doc(chatMessage.id)
        .set(chatMessage.toMap());
  }

  /// Get real-time message stream for an issue
  Stream<List<ChatMessage>> getMessages(String issueId) {
    return _firestore
        .collection('issues')
        .doc(issueId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatMessage.fromMap(doc.data()))
                  .toList(),
        );
  }

  /// Get unread message count (messages not from current user)
  Stream<int> getUnreadCount(String issueId, String currentUserId) {
    return _firestore
        .collection('issues')
        .doc(issueId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
