
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../chat/chat_screen.dart';
import 'product_details_screen.dart';

class StoreProfileScreen extends StatelessWidget {
  final String sellerId;
  final String storeName;

  const StoreProfileScreen({
    super.key,
    required this.sellerId,
    required this.storeName,
  });

  static const Color pink = Color(0xFFD96B91);
  static const Color background = Color(0xFFFFF8FA);
  static const Color darkPink = Color(0xFF79515F);

  CollectionReference<Map<String, dynamic>> get productsRef {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(sellerId)
        .collection('products');
  }

  Future<void> openChat(
    BuildContext context,
    String currentStoreName,
  ) async {
    try {
      final chatId = await ChatService.createOrGetChat(
        sellerId: sellerId,
        storeName: currentStoreName,
      );

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            chatId: chatId,
            currentUserRole: 'user',
            otherUserId: sellerId,
            otherUserName: currentStoreName,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void openProductDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> productDoc,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          productDoc: productDoc,
        ),
      ),
    );
  }

  double getPrice(Map<String, dynamic> data) {
    final value = data['price'] ?? 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  int getSalesCount(Map<String, dynamic> data) {
    final value = data['soldCount'] ??
        data['totalSold'] ??
        data['salesCount'] ??
        0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  DateTime getCreatedDate(Map<String, dynamic> data) {
    final value = data['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime(2000);
  }

  Widget productCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> productDoc,
  ) {
    final data = productDoc.data();

    final name = data['name']?.toString() ?? 'Unnamed Product';
    final price = getPrice(data);
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';

    return Card(
      color: Colors.white,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => openProductDetails(context, productDoc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const ColoredBox(
                            color: Color(0xFFFFE8F0),
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: pink,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      )
                    : const ColoredBox(
                        color: Color(0xFFFFE8F0),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: pink,
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkPink,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${price.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: pink,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  const Text(
                    'View Details',
                    style: TextStyle(
                      color: pink,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState({
    String title = 'No products available',
    String message = 'This shop has no active products yet.',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 60,
              color: pink,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkPink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProductGrid(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products, {
    bool shrinkWrap = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final crossAxisCount = width >= 900
            ? 4
            : width >= 600
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: const EdgeInsets.all(14),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, index) {
            return productCard(context, products[index]);
          },
        );
      },
    );
  }

  Widget buildHomeTab(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    String currentStoreName,
  ) {
    if (products.isEmpty) {
      return buildEmptyState();
    }

    final featuredProducts = products.take(4).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 5),
            child: Text(
              'Welcome to $currentStoreName!',
              style: const TextStyle(
                color: darkPink,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Explore products from this shop.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Featured Products',
              style: TextStyle(
                color: darkPink,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          buildProductGrid(
            context,
            featuredProducts,
            shrinkWrap: true,
          ),
        ],
      ),
    );
  }

  Widget buildTabGrid(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products, {
    String emptyTitle = 'No products available',
    String emptyMessage = 'This shop has no active products yet.',
  }) {
    if (products.isEmpty) {
      return buildEmptyState(
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return buildProductGrid(context, products);
  }

  @override
  Widget build(BuildContext context) {
    if (sellerId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text('Store Profile'),
          backgroundColor: pink,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Store information is unavailable.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text('Store Profile'),
          backgroundColor: pink,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(sellerId)
              .snapshots(),
          builder: (context, sellerSnapshot) {
            final sellerData = sellerSnapshot.data?.data();

            final currentStoreName =
                sellerData?['storeName']?.toString().trim().isNotEmpty == true
                    ? sellerData!['storeName'].toString()
                    : storeName;

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Color(0xFFFFE8F0),
                        child: Icon(
                          Icons.store,
                          color: pink,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentStoreName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkPink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Shop products and collections',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            openChat(context, currentStoreName);
                          },
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 19,
                          ),
                          label: const Text(
                            'Chat with Seller',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: pink,
                            side: const BorderSide(
                              color: pink,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // STORE TABS
                Container(
                  color: Colors.white,
                  child: const TabBar(
                    isScrollable: true,
                    labelColor: pink,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: pink,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(text: 'Home'),
                      Tab(text: 'All Products'),
                      Tab(text: 'Best Seller'),
                      Tab(text: 'New Arrival'),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: productsRef
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                    builder: (context, productSnapshot) {
                      if (productSnapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Unable to load store products. Please try again.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (productSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !productSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: pink,
                          ),
                        );
                      }

                      final products =
                          productSnapshot.data?.docs ?? [];

                      final newestProducts = [...products]
                        ..sort((a, b) {
                          return getCreatedDate(b.data()).compareTo(
                            getCreatedDate(a.data()),
                          );
                        });

                      final bestSellerProducts = [...products]
                        ..sort((a, b) {
                          return getSalesCount(b.data()).compareTo(
                            getSalesCount(a.data()),
                          );
                        });

                      final hasSalesData = products.any(
                        (product) => getSalesCount(product.data()) > 0,
                      );

                      return TabBarView(
                        children: [
                          // HOME
                          buildHomeTab(
                            context,
                            newestProducts,
                            currentStoreName,
                          ),

                          // ALL PRODUCTS
                          buildTabGrid(
                            context,
                            newestProducts,
                          ),

                          // BEST SELLER
                          hasSalesData
                              ? buildTabGrid(
                                  context,
                                  bestSellerProducts
                                      .where(
                                        (product) =>
                                            getSalesCount(product.data()) > 0,
                                      )
                                      .toList(),
                                )
                              : buildEmptyState(
                                  title: 'No best sellers yet',
                                  message:
                                      'Products will appear here once sales data is available.',
                                ),

                          // NEW ARRIVAL
                          buildTabGrid(
                            context,
                            newestProducts,
                            emptyTitle: 'No new arrivals yet',
                            emptyMessage:
                                'New products from this shop will appear here.',
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
