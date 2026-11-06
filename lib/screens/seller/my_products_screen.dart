
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'seller_orders_screen.dart';

class MyProductsScreen extends StatelessWidget {
  const MyProductsScreen({super.key});

  static const Color pink = Color(0xFFD96B91);
  static const Color background = Color(0xFFFFF8FA);
  static const Color darkPink = Color(0xFF79515F);

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get productsRef {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .collection('products');
  }

  DocumentReference<Map<String, dynamic>> get sellerRef {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(uid);
  }

  Future<void> editShopName(
    BuildContext context,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Shop Name'),
          content: TextField(
            controller: controller,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Shop Name',
              hintText: 'Enter your shop name',
              prefixIcon: Icon(Icons.store, color: pink),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: pink),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: darkPink),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) return;

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null || newName.trim().isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;

      await sellerRef.update({
        'storeName': newName.trim(),
      });

      final products = await productsRef.get();

      const int batchLimit = 450;

      for (var i = 0; i < products.docs.length; i += batchLimit) {
        final batch = firestore.batch();

        final end = (i + batchLimit < products.docs.length)
            ? i + batchLimit
            : products.docs.length;

        for (var j = i; j < end; j++) {
          batch.update(products.docs[j].reference, {
            'storeName': newName.trim(),
          });
        }

        await batch.commit();
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop name updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update shop name: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteProduct(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final productName = doc.data()['name']?.toString() ?? 'this product';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: Text(
            'Are you sure you want to delete "$productName"? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: darkPink),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await productsRef.doc(doc.id).delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editProduct(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProductScreen(
          productId: doc.id,
          productData: doc.data(),
        ),
      ),
    );
  }

  void openOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SellerOrdersScreen(),
      ),
    );
  }

  void showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature will be available once orders are implemented.',
        ),
        backgroundColor: pink,
      ),
    );
  }

  Widget statCard({
    required IconData icon,
    required String title,
    required String value,
    Color iconColor = pink,
  }) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 27),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: darkPink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: darkPink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkPink,
        ),
      ),
    );
  }

  Widget menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFE8F0),
          child: Icon(icon, color: pink),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: darkPink,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: pink,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget productCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final name = data['name'] ?? 'Unnamed Product';
    final price = data['price'] ?? 0;
    final stock = data['stock'] ?? 0;
    final imageUrl = data['imageUrl'] ?? '';
    final isActive = data['isActive'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.toString().isNotEmpty
                      ? Image.network(
                          imageUrl.toString(),
                          width: 85,
                          height: 85,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) {
                            return Container(
                              width: 85,
                              height: 85,
                              color: const Color(0xFFFFE8F0),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: pink,
                                size: 35,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 85,
                          height: 85,
                          color: const Color(0xFFFFE8F0),
                          child: const Icon(
                            Icons.image_outlined,
                            color: pink,
                            size: 35,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: darkPink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('Price: ₱$price'),
                      Text('Stock: $stock'),
                      const SizedBox(height: 5),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => editProduct(context, doc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: pink,
                      side: const BorderSide(color: pink),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => deleteProduct(context, doc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: sellerRef.snapshots(),
        builder: (context, sellerSnapshot) {
          final sellerData = sellerSnapshot.data?.data();

          final shopName = sellerData?['storeName'] ?? 'My Shop';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: productsRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Something went wrong.'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: pink),
                );
              }

              final products = snapshot.data?.docs ?? [];
              final totalProducts = products.length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 27,
                            backgroundColor: Color(0xFFFFE8F0),
                            child: Icon(
                              Icons.store,
                              color: pink,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'My Shop',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  shopName.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 19,
                                    color: darkPink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit Shop Name',
                            onPressed: () => editShopName(
                              context,
                              shopName.toString(),
                            ),
                            icon: const Icon(Icons.edit, color: pink),
                          ),
                        ],
                      ),
                    ),
                  ),

                  sectionTitle('Store Overview'),

                  Row(
                    children: [
                      statCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'Total Products',
                        value: totalProducts.toString(),
                      ),
                      const SizedBox(width: 10),
                      statCard(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Total Orders',
                        value: '0',
                        iconColor: Colors.blue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  sectionTitle('Product Management'),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add New Product',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddProductScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  menuCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Orders Received',
                    subtitle: 'View and manage customer orders',
                    onTap: () => openOrders(context),
                  ),

                  menuCard(
                    icon: Icons.analytics_outlined,
                    title: 'Sales Analytics',
                    subtitle: 'View your shop performance',
                    onTap: () => showComingSoon(context, 'Sales Analytics'),
                  ),

                  menuCard(
                    icon: Icons.trending_up,
                    title: 'Most Purchased Products',
                    subtitle: 'See which products sell the most',
                    onTap: () => showComingSoon(
                      context,
                      'Most Purchased Products',
                    ),
                  ),

                  sectionTitle('Manage Products'),

                  if (products.isEmpty)
                    const Card(
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(25),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 55,
                              color: pink,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No products yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: darkPink,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Add your first product to your shop.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: darkPink),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...products.map(
                      (product) => productCard(context, product),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
