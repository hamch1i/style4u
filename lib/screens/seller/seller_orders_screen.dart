
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  static const Color pink = Color(0xFFD96B91);
  static const Color blue = Color(0xFF4A90E2);

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

    return 'Date unavailable';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Order Placed';
      case 'confirmed':
        return 'Order Confirmed';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.purple;
      case 'processing':
        return blue;
      case 'shipped':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateOrderStatus({
    required BuildContext context,
    required String orderId,
    required String newStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final orderRef = firestore.collection('orders').doc(orderId);

      await firestore.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Order not found.');
        }

        final orderData = orderSnapshot.data()!;

        if (orderData['sellerId'] != user.uid) {
          throw Exception('You are not allowed to update this order.');
        }

        final currentStatus =
            (orderData['orderStatus'] ?? 'pending').toString();

        final allowedTransitions = {
          'pending': ['confirmed', 'rejected'],
          'confirmed': ['processing'],
          'processing': ['shipped'],
        };

        if (!(allowedTransitions[currentStatus]?.contains(newStatus) ??
            false)) {
          throw Exception('This order status cannot be changed.');
        }

        final List<dynamic> items =
            orderData['items'] is List ? orderData['items'] : [];

        // Read product documents before performing transaction writes.
        final productUpdates = <Map<String, dynamic>>[];

        if (newStatus == 'rejected') {
          for (final item in items) {
            if (item is! Map) continue;

            final path = (item['productPath'] ?? '').toString().trim();
            final quantity = _toInt(item['quantity']);

            if (path.isEmpty || quantity <= 0) continue;

            final productRef = firestore.doc(path);
            final productSnapshot = await transaction.get(productRef);

            if (productSnapshot.exists) {
              productUpdates.add({
                'ref': productRef,
                'stock': _toInt(productSnapshot.data()?['stock']),
                'quantity': quantity,
              });
            }
          }
        }

        // Restore reserved stock if the seller rejects the order.
        for (final product in productUpdates) {
          final productRef =
              product['ref'] as DocumentReference<Map<String, dynamic>>;

          transaction.update(productRef, {
            'stock': product['stock'] + product['quantity'],
          });
        }

        // Update the main order document.
        transaction.update(orderRef, {
          'orderStatus': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add a timestamped tracking history entry.
        final historyRef =
            orderRef.collection('statusHistory').doc();

        transaction.set(historyRef, {
          'status': newStatus,
          'updatedBy': 'seller',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Notify the customer about the status change.
        final customerId =
            (orderData['customerId'] ?? '').toString().trim();

        if (customerId.isNotEmpty) {
          final notificationRef = firestore
              .collection('users')
              .doc(customerId)
              .collection('notifications')
              .doc();

          String title;
          String body;

          switch (newStatus) {
            case 'confirmed':
              title = 'Order Confirmed!';
              body = 'The seller has confirmed your order.';
              break;
            case 'processing':
              title = 'Order Processing';
              body = 'The seller is now preparing your order.';
              break;
            case 'shipped':
              title = 'Your Order Has Shipped!';
              body =
                  'Your order has been marked as shipped. Confirm receipt when it arrives.';
              break;
            case 'rejected':
              title = 'Order Rejected';
              body =
                  'The seller could not accept your order. Your reserved product stock has been restored.';
              break;
            default:
              title = 'Order Updated';
              body = 'Your order status has been updated.';
          }

          transaction.set(notificationRef, {
            'title': title,
            'body': body,
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!context.mounted) return;

      String successMessage;

      switch (newStatus) {
        case 'confirmed':
          successMessage = 'Order confirmed. Customer has been notified.';
          break;
        case 'processing':
          successMessage = 'Order is now being processed.';
          break;
        case 'shipped':
          successMessage = 'Order marked as shipped.';
          break;
        default:
          successMessage = 'Order rejected. Reserved stock restored.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
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

  Future<void> _confirmAction({
    required BuildContext context,
    required String orderId,
    required String newStatus,
  }) async {
    String title;
    String message;

    switch (newStatus) {
      case 'confirmed':
        title = 'Confirm Order?';
        message = 'Do you want to confirm this customer order?';
        break;
      case 'processing':
        title = 'Start Processing?';
        message =
            'Have you confirmed that you are ready to prepare this order?';
        break;
      case 'shipped':
        title = 'Mark as Shipped?';
        message = 'Confirm that this order has been shipped.';
        break;
      case 'rejected':
        title = 'Reject Order?';
        message =
            'Are you sure you want to reject this order? Reserved product stock will be restored.';
        break;
      default:
        return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    newStatus == 'rejected' ? Colors.red : pink,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await _updateOrderStatus(
        context: context,
        orderId: orderId,
        newStatus: newStatus,
      );
    }
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

  Widget _buildTrackingHistory(String orderId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('statusHistory')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load tracking history.',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: CircularProgressIndicator(
                color: pink,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final history = snapshot.data?.docs ?? [];

        if (history.isEmpty) {
          return const Text(
            'No tracking history available.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          );
        }

        return Column(
          children: List.generate(history.length, (index) {
            final entry = history[index].data();
            final status = (entry['status'] ?? '').toString();
            final timestamp = _formatDate(entry['createdAt']);
            final isLast = index == history.length - 1;
            final color = _statusColor(status);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 37,
                          color: Colors.grey.shade300,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          timestamp,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final orderId = document.id;
    final customerName =
        (data['customerName'] ?? 'Customer').toString();
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

            const Text(
              'Customer Name',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              customerName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 14),
            const Text(
              'Products Ordered',
              style: TextStyle(color: Colors.black54, fontSize: 12),
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),

            const Divider(height: 24),

            const Text(
              'Shipping Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: pink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shipping Method: $shippingMethod',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: pink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delivery Address / Pickup: $deliveryAddress',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
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

            const Divider(height: 24),

            // ORDER TRACKING HISTORY
            const Row(
              children: [
                Icon(
                  Icons.track_changes,
                  color: pink,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Order Tracking History',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildTrackingHistory(orderId),

            const SizedBox(height: 8),

            if (status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmAction(
                        context: context,
                        orderId: orderId,
                        newStatus: 'rejected',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmAction(
                        context: context,
                        orderId: orderId,
                        newStatus: 'confirmed',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Confirm Order'),
                    ),
                  ),
                ],
              ),

            if (status == 'confirmed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmAction(
                    context: context,
                    orderId: orderId,
                    newStatus: 'processing',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Start Processing'),
                ),
              ),

            if (status == 'processing')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAction(
                    context: context,
                    orderId: orderId,
                    newStatus: 'shipped',
                  ),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Mark as Shipped'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),

            if (status == 'shipped')
              const Text(
                'Waiting for the customer to confirm receipt.',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),

            if (status == 'delivered' || status == 'rejected')
              const Text(
                'This order is already finalized.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        backgroundColor: pink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Orders Received',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text('Please log in to view your orders.'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('sellerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load orders.\n${snapshot.error}',
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
                          color: pink,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No orders yet.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Customer orders for your shop will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final pendingCount = orders
                    .where((doc) =>
                        doc.data()['orderStatus'] == 'pending')
                    .length;

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      decoration: BoxDecoration(
                        color: pink.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_actions,
                            color: pink,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pending Orders',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$pendingCount order(s) waiting for your approval',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          return _buildOrderCard(
                            context,
                            orders[index],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
