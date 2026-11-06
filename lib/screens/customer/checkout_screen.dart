
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color pink = Color(0xFFD96B91);
  static const double expressShippingFee = 150.00;

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final gcashReferenceController = TextEditingController();

  String paymentMethod = 'COD';
  String shippingMethod = 'Standard Shipping';

  bool isPlacingOrder = false;

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

  int getQuantity(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String getSellerIdFromProductPath(String productPath) {
    final parts = productPath.split('/');

    if (parts.length != 4 ||
        parts[0] != 'Users' ||
        parts[2] != 'products' ||
        parts[1].isEmpty ||
        parts[3].isEmpty) {
      throw Exception('Invalid product information in your cart.');
    }

    return parts[1];
  }

  int get checkoutSellerCount {
    final sellerIds = <String>{};

    for (final item in widget.cartItems) {
      final sellerId = (item['sellerId'] ?? '').toString();

      if (sellerId.isNotEmpty) {
        sellerIds.add(sellerId);
        continue;
      }

      final productPath = (item['productPath'] ?? '').toString();

      if (productPath.isNotEmpty) {
        try {
          sellerIds.add(getSellerIdFromProductPath(productPath));
        } catch (_) {}
      }
    }

    return sellerIds.isEmpty ? 1 : sellerIds.length;
  }

  double get shippingFee {
    if (shippingMethod == 'Express Shipping') {
      return expressShippingFee * checkoutSellerCount;
    }

    return 0.0;
  }

  double get grandTotal => widget.total + shippingFee;

  bool get isStorePickup => shippingMethod == 'Store Pickup';

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    gcashReferenceController.dispose();
    super.dispose();
  }

  bool validateRequiredFields() {
    bool isValid = true;

    if (nameController.text.trim().isEmpty) {
      isValid = false;
    }

    final phone = phoneController.text.trim();

    if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
      isValid = false;
    }

    if (!isStorePickup && addressController.text.trim().isEmpty) {
      isValid = false;
    }

    if (paymentMethod == 'GCash' &&
        gcashReferenceController.text.trim().isEmpty) {
      isValid = false;
    }

    return isValid;
  }

  Future<void> placeOrder() async {
    if (isPlacingOrder) return;

    if (!validateRequiredFields()) {
      _formKey.currentState!.validate();
      showMessage('Please complete all required fields.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Please log in before checking out.');
      return;
    }

    final selectedCartIds = widget.cartItems
        .map((item) => (item['cartItemId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (selectedCartIds.isEmpty) {
      showMessage(
        'No selected products found. Please return to your cart.',
      );
      return;
    }

    setState(() {
      isPlacingOrder = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final customerName = nameController.text.trim();
      final customerPhone = phoneController.text.trim();

      final deliveryAddress = isStorePickup
          ? 'Store Pickup'
          : addressController.text.trim();

      final gcashReference = gcashReferenceController.text.trim();

      final selectedCartReferences = selectedCartIds.map((id) {
        return cartCollection.doc(id);
      }).toList();

      final result =
          await firestore.runTransaction<Map<String, dynamic>>(
        (transaction) async {
          final Map<String, Map<String, dynamic>> selectedCartData = {};
          final Map<String, String> productPaths = {};
          final Map<String, int> productQuantities = {};

          // READ CART DOCUMENTS.
          for (final cartRef in selectedCartReferences) {
            final cartSnapshot = await transaction.get(cartRef);

            if (!cartSnapshot.exists) {
              throw Exception(
                'One of your selected cart items is no longer available. '
                'Please return to your cart and try again.',
              );
            }

            final data = cartSnapshot.data() ?? {};

            final productPath =
                (data['productPath'] ?? '').toString();

            if (productPath.isEmpty) {
              throw Exception(
                'Some selected products have incomplete information.',
              );
            }

            final sellerId = getSellerIdFromProductPath(productPath);

            if (sellerId == user.uid) {
              throw Exception(
                'You cannot checkout products from your own store.',
              );
            }

            final cartSellerId =
                (data['sellerId'] ?? '').toString();

            if (cartSellerId.isNotEmpty &&
                cartSellerId != sellerId) {
              throw Exception(
                'Invalid seller information for one of your products.',
              );
            }

            final quantity = getQuantity(data['quantity']);

            if (quantity <= 0) {
              throw Exception('Invalid product quantity.');
            }

            selectedCartData[cartRef.id] = {
              ...data,
              'cartItemId': cartRef.id,
              'sellerId': sellerId,
            };

            productPaths[cartRef.id] = productPath;

            productQuantities[productPath] =
                (productQuantities[productPath] ?? 0) + quantity;
          }

          // READ PRODUCT DOCUMENTS.
          final Map<String, DocumentSnapshot<Map<String, dynamic>>>
              productSnapshots = {};

          for (final productPath in productQuantities.keys) {
            final productRef = firestore.doc(productPath);
            final productSnapshot = await transaction.get(productRef);

            if (!productSnapshot.exists) {
              throw Exception(
                'One of your selected products is no longer available.',
              );
            }

            final productData = productSnapshot.data() ?? {};

            if (productData['isActive'] == false) {
              throw Exception(
                '${productData['name'] ?? 'A product'} '
                'is no longer available.',
              );
            }

            final actualSellerId =
                getSellerIdFromProductPath(productPath);

            final storedSellerId =
                (productData['sellerId'] ?? '').toString();

            if (storedSellerId.isNotEmpty &&
                storedSellerId != actualSellerId) {
              throw Exception(
                'Invalid seller information for one of your products.',
              );
            }

            if (actualSellerId == user.uid) {
              throw Exception(
                'You cannot checkout products from your own store.',
              );
            }

            final currentPrice = getPrice(productData['price']);

            if (currentPrice < 0) {
              throw Exception('Invalid product price.');
            }

            productSnapshots[productPath] = productSnapshot;
          }

          // VALIDATE STOCK.
          for (final entry in productQuantities.entries) {
            final productData =
                productSnapshots[entry.key]!.data() ?? {};

            final availableStock =
                getQuantity(productData['stock'] ?? 0);

            if (entry.value > availableStock) {
              final productName =
                  (productData['name'] ?? 'A product').toString();

              throw Exception(
                'Not enough stock for $productName. '
                'Available stock: $availableStock.',
              );
            }
          }

          // GROUP ITEMS BY SELLER.
          final Map<String, List<Map<String, dynamic>>> sellerItems = {};

          for (final cartEntry in selectedCartData.entries) {
            final cartItem = cartEntry.value;
            final productPath = productPaths[cartEntry.key]!;

            final sellerId = cartItem['sellerId'].toString();

            final productData =
                productSnapshots[productPath]!.data() ?? {};

            final quantity = getQuantity(cartItem['quantity']);
            final currentPrice = getPrice(productData['price']);
            final subtotal = currentPrice * quantity;

            sellerItems.putIfAbsent(sellerId, () => []);

            sellerItems[sellerId]!.add({
              'productId': cartItem['productId'] ?? '',
              'productPath': productPath,
              'name': productData['name'] ??
                  cartItem['name'] ??
                  'Product',
              'description': productData['description'] ??
                  cartItem['description'] ??
                  '',
              'category': productData['category'] ??
                  cartItem['category'] ??
                  '',
              'gender': productData['gender'] ??
                  cartItem['gender'] ??
                  '',
              'imageUrl': productData['imageUrl'] ??
                  cartItem['imageUrl'] ??
                  '',
              'storeName': productData['storeName'] ??
                  cartItem['storeName'] ??
                  '',
              'sellerId': sellerId,
              'price': currentPrice,
              'quantity': quantity,
              'size': cartItem['size'] ?? '',
              'subtotal': subtotal,
            });
          }

          final List<String> orderIds = [];
          double actualGrandTotal = 0;

          // CREATE ONE ORDER PER SELLER.
          for (final sellerEntry in sellerItems.entries) {
            final sellerId = sellerEntry.key;
            final orderItems = sellerEntry.value;

            double sellerSubtotal = 0;

            for (final item in orderItems) {
              sellerSubtotal += getPrice(item['subtotal']);
            }

            final sellerShippingFee =
                shippingMethod == 'Express Shipping'
                    ? expressShippingFee
                    : 0.0;

            final sellerTotal = sellerSubtotal + sellerShippingFee;

            final orderRef = firestore.collection('orders').doc();

            final storeName =
                (orderItems.first['storeName'] ?? 'Store').toString();

            transaction.set(orderRef, {
              'orderId': orderRef.id,
              'customerId': user.uid,
              'sellerId': sellerId,
              'customerName': customerName,
              'customerPhone': customerPhone,
              'deliveryAddress': deliveryAddress,
              'shippingMethod': shippingMethod,
              'shippingFee': sellerShippingFee,
              'items': orderItems,
              'subtotal': sellerSubtotal,
              'totalAmount': sellerTotal,
              'paymentMethod': paymentMethod,
              'paymentStatus': paymentMethod == 'COD'
                  ? 'pending'
                  : 'pending_verification',
              'gcashReference': paymentMethod == 'GCash'
                  ? gcashReference
                  : '',
              'orderStatus': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });

            // INITIAL STATUS HISTORY.
            final pendingHistoryRef =
                orderRef.collection('statusHistory').doc();

            transaction.set(pendingHistoryRef, {
              'status': 'pending',
              'updatedBy': 'customer',
              'createdAt': FieldValue.serverTimestamp(),
            });

            // SELLER NOTIFICATION.
            final sellerNotificationRef = firestore
                .collection('Users')
                .doc(sellerId)
                .collection('notifications')
                .doc();

            transaction.set(sellerNotificationRef, {
              'title': 'New Order Received',
              'body':
                  '$customerName placed a new order worth '
                  '₱${sellerTotal.toStringAsFixed(2)} at $storeName.',
              'type': 'order',
              'isRead': false,
              'orderId': orderRef.id,
              'createdAt': FieldValue.serverTimestamp(),
            });

            // CUSTOMER NOTIFICATION.
            final customerNotificationRef = firestore
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .doc();

            transaction.set(customerNotificationRef, {
              'title': 'Order Placed Successfully',
              'body':
                  'Your order from $storeName has been placed successfully. '
                  'Total: ₱${sellerTotal.toStringAsFixed(2)}.',
              'type': 'order',
              'isRead': false,
              'orderId': orderRef.id,
              'createdAt': FieldValue.serverTimestamp(),
            });

            orderIds.add(orderRef.id);
            actualGrandTotal += sellerTotal;
          }

          // DEDUCT STOCK.
          for (final entry in productQuantities.entries) {
            final productRef = firestore.doc(entry.key);

            final productData =
                productSnapshots[entry.key]!.data() ?? {};

            final currentStock =
                getQuantity(productData['stock'] ?? 0);

            transaction.update(productRef, {
              'stock': currentStock - entry.value,
            });
          }

          // DELETE SELECTED CART ITEMS.
          for (final cartRef in selectedCartReferences) {
            transaction.delete(cartRef);
          }

          return {
            'orderIds': orderIds,
            'total': actualGrandTotal,
          };
        },
      );

      if (!mounted) return;

      final orderIds =
          List<String>.from(result['orderIds'] as List);

      final actualTotal =
          (result['total'] as num).toDouble();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderIds: orderIds,
            total: actualTotal,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          isPlacingOrder = false;
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

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildShippingOption({
    required String value,
    required String description,
    required String price,
    required IconData icon,
  }) {
    final selected = shippingMethod == value;

    return InkWell(
      onTap: isPlacingOrder
          ? null
          : () {
              setState(() {
                shippingMethod = value;
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? pink.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? pink : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? pink : Colors.grey,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: pink, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                color: pink,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            buildSectionTitle('Delivery Information'),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the recipient name.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '09XXXXXXXXX',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';

                      if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
                        return 'Enter a valid 11-digit Philippine mobile number.';
                      }

                      return null;
                    },
                  ),

                  if (!isStorePickup) ...[
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: addressController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Complete Delivery Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!isStorePickup &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter your delivery address.';
                        }

                        if (!isStorePickup &&
                            value!.trim().length < 10) {
                          return 'Please provide a more complete address.';
                        }

                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            buildSectionTitle('Shipping Method'),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  buildShippingOption(
                    value: 'Standard Shipping',
                    description: 'Regular delivery to your address.',
                    price: 'FREE',
                    icon: Icons.local_shipping_outlined,
                  ),
                  buildShippingOption(
                    value: 'Express Shipping',
                    description: 'Estimated delivery: 1–2 business days.',
                    price: '₱150 / store',
                    icon: Icons.delivery_dining_outlined,
                  ),
                  buildShippingOption(
                    value: 'Store Pickup',
                    description: 'Pick up your order directly from the seller.',
                    price: 'FREE',
                    icon: Icons.storefront_outlined,
                  ),
                ],
              ),
            ),

            if (isStorePickup) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You selected Store Pickup. Contact the seller '
                        'for the store location and pickup arrangements.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            buildSectionTitle('Payment Method'),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: RadioGroup<String>(
                groupValue: paymentMethod,
                onChanged: (value) {
                  if (isPlacingOrder || value == null) return;

                  setState(() {
                    paymentMethod = value;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'COD',
                      activeColor: pink,
                      title: const Text(
                        'Cash on Delivery',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Pay when your order arrives or is picked up.',
                      ),
                      secondary: const Icon(
                        Icons.payments_outlined,
                        color: pink,
                      ),
                    ),

                    const Divider(height: 1),

                    RadioListTile<String>(
                      value: 'GCash',
                      activeColor: pink,
                      title: const Text(
                        'GCash',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Pay using GCash and provide your reference number.',
                      ),
                      secondary: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: pink,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (paymentMethod == 'GCash') ...[
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GCash Payment',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Use the official GCash payment details '
                      'provided by the seller or store. After paying, '
                      'enter your transaction reference number below.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: gcashReferenceController,
                      decoration: const InputDecoration(
                        labelText: 'GCash Reference Number',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (paymentMethod == 'GCash' &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter your GCash reference number.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GCash payments will remain pending until verified.',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            buildSectionTitle('Order Summary'),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  ...widget.cartItems.map((item) {
                    final name =
                        (item['name'] ?? 'Product').toString();

                    final store =
                        (item['storeName'] ?? 'Unknown Store').toString();

                    final size =
                        (item['size'] ?? '').toString();

                    final quantity = getQuantity(item['quantity']);
                    final price = getPrice(item['price']);
                    final subtotal = price * quantity;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  store,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  'Size: ${size.isEmpty ? 'Not selected' : size} | Qty: $quantity',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: pink,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text('₱${widget.total.toStringAsFixed(2)}'),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shipping Fee'),
                      Text(
                        shippingFee == 0
                            ? 'FREE'
                            : '₱${shippingFee.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: pink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  if (shippingMethod == 'Express Shipping' &&
                      checkoutSellerCount > 1) ...[
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$checkoutSellerCount stores × ₱150',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],

                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: pink,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isPlacingOrder ? null : placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isPlacingOrder
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
