import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSellerDetailsScreen extends StatelessWidget {
  final String sellerId;

  const AdminSellerDetailsScreen({
    super.key,
    required this.sellerId,
  });

  static const Color pink = Color(0xFFD96B91);

  Widget _info(String label, dynamic value) {
    final displayValue =
        value == null || value.toString().trim().isEmpty
            ? 'Not provided'
            : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text('Seller Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .doc(sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load seller details.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child: Text('Seller account not found.'),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>;

          final shopName =
              data['storeName'] ?? data['shopName'] ?? 'Unnamed Shop';

          final logo = (data['shopLogo'] ?? '').toString();
          final banner = (data['shopBanner'] ?? '').toString();

          final isActive = data['isShopActive'] ?? true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          if (banner.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                              child: Image.network(
                                banner,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox(height: 30),
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (logo.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                logo,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _placeholder(),
                              ),
                            )
                          else
                            _placeholder(),
                          const SizedBox(height: 14),
                          Text(
                            shopName.toString(),
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isActive
                                  ? 'ACTIVE SHOP'
                                  : 'DEACTIVATED SHOP',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _section(
                      'Seller Account Information',
                      [
                        _info('Seller Name', data['name'] ??
                            data['fullName']),
                        _info('Email', data['email']),
                        _info('Seller Status', data['sellerStatus']),
                        _info('Account ID', sellerId),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _section(
                      'Shop Information',
                      [
                        _info('Shop Name', shopName),
                        _info('Description', data['shopDescription']),
                        _info('Contact Number', data['shopContact']),
                        _info('Shop Address', data['shopAddress']),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Shop information is managed by the seller. '
                      'The administrator can only view these details '
                      'and control shop activation.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: pink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(
        Icons.store,
        color: pink,
        size: 45,
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 25),
          ...children,
        ],
      ),
    );
  }
}