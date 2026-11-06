
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'store_profile_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> productDoc;

  const ProductDetailsScreen({
    super.key,
    required this.productDoc,
  });

  @override
  State<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState
    extends State<ProductDetailsScreen> {
  final Color pink = const Color(0xFFD96B91);
  final Color blue = const Color(0xFF568BCB);

  String selectedSize = '';
  int quantity = 1;
  bool isLoading = false;

  Map<String, dynamic> get product =>
      widget.productDoc.data() ?? {};

  String get currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  String get productSellerId {
    final savedSellerId =
        (product['sellerId'] ?? '').toString();

    if (savedSellerId.isNotEmpty) {
      return savedSellerId;
    }

    return widget.productDoc.reference.parent.parent?.id ?? '';
  }

  bool get isOwnProduct {
    return currentUserId.isNotEmpty &&
        productSellerId.isNotEmpty &&
        currentUserId == productSellerId;
  }

  Color get primaryColor {
    final gender =
        (product['gender'] ?? '').toString().toLowerCase();

    return gender == 'male' || gender == 'men' ? blue : pink;
  }

  int get stock {
    final value = product['stock'];

    if (value is num) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  double get price {
    final value = product['price'];

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  List<String> get availableSizes {
    final sizes = product['sizes'];

    if (sizes is List && sizes.isNotEmpty) {
      return sizes.map((size) => size.toString()).toList();
    }

    return ['S', 'M', 'L', 'XL', 'XXL'];
  }

  @override
  void initState() {
    super.initState();

    final sizes = product['sizes'];

    if (sizes is List && sizes.isNotEmpty) {
      selectedSize = sizes.first.toString();
    } else {
      selectedSize = 'S';
    }
  }

  // OPEN STORE PROFILE
  void openStoreProfile() {
    final sellerId = productSellerId;

    final storeName =
        (product['storeName'] ?? 'Unknown Store').toString();

    if (sellerId.isEmpty) {
      showMessage('Store information is unavailable.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreProfileScreen(
          sellerId: sellerId,
          storeName: storeName,
        ),
      ),
    );
  }

  // ADD PRODUCT TO CART
  Future<void> addToCart() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Please log in first.');
      return;
    }

    // Prevent sellers from buying their own products.
    if (isOwnProduct) {
      showMessage(
        'You cannot purchase products from your own store.',
      );
      return;
    }

    if (stock <= 0) {
      showMessage('This product is out of stock.');
      return;
    }

    if (quantity > stock) {
      showMessage('Not enough stock available.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final cartCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');

      final productPath = widget.productDoc.reference.path;

      final cartId =
          '${productPath.replaceAll('/', '_')}_${selectedSize.toUpperCase()}';

      final cartRef = cartCollection.doc(cartId);

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          // Recheck the latest product information.
          final latestProduct =
              await transaction.get(widget.productDoc.reference);

          if (!latestProduct.exists) {
            throw Exception('This product is no longer available.');
          }

          final latestData = latestProduct.data() ?? {};

          if (latestData['isActive'] == false) {
            throw Exception('This product is no longer available.');
          }

          final latestSellerId =
              (latestData['sellerId'] ?? '').toString();

          final actualSellerId = latestSellerId.isNotEmpty
              ? latestSellerId
              : widget.productDoc.reference.parent.parent?.id ?? '';

          if (actualSellerId == user.uid) {
            throw Exception(
              'You cannot purchase products from your own store.',
            );
          }

          final latestStockValue = latestData['stock'];
          final latestStock = latestStockValue is num
              ? latestStockValue.toInt()
              : int.tryParse(latestStockValue.toString()) ?? 0;

          if (latestStock <= 0 || quantity > latestStock) {
            throw Exception('Not enough stock available.');
          }

          // Read existing cart item.
          final existing = await transaction.get(cartRef);

          final existingQuantity = existing.exists
              ? ((existing.data()?['quantity'] ?? 0) as num).toInt()
              : 0;

          if (existingQuantity + quantity > latestStock) {
            throw Exception('Not enough stock available.');
          }

          final latestPriceValue = latestData['price'];
          final latestPrice = latestPriceValue is num
              ? latestPriceValue.toDouble()
              : double.tryParse(latestPriceValue.toString()) ?? 0.0;

          final cartData = {
            'productId': widget.productDoc.id,
            'productPath': productPath,
            'name': latestData['name'] ?? 'Product',
            'description': latestData['description'] ?? '',
            'category': latestData['category'] ?? '',
            'gender': latestData['gender'] ?? '',
            'storeName': latestData['storeName'] ?? '',
            'sellerId': actualSellerId,
            'price': latestPrice,
            'stock': latestStock,
            'imageUrl': latestData['imageUrl'] ?? '',
            'size': selectedSize,
            'quantity': existingQuantity + quantity,
            'addedAt': FieldValue.serverTimestamp(),
          };

          transaction.set(cartRef, cartData);
        },
      );

      if (!mounted) return;

      showMessage('Product added to cart!');
    } catch (e) {
      if (!mounted) return;

      final errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      showMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (product['name'] ?? 'Product').toString();

    final description =
        (product['description'] ?? 'No description available.')
            .toString();

    final storeName =
        (product['storeName'] ?? 'Unknown Store').toString();

    final imageUrl = (product['imageUrl'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Product Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 350,
              color: Colors.white,
              child: imageUrl.isEmpty
                  ? const Icon(
                      Icons.image_not_supported_outlined,
                      size: 70,
                      color: Colors.grey,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image_outlined,
                          size: 70,
                          color: Colors.grey,
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CLICKABLE STORE NAME
                  GestureDetector(
                    onTap: openStoreProfile,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          storeName,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.open_in_new,
                          size: 13,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    '₱${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'Select Size',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableSizes.map((size) {
                      final isSelected = selectedSize == size;

                      return ChoiceChip(
                        label: Text(size),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedSize = size;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      IconButton(
                        onPressed: quantity > 1
                            ? () {
                                setState(() {
                                  quantity--;
                                });
                              }
                            : null,
                        icon: const Icon(
                          Icons.remove_circle_outline,
                        ),
                        color: primaryColor,
                      ),

                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        onPressed: quantity < stock
                            ? () {
                                setState(() {
                                  quantity++;
                                });
                              }
                            : null,
                        icon: const Icon(
                          Icons.add_circle_outline,
                        ),
                        color: primaryColor,
                      ),

                      const SizedBox(width: 10),

                      Text(
                        stock > 0
                            ? '$stock available'
                            : 'Out of stock',
                        style: TextStyle(
                          color: stock > 0
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  if (isOwnProduct) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is your own product. You cannot purchase it using this account.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: stock > 0 &&
                              !isLoading &&
                              !isOwnProduct
                          ? addToCart
                          : null,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.shopping_cart_outlined,
                            ),
                      label: Text(
                        isOwnProduct
                            ? 'Your Own Product'
                            : isLoading
                                ? 'Adding...'
                                : stock <= 0
                                    ? 'Out of Stock'
                                    : 'Add to Cart',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
