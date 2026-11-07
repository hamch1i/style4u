import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_seller_details_screen.dart';

class AdminSellerManagementScreen extends StatelessWidget {
  const AdminSellerManagementScreen({super.key});

  static const Color pink = Color(0xFFD96B91);

  Future<void> _toggleShopStatus(
    BuildContext context,
    String sellerId,
    bool currentlyActive,
  ) async {
    final action = currentlyActive ? 'deactivate' : 'reactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            currentlyActive ? 'Deactivate Shop?' : 'Reactivate Shop?',
          ),
          content: Text(
            currentlyActive
                ? 'This seller shop will be deactivated. The seller will not be able to operate the shop while it is inactive.'
                : 'This seller shop will be reactivated.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    currentlyActive ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: Text(
                currentlyActive ? 'Deactivate' : 'Reactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(sellerId)
          .update({
        'isShopActive': !currentlyActive,
        'shopStatusUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shop successfully $action${action == 'deactivate' ? 'd.' : 'd.'}'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update shop: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seller Management',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'View seller accounts and manage shop activation.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .where('role', isEqualTo: 'seller')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading sellers.'),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final sellers = snapshot.data?.docs ?? [];

                if (sellers.isEmpty) {
                  return const Center(
                    child: Text('No registered sellers found.'),
                  );
                }

                return ListView.separated(
                  itemCount: sellers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final seller = sellers[index];
                    final data =
                        seller.data() as Map<String, dynamic>;

                    final sellerId = seller.id;
                    final shopName =
                        (data['storeName'] ??
                                data['shopName'] ??
                                'Unnamed Shop')
                            .toString();

                    final ownerName =
                        (data['name'] ??
                                data['fullName'] ??
                                'Seller')
                            .toString();

                    final email =
                        (data['email'] ?? 'No email').toString();

                    final logo =
                        (data['shopLogo'] ?? '').toString();

                    final isActive = data['isShopActive'] ?? true;

                    final sellerStatus =
                        (data['sellerStatus'] ?? 'pending')
                            .toString();

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: logo.isNotEmpty
                                ? Image.network(
                                    logo,
                                    width: 65,
                                    height: 65,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _shopPlaceholder(),
                                  )
                                : _shopPlaceholder(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shopName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Owner: $ownerName'),
                                Text(email),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _statusChip(
                                      isActive ? 'ACTIVE' : 'INACTIVE',
                                      isActive
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    _statusChip(
                                      sellerStatus.toUpperCase(),
                                      Colors.blueGrey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminSellerDetailsScreen(
                                        sellerId: sellerId,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('View Details'),
                              ),
                              const SizedBox(height: 7),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isActive ? Colors.red : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _toggleShopStatus(
                                  context,
                                  sellerId,
                                  isActive,
                                ),
                                child: Text(
                                  isActive
                                      ? 'Deactivate Shop'
                                      : 'Reactivate Shop',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _shopPlaceholder() {
    return Container(
      width: 65,
      height: 65,
      color: pink.withValues(alpha: 0.12),
      child: const Icon(
        Icons.store,
        color: pink,
        size: 30,
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}