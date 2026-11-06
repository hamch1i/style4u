
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> createOrGetChat({
    required String sellerId,
    required String storeName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    if (user.uid == sellerId) {
      throw Exception('You cannot chat with your own store.');
    }

    final customerSnapshot =
        await _db.collection('users').doc(user.uid).get();

    final sellerSnapshot =
        await _db.collection('Users').doc(sellerId).get();

    final customerData = customerSnapshot.data() ?? {};
    final sellerData = sellerSnapshot.data() ?? {};

    final customerName =
        (customerData['name'] ?? user.email ?? 'Customer').toString();

    final actualStoreName =
        (sellerData['storeName'] ?? storeName).toString();

    final chatId = '${user.uid}_$sellerId';
    final chatRef = _db.collection('chats').doc(chatId);

    await _db.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);

      if (!chatSnapshot.exists) {
        transaction.set(chatRef, {
          'customerId': user.uid,
          'sellerId': sellerId,
          'customerName': customerName,
          'sellerName': actualStoreName,
          'storeName': actualStoreName,
          'participants': [user.uid, sellerId],
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return chatId;
  }

  static Future<void> sendMessage({
    required String chatId,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final text = message.trim();

    if (user == null || text.isEmpty) return;

    final chatRef = _db.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final batch = _db.batch();

    batch.set(messageRef, {
      'senderId': user.uid,
      'message': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': user.uid,
    });

    await batch.commit();
  }
}

class ChatInboxScreen extends StatelessWidget {
  final String role;

  const ChatInboxScreen({
    super.key,
    required this.role,
  });

  static const Color pink = Color(0xFFD96B91);
  static const Color blue = Color(0xFF4A90E2);

  Color get activeColor => role == 'seller' ? pink : pink;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view messages.'));
    }

    final field = role == 'seller' ? 'sellerId' : 'customerId';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where(field, isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load conversations.'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: pink),
          );
        }

        final chats = snapshot.data?.docs.toList() ?? [];

        chats.sort((a, b) {
          final aTime = a.data()['lastMessageAt'] as Timestamp?;
          final bTime = b.data()['lastMessageAt'] as Timestamp?;

          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });

        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 65,
                    color: pink.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    role == 'seller'
                        ? 'Messages from your customers will appear here.'
                        : 'Start chatting with a seller to see your conversations here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: chats.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = chats[index];
            final data = doc.data();

            final otherName = role == 'seller'
                ? (data['customerName'] ?? 'Customer').toString()
                : (data['storeName'] ?? 'Store').toString();

            final lastMessage =
                (data['lastMessage'] ?? '').toString();

            final otherUserId = role == 'seller'
                ? (data['customerId'] ?? '').toString()
                : (data['sellerId'] ?? '').toString();

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              leading: CircleAvatar(
                backgroundColor: pink.withValues(alpha: 0.15),
                child: Icon(
                  role == 'seller'
                      ? Icons.person_outline
                      : Icons.storefront_outlined,
                  color: pink,
                ),
              ),
              title: Text(
                otherName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                lastMessage.isEmpty ? 'Start a conversation' : lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatConversationScreen(
                      chatId: doc.id,
                      currentUserRole: role,
                      otherUserId: otherUserId,
                      otherUserName: otherName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  final String chatId;
  final String currentUserRole;
  final String otherUserId;
  final String otherUserName;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.currentUserRole,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  static const Color pink = Color(0xFFD96B91);

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isSending = false;

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final message = messageController.text.trim();

    if (message.isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });

    messageController.clear();

    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        message: message,
      );
    } catch (e) {
      if (mounted) {
        messageController.text = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        backgroundColor: pink,
        foregroundColor: Colors.white,
        title: Text(
          widget.otherUserName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load messages.'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: pink),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Send a message to start the conversation.'),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();

                    final senderId =
                        (data['senderId'] ?? '').toString();

                    final isMine = senderId == currentUserId;

                    final message =
                        (data['message'] ?? '').toString();

                    final timestamp =
                        data['createdAt'] as Timestamp?;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMine ? pink : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isMine
                              ? null
                              : Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              message,
                              style: TextStyle(
                                color: isMine ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatTime(timestamp),
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white70
                                    : Colors.black45,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: const Color(0xFFFFF8FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: pink,
                    child: IconButton(
                      onPressed: isSending ? null : send,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
