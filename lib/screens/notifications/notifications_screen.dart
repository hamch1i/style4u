
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  final String role;

  const NotificationsScreen({
    super.key,
    required this.role,
  });

  static const Color pink = Color(0xFFD96B91);

  CollectionReference<Map<String, dynamic>> get notificationCollection {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final parentCollection = role == 'seller' ? 'Users' : 'users';

    return FirebaseFirestore.instance
        .collection(parentCollection)
        .doc(uid)
        .collection('notifications');
  }

  Future<void> markAsRead(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    await reference.update({'isRead': true});
  }

  Future<void> markAllAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> notifications,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final notification in notifications) {
      if (notification.data()['isRead'] != true) {
        batch.update(notification.reference, {'isRead': true});
      }
    }

    await batch.commit();
  }

  String formatDate(dynamic value) {
    if (value is! Timestamp) return 'Just now';

    final date = value.toDate();
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    }
    if (difference.inDays == 1) return 'Yesterday';

    return '${date.day}/${date.month}/${date.year}';
  }

  IconData notificationIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'payment':
        return Icons.payments_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in first.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: pink,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: notificationCollection.snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              return TextButton(
                onPressed: docs.isEmpty
                    ? null
                    : () async {
                        try {
                          await markAllAsRead(docs);
                        } catch (e) {
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unable to update: $e')),
                          );
                        }
                      },
                child: const Text(
                  'Read all',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationCollection
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load notifications.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: pink),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 75,
                    color: pink.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Your order and chat updates will appear here.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data();

              final title = (data['title'] ?? 'Notification').toString();
              final body = (data['body'] ?? '').toString();
              final type = (data['type'] ?? '').toString();
              final isRead = data['isRead'] == true;

              return Card(
                color: isRead ? Colors.white : const Color(0xFFFFEDF3),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    if (!isRead) {
                      try {
                        await markAsRead(doc.reference);
                      } catch (e) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to update notification: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: pink.withValues(alpha: 0.13),
                          child: Icon(
                            notificationIcon(type),
                            color: pink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: pink,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 7),
                              Text(
                                formatDate(data['createdAt']),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
