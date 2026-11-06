
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'product_details_screen.dart';

class WishlistService {
  static CollectionReference<Map<String, dynamic>>? get wishlist {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wishlist');
  }

  static Future<bool> isSaved(String productId) async {
    final collection = wishlist;
    if (collection == null) return false;

    final doc = await collection.doc(productId).get();
    return doc.exists;
  }

  static Future<void> toggleProduct({
    required DocumentSnapshot<Map<String, dynamic>> productDoc,
  }) async {
    final collection = wishlist;

    if (collection == null) {
      throw Exception('Please log in to use Wishlist.');
    }

    final productReference = collection.doc(productDoc.id);
    final savedProduct = await productReference.get();

    if (savedProduct.exists) {
      await productReference.delete();
      return;
    }

    final product = productDoc.data() ?? {};

    final sellerIdFromData =
        (product['sellerId'] ?? '').toString().trim();

    final sellerIdFromPath =
        productDoc.reference.parent.parent?.id ?? '';

    await productReference.set({
      'productId': productDoc.id,
      'productPath': productDoc.reference.path,
      'sellerId': sellerIdFromData.isNotEmpty
          ? sellerIdFromData
          : sellerIdFromPath,
      'name': (product['name'] ?? 'Unnamed Product').toString(),
      'imageUrl': (product['imageUrl'] ?? '').toString(),
      'storeName': (product['storeName'] ?? 'Unknown Store').toString(),
      'price': product['price'] ?? 0,
      'category': (product['category'] ?? '').toString(),
      'gender': (product['gender'] ?? '').toString(),
      'addedAt': FieldValue.serverTimestamp(),
    });
  }
}

class WishlistButton extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> productDoc;
  final Color color;

  const WishlistButton({
    super.key,
    required this.productDoc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final wishlistReference = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wishlist')
        .doc(productDoc.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: wishlistReference.snapshots(),
      builder: (context, snapshot) {
        final isSaved = snapshot.data?.exists ?? false;

        return Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              try {
                await WishlistService.toggleProduct(
                  productDoc: productDoc,
                );

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isSaved
                          ? 'Removed from Wishlist'
                          : 'Added to Wishlist',
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to update Wishlist: $error'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                size: 19,
                color: isSaved ? Colors.red : color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class WishlistHeaderButton extends StatelessWidget {
  final Color color;

  const WishlistHeaderButton({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final wishlistReference = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wishlist');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: wishlistReference.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return IconButton(
          tooltip: 'Wishlist',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WishlistScreen(
                  primaryColor: color,
                ),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.favorite_border,
                color: color,
                size: 27,
              ),
              if (count > 0)
                Positioned(
                  right: -7,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class WishlistScreen extends StatelessWidget {
  final Color primaryColor;

  const WishlistScreen({
    super.key,
    required this.primaryColor,
  });

  Future<void> openProduct(
    BuildContext context,
    String productPath,
  ) async {
    try {
      final productReference =
          FirebaseFirestore.instance.doc(productPath);

      final productDoc = await productReference.get();

      if (!context.mounted) return;

      if (!productDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This product is no longer available.'),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailsScreen(
            productDoc: productDoc,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open product: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = WishlistService.wishlist;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('My Wishlist'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: collection == null
          ? const Center(
              child: Text('Please log in to view your Wishlist.'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: collection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load Wishlist.'),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
                  );
                }

                final products = snapshot.data?.docs ?? [];

                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 75,
                            color: primaryColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Your Wishlist is empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Tap the heart on a product to save it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data();

                    final name =
                        (data['name'] ?? 'Unnamed Product').toString();

                    final imageUrl =
                        (data['imageUrl'] ?? '').toString();

                    final storeName =
                        (data['storeName'] ?? 'Unknown Store').toString();

                    final productPath =
                        (data['productPath'] ?? '').toString();

                    final price = data['price'] is num
                        ? (data['price'] as num).toDouble()
                        : double.tryParse(
                              (data['price'] ?? '0').toString(),
                            ) ??
                            0.0;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GestureDetector(
                                  onTap: productPath.isEmpty
                                      ? null
                                      : () => openProduct(
                                            context,
                                            productPath,
                                          ),
                                  child: imageUrl.isEmpty
                                      ? Container(
                                          color: Colors.grey.shade100,
                                          child: const Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 45,
                                            color: Colors.grey,
                                          ),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              color: Colors.grey.shade100,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                size: 45,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Remove from Wishlist',
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      padding: const EdgeInsets.all(7),
                                      onPressed: () async {
                                        await doc.reference.delete();
                                      },
                                      icon: const Icon(
                                        Icons.favorite,
                                        color: Colors.red,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  storeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '₱${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: productPath.isEmpty
                                        ? null
                                        : () => openProduct(
                                              context,
                                              productPath,
                                            ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      'View Product',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

