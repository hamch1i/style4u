import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_details_screen.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final bool showAppBar;

  const CartScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const Color pink = Color(0xFFD96B91);

  final Set<String> selectedItems = {};

  CollectionReference<Map<String, dynamic>> get cartCollection {
    final user = FirebaseAuth.instance.currentUser!;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart');
  }

  double getPrice(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> updateQuantity(
    DocumentSnapshot<Map<String, dynamic>> item,
    int change,
  ) async {
    final data = item.data();
    if (data == null) return;

    final currentQuantity =
        (data['quantity'] as num?)?.toInt() ?? 1;

    final newQuantity = currentQuantity + change;

    if (newQuantity <= 0) {
      setState(() {
        selectedItems.remove(item.id);
      });

      await item.reference.delete();
    } else {
      final stock = (data['stock'] as num?)?.toInt() ?? 0;

      if (newQuantity > stock) return;

      await item.reference.update({
        'quantity': newQuantity,
      });
    }
  }

  Future<void> openProductDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final productPath = data['productPath']?.toString();

    if (productPath == null || productPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product details are unavailable.'),
        ),
      );
      return;
    }

    try {
      final productDoc = await FirebaseFirestore.instance
          .doc(productPath)
          .get();

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
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open product details.'),
        ),
      );
    }
  }

  void toggleSelection(String itemId, bool? value) {
    setState(() {
      if (value == true) {
        selectedItems.add(itemId);
      } else {
        selectedItems.remove(itemId);
      }
    });
  }

  void toggleSelectAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    bool? value,
  ) {
    setState(() {
      if (value == true) {
        selectedItems.addAll(items.map((item) => item.id));
      } else {
        selectedItems.clear();
      }
    });
  }

  void proceedToCheckout(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    double total,
  ) {
    final selectedCartItems = items
        .where((item) => selectedItems.contains(item.id))
        .toList();

    if (selectedCartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select products to checkout.'),
        ),
      );
      return;
    }

    final checkoutItems = selectedCartItems.map((item) {
      return {
        ...item.data(),
        'cartItemId': item.id,
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: checkoutItems,
          total: total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view your cart.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'My Cart',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: pink,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load your cart.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: pink,
              ),
            );
          }

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
            selectedItems.clear();

            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 75,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your cart is empty!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Start adding products you love.'),
                ],
              ),
            );
          }

          final existingIds = items.map((item) => item.id).toSet();
          selectedItems.removeWhere(
            (id) => !existingIds.contains(id),
          );

          final selectedCartItems = items
              .where((item) => selectedItems.contains(item.id))
              .toList();

          double selectedTotal = 0;

          for (final item in selectedCartItems) {
            final data = item.data();
            final price = getPrice(data['price']);
            final quantity =
                (data['quantity'] as num?)?.toInt() ?? 1;

            selectedTotal += price * quantity;
          }

          final allSelected =
              items.isNotEmpty && selectedItems.length == items.length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      color: Colors.white,
                      elevation: 1,
                      child: CheckboxListTile(
                        value: allSelected,
                        onChanged: (value) =>
                            toggleSelectAll(items, value),
                        activeColor: pink,
                        controlAffinity:
                            ListTileControlAffinity.leading,
                        title: const Text(
                          'Select All',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${selectedItems.length} of ${items.length} products selected',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...items.map((item) {
                      final data = item.data();

                      final name =
                          (data['name'] ?? 'Unnamed Product').toString();

                      final store =
                          (data['storeName'] ?? 'Unknown Store').toString();

                      final imageUrl =
                          (data['imageUrl'] ?? '').toString();

                      final price = getPrice(data['price']);

                      final quantity =
                          (data['quantity'] as num?)?.toInt() ?? 1;

                      final size = (data['size'] ?? '').toString();

                      final subtotal = price * quantity;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: selectedItems.contains(item.id),
                                onChanged: (value) =>
                                    toggleSelection(item.id, value),
                                activeColor: pink,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              openProductDetails(context, data),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: imageUrl.isEmpty
                                                ? Container(
                                                    width: 85,
                                                    height: 95,
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(
                                                      Icons.image,
                                                    ),
                                                  )
                                                : Image.network(
                                                    imageUrl,
                                                    width: 85,
                                                    height: 95,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Container(
                                                        width: 85,
                                                        height: 95,
                                                        color:
                                                            Colors.grey.shade200,
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () =>
                                                openProductDetails(context, data),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                                bottom: 5,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    store,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: pink.withValues(
                                                        alpha: 0.10,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(7),
                                                    ),
                                                    child: Text(
                                                      size.isNotEmpty
                                                          ? 'Size: $size'
                                                          : 'Size: Not selected',
                                                      style: const TextStyle(
                                                        color: pink,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 7),
                                                  Text(
                                                    '₱${price.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: pink,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    'Subtotal: ₱${subtotal.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade700,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Spacer(),
                                        IconButton(
                                          onPressed: () =>
                                              updateQuantity(item, -1),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                          color: pink,
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                        Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              updateQuantity(item, 1),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          color: pink,
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  setState(() {
                                    selectedItems.remove(item.id);
                                  });
                                  await item.reference.delete();
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                tooltip: 'Remove item',
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Selected Items Total:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₱${selectedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: pink,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${selectedCartItems.length} product(s) selected',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedCartItems.isEmpty
                            ? null
                            : () => proceedToCheckout(
                                  context,
                                  items,
                                  selectedTotal,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pink,
                          disabledBackgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Proceed to Checkout',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
