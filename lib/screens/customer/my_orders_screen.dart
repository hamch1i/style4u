
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  static const Color pink = Color(0xFFD96B91);
  static const Color blue = Color(0xFF4A90E2);

  static const List<String> trackingSteps = [
    'Order Placed',
    'Confirmed',
    'Processing',
    'In Transit',
    'Delivered',
  ];

  static const List<String> trackingStatuses = [
    'pending',
    'confirmed',
    'processing',
    'shipped',
    'delivered',
  ];

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.month}/${date.day}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    if (value is DateTime) {
      return _formatDate(Timestamp.fromDate(value));
    }

    return 'Date unavailable';
  }

  int _statusIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'confirmed':
        return 1;
      case 'processing':
        return 2;
      case 'shipped':
        return 3;
      case 'delivered':
        return 4;
      default:
        return -1;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'processing':
        return blue;
      case 'shipped':
        return Colors.deepPurple;
      case 'delivered':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _trackingDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for the seller to confirm your order.';
      case 'confirmed':
        return 'The seller has accepted your order.';
      case 'processing':
        return 'The seller is preparing your order.';
      case 'shipped':
        return 'Your order is on its way!';
      case 'delivered':
        return 'You have received your order.';
      default:
        return '';
    }
  }

  Widget _buildTracking(
    String orderId,
    String status,
    dynamic orderCreatedAt,
  ) {
    final currentIndex = _statusIndex(status);

    if (status == 'rejected') {
      return _statusMessage(
        'This order was rejected by the seller.',
        Colors.red,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('statusHistory')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic> history = {};

        if (snapshot.hasData) {
          for (final document in snapshot.data!.docs) {
            final event = document.data();
            final eventStatus =
                (event['status'] ?? '').toString().toLowerCase();

            if (eventStatus.isNotEmpty) {
              history[eventStatus] = event['createdAt'];
            }
          }
        }

        // Fallback for older orders that do not have history records.
        history.putIfAbsent('pending', () => orderCreatedAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Tracking',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 18),

            if (snapshot.hasError)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Tracking timestamps are temporarily unavailable.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ),

            ...List.generate(trackingSteps.length, (index) {
              final stepStatus = trackingStatuses[index];
              final isCompleted = currentIndex >= index;
              final isCurrent = currentIndex == index;
              final isLast = index == trackingSteps.length - 1;
              final hasTimestamp = history.containsKey(stepStatus);

              final timestamp = hasTimestamp
                  ? _formatDate(history[stepStatus])
                  : 'Waiting for update';

              final Color stepColor =
                  isCompleted ? pink : Colors.grey.shade300;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? pink
                                  : Colors.grey.shade200,
                              border: Border.all(
                                color: stepColor,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check
                                  : Icons.circle_outlined,
                              color: isCompleted
                                  ? Colors.white
                                  : Colors.grey,
                              size: 15,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: index < currentIndex
                                    ? pink
                                    : Colors.grey.shade300,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trackingSteps[index],
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isCompleted
                                    ? Colors.black87
                                    : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              timestamp,
                              style: TextStyle(
                                color: hasTimestamp
                                    ? Colors.black54
                                    : Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            if (isCurrent)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  _trackingDescription(status),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: pink.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: pink,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _markAsDelivered(
    BuildContext context,
    String orderId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Order Received?'),
          content: const Text(
            'Please confirm only if you have already received your order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, I received it'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final orderRef = firestore.collection('orders').doc(orderId);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);

        if (!snapshot.exists) {
          throw Exception('Order not found.');
        }

        final data = snapshot.data()!;

        if (data['customerId'] != user.uid) {
          throw Exception('You are not allowed to update this order.');
        }

        final currentStatus =
            (data['orderStatus'] ?? 'pending').toString().toLowerCase();

        if (currentStatus != 'shipped') {
          throw Exception(
            'You can only confirm receipt after the seller ships your order.',
          );
        }

        transaction.update(orderRef, {
          'orderStatus': 'delivered',
          'updatedAt': FieldValue.serverTimestamp(),
          'deliveredAt': FieldValue.serverTimestamp(),
          'deliveredBy': 'customer',
        });

        // Save the Delivered event for both customer and seller tracking.
        final historyRef =
            orderRef.collection('statusHistory').doc();

        transaction.set(historyRef, {
          'status': 'delivered',
          'updatedBy': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });

        final sellerId = (data['sellerId'] ?? '').toString().trim();

        if (sellerId.isNotEmpty) {
          final notificationRef = firestore
              .collection('Users')
              .doc(sellerId)
              .collection('notifications')
              .doc();

          transaction.set(notificationRef, {
            'title': 'Order Delivered!',
            'body': 'The customer has confirmed receiving the order.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order successfully marked as Delivered!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update order: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final orderId = document.id;

    final status =
        (data['orderStatus'] ?? 'pending').toString().toLowerCase();

    final totalAmount = _toDouble(data['totalAmount']);
    final subtotal = _toDouble(
      data['subtotal'] ?? data['totalAmount'],
    );
    final shippingFee = _toDouble(data['shippingFee']);

    final shippingMethod =
        (data['shippingMethod'] ?? 'Not specified').toString();

    final deliveryAddress =
        (data['deliveryAddress'] ?? 'Not specified').toString();

    final paymentMethod =
        (data['paymentMethod'] ?? 'Not specified').toString();

    final createdAt = _formatDate(data['createdAt']);

    final List<dynamic> items =
        data['items'] is List ? data['items'] : [];

    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: pink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            _buildTracking(orderId, status, data['createdAt']),

            const Divider(height: 24),

            const Text(
              'Products Ordered',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),

            if (items.isEmpty)
              const Text('No product details available.')
            else
              ...items.map((item) {
                if (item is! Map) {
                  return const SizedBox.shrink();
                }

                final name = (item['name'] ?? 'Product').toString();
                final quantity = _toInt(item['quantity']);
                final price = _toDouble(item['price']);
                final size = (item['size'] ?? '').toString();
                final imageUrl = (item['imageUrl'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _productPlaceholder();
                                },
                              )
                            : _productPlaceholder(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Qty: $quantity'
                              '${size.isNotEmpty ? ' • Size: $size' : ''}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${(price * quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const Divider(height: 24),

            const Text(
              'Shipping Information',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),

            _infoRow(
              Icons.local_shipping_outlined,
              'Shipping Method',
              shippingMethod,
            ),

            if (shippingMethod == 'Express Shipping')
              const Padding(
                padding: EdgeInsets.only(left: 26, top: 4),
                child: Text(
                  'Estimated: 1–2 business days',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            _infoRow(
              Icons.location_on_outlined,
              'Delivery Address / Pickup',
              deliveryAddress,
            ),

            const Divider(height: 24),

            _amountRow('Subtotal', subtotal),
            const SizedBox(height: 6),
            _amountRow('Shipping Fee', shippingFee),
            const Divider(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '₱${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: pink,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Payment: $paymentMethod',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),

            Text(
              'Date: $createdAt',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),

            if (status == 'shipped') ...[
              const SizedBox(height: 16),
              _statusMessage(
                'Your order is in transit! Please confirm once you receive it.',
                Colors.deepPurple,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsDelivered(context, orderId),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Order Received'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],

            if (status == 'pending') ...[
              const SizedBox(height: 16),
              _statusMessage(
                'Your order has been placed. Waiting for seller confirmation.',
                Colors.orange,
              ),
            ],

            if (status == 'confirmed') ...[
              const SizedBox(height: 16),
              _statusMessage(
                'The seller has confirmed your order!',
                blue,
              ),
            ],

            if (status == 'processing') ...[
              const SizedBox(height: 16),
              _statusMessage(
                'Your seller is preparing your order.',
                blue,
              ),
            ],

            if (status == 'delivered') ...[
              const SizedBox(height: 16),
              _statusMessage(
                'You have confirmed receiving this order. Thank you!',
                Colors.green,
              ),
            ],

            if (status == 'rejected') ...[
              const SizedBox(height: 16),
              _statusMessage(
                'This order was rejected by the seller.',
                Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: pink),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
        Text(
          '₱${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _statusMessage(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _productPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      color: Colors.grey.shade100,
      child: const Icon(
        Icons.shopping_bag_outlined,
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(
              child: Text('Please log in to view your orders.'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load your orders.\n${snapshot.error}',
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

                final orders = snapshot.data?.docs.toList() ?? [];

                orders.sort((a, b) {
                  final aDate = a.data()['createdAt'];
                  final bDate = b.data()['createdAt'];

                  final aTime = aDate is Timestamp
                      ? aDate.millisecondsSinceEpoch
                      : 0;
                  final bTime = bDate is Timestamp
                      ? bDate.millisecondsSinceEpoch
                      : 0;

                  return bTime.compareTo(aTime);
                });

                if (orders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 65,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'You have no orders yet.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(context, orders[index]);
                  },
                );
              },
            ),
    );
  }
}
