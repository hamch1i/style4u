import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'seller_add_product_screen.dart';
import 'seller_edit_product_screen.dart';

class SellerWebDashboard extends StatefulWidget {
  const SellerWebDashboard({super.key});

  @override
  State<SellerWebDashboard> createState() => _SellerWebDashboardState();
}

class _SellerWebDashboardState extends State<SellerWebDashboard> {
  static const Color pink = Color(0xFFD96B91);
  static const Color darkPink = Color(0xFFB94F78);
  static const Color background = Color(0xFFFFF7FA);
  static const Color lightPink = Color(0xFFFCEAF0);

  int selectedPage = 0;

  final List<IconData> pageIcons = [
    Icons.dashboard_outlined,
    Icons.storefront_outlined,
    Icons.inventory_2_outlined,
    Icons.shopping_bag_outlined,
    Icons.analytics_outlined,
    Icons.person_outline,
  ];

  List<String> _pageNames(String storeName) => [
        'Dashboard',
        storeName,
        'My Products',
        'Orders Received',
        'Analytics',
        'Personal Information',
      ];

  String _cleanName(dynamic value) {
    final name = value?.toString().trim() ?? '';
    return name;
  }

  String _resolveStoreName(
    Map<String, dynamic> sellerData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
  ) {
    // First, use the seller's saved shop name.
    for (final key in ['storeName', 'shopName', 'businessName']) {
      final name = _cleanName(sellerData[key]);
      if (name.isNotEmpty) return name;
    }

    // If the seller profile has no shop name, use the existing
    // shop name saved in the seller's product records.
    for (final product in products) {
      final data = product.data();

      for (final key in ['storeName', 'shopName', 'businessName']) {
        final name = _cleanName(data[key]);
        if (name.isNotEmpty) return name;
      }
    }

    // Last fallback: Firebase Authentication display name.
    final displayName =
        _cleanName(FirebaseAuth.instance.currentUser?.displayName);

    if (displayName.isNotEmpty) return displayName;

    return 'Your Shop';
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) =>
      '₱${_toDouble(value).toStringAsFixed(2)}';

  String _date(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.month}/${date.day}/${date.year}';
    }
    return 'Not available';
  }

  DocumentReference<Map<String, dynamic>> get _sellerRef {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('Users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _sellerRef.collection('products');

  Query<Map<String, dynamic>> get _ordersQuery {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: uid);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _openAddProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SellerAddProductScreen(),
      ),
    );
  }

  Future<void> _openEditProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerEditProductScreen(
          productId: productId,
          productData: data,
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _productsRef.doc(productId).delete();
      if (!mounted) return;
      _message('Product deleted successfully.');
    } catch (e) {
      if (!mounted) return;
      _message('Unable to delete product: $e');
    }
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(orderId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Order not found.');
        }

        final order = orderSnapshot.data()!;
        final currentStatus =
            order['orderStatus']?.toString() ?? 'pending';

        if (order['sellerId'] != user.uid) {
          throw Exception('You cannot update this order.');
        }

        // Sellers cannot mark an order as delivered.
        final allowed = {
          'pending': ['confirmed', 'rejected'],
          'confirmed': ['processing'],
          'processing': ['shipped'],
        };

        if (!(allowed[currentStatus]?.contains(newStatus) ?? false)) {
          throw Exception('This order status change is not allowed.');
        }

        final productUpdates = <MapEntry<
            DocumentReference<Map<String, dynamic>>,
            int>>[];

        if (newStatus == 'rejected') {
          final items = order['items'] as List<dynamic>? ?? [];

          for (final item in items) {
            if (item is! Map) continue;

            final productPath = item['productPath']?.toString() ?? '';
            final quantity = _toInt(item['quantity']);

            if (productPath.isEmpty || quantity <= 0) continue;

            final productRef =
                FirebaseFirestore.instance.doc(productPath);
            final productSnapshot = await transaction.get(productRef);

            if (productSnapshot.exists) {
              final productData = productSnapshot.data() ?? {};
              final currentStock = _toInt(productData['stock']);

              productUpdates.add(
                MapEntry(productRef, currentStock + quantity),
              );
            }
          }
        }

        transaction.update(orderRef, {
          'orderStatus': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final historyRef = orderRef.collection('statusHistory').doc();

        transaction.set(historyRef, {
          'status': newStatus,
          'updatedBy': 'seller',
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (final entry in productUpdates) {
          transaction.update(entry.key, {'stock': entry.value});
        }

        final customerId = order['customerId']?.toString() ?? '';

        if (customerId.isNotEmpty) {
          final notificationRef = FirebaseFirestore.instance
              .collection('users')
              .doc(customerId)
              .collection('notifications')
              .doc();

          final messages = {
            'confirmed': 'Your order has been confirmed by the seller.',
            'rejected': 'Your order has been rejected by the seller.',
            'processing': 'The seller is now preparing your order.',
            'shipped': 'Your order has been shipped.',
          };

          transaction.set(notificationRef, {
            'title': 'Order Update',
            'body': messages[newStatus] ??
                'Your order status has been updated.',
            'type': 'order',
            'orderId': orderId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) return;
      _message('Order updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _message('Unable to update order: $e');
    }
  }

  Future<void> _confirmOrderAction(
    String orderId,
    String status,
  ) async {
    final labels = {
      'confirmed': 'confirm this order',
      'rejected': 'reject this order',
      'processing': 'start processing this order',
      'shipped': 'mark this order as shipped',
    };

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text('Are you sure you want to ${labels[status]}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'rejected' ? Colors.red : pink,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateOrderStatus(orderId, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in again.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _sellerRef.snapshots(),
      builder: (context, sellerSnapshot) {
        if (sellerSnapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to load seller information.')),
          );
        }

        if (!sellerSnapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: pink),
            ),
          );
        }

        final sellerData = sellerSnapshot.data!.data() ?? {};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _productsRef.snapshots(),
          builder: (context, productSnapshot) {
            if (productSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('Unable to load products.')),
              );
            }

            if (!productSnapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: pink),
                ),
              );
            }

            final products = productSnapshot.data!.docs;
            final storeName = _resolveStoreName(sellerData, products);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ordersQuery.snapshots(),
              builder: (context, orderSnapshot) {
                if (orderSnapshot.hasError) {
                  return const Scaffold(
                    body: Center(child: Text('Unable to load orders.')),
                  );
                }

                if (!orderSnapshot.hasData) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: pink),
                    ),
                  );
                }

                return _buildPortal(
                  storeName,
                  sellerData,
                  products,
                  orderSnapshot.data!.docs,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPortal(
    String storeName,
    Map<String, dynamic> sellerData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        return Scaffold(
          backgroundColor: background,
          drawer: isWide ? null : Drawer(child: _buildSidebar(storeName)),
          body: Row(
            children: [
              if (isWide)
                SizedBox(
                  width: 250,
                  child: _buildSidebar(storeName),
                ),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(storeName, isWide),
                    if (!isWide) _buildMobileNavigation(storeName),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF7FA),
                              Color(0xFFF9F6F8),
                              Color(0xFFFFF0F5),
                            ],
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 28 : 16,
                            vertical: isWide ? 26 : 18,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 1180,
                              ),
                              child: _buildSelectedPage(
                                storeName,
                                sellerData,
                                products,
                                orders,
                              ),
                            ),
                          ),
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
  }

  Widget _buildSidebar(String storeName) {
    final names = _pageNames(storeName);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFF1E3E9)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 25, 16, 22),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    'assets/images/style4u_logo.png',
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                      Icons.storefront,
                      color: pink,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Style4U',
                    style: TextStyle(
                      color: darkPink,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1E3E9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 23, 20, 11),
            child: Text(
              'SELLER MENU',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: names.length,
              itemBuilder: (context, index) {
                final selected = selectedPage == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: selected ? lightPink : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () {
                        setState(() => selectedPage = index);

                        if (MediaQuery.of(context).size.width < 1000) {
                          Navigator.pop(context);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              pageIcons[index],
                              size: 20,
                              color: selected
                                  ? darkPink
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                names[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? darkPink
                                      : Colors.black87,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (selected)
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: pink,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1E3E9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavigation(String storeName) {
    final names = _pageNames(storeName);

    return Container(
      color: Colors.white,
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: List.generate(
          names.length,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            child: ChoiceChip(
              label: Text(names[index]),
              selected: selectedPage == index,
              selectedColor: lightPink,
              labelStyle: TextStyle(
                color: selectedPage == index ? darkPink : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => selectedPage = index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String storeName, bool isWide) {
    final title = _pageNames(storeName)[selectedPage];

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: lightPink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: darkPink,
                  size: 17,
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: darkPink,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage(
    String storeName,
    Map<String, dynamic> sellerData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    switch (selectedPage) {
      case 0:
        return _dashboardPage(storeName, products, orders);
      case 1:
        return _shopPage(storeName, sellerData);
      case 2:
        return _productsPage(products);
      case 3:
        return _ordersPage(orders);
      case 4:
        return _analyticsPage(products, orders);
      case 5:
        return _personalInformationPage(storeName, sellerData);
      default:
        return _dashboardPage(storeName, products, orders);
    }
  }

  Widget _pageHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardPage(
    String storeName,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    final active =
        products.where((p) => p.data()['isActive'] == true).length;

    final lowStock =
        products.where((p) => _toInt(p.data()['stock']) <= 5).length;

    final pending =
        orders.where((o) => o.data()['orderStatus'] == 'pending').length;

    final delivered =
        orders.where((o) => o.data()['orderStatus'] == 'delivered').length;

    final revenue = orders
        .where((o) => o.data()['orderStatus'] == 'delivered')
        .fold<double>(
          0,
          (total, o) => total + _toDouble(o.data()['totalAmount']),
        );

    final sorted = [...orders]
      ..sort((a, b) {
        final ad = a.data()['createdAt'];
        final bd = b.data()['createdAt'];
        final am = ad is Timestamp ? ad.millisecondsSinceEpoch : 0;
        final bm = bd is Timestamp ? bd.millisecondsSinceEpoch : 0;
        return bm.compareTo(am);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          'Welcome back, $storeName!',
          'Here is an overview of your shop.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 650
                    ? 3
                    : constraints.maxWidth >= 420
                        ? 2
                        : 1;

            final width =
                (constraints.maxWidth - (columns - 1) * 14) / columns;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _statCard(
                  'Total Products',
                  '${products.length}',
                  Icons.inventory_2_outlined,
                  width,
                ),
                _statCard(
                  'Active Products',
                  '$active',
                  Icons.check_circle_outline,
                  width,
                ),
                _statCard(
                  'Low Stock',
                  '$lowStock',
                  Icons.warning_amber_outlined,
                  width,
                ),
                _statCard(
                  'Orders Received',
                  '${orders.length}',
                  Icons.shopping_bag_outlined,
                  width,
                ),
                _statCard(
                  'Pending Orders',
                  '$pending',
                  Icons.pending_actions_outlined,
                  width,
                ),
                _statCard(
                  'Delivered Orders',
                  '$delivered',
                  Icons.local_shipping_outlined,
                  width,
                ),
                _statCard(
                  'Sales Revenue',
                  _money(revenue),
                  Icons.payments_outlined,
                  width,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _sectionTitle('Recent Orders'),
        const SizedBox(height: 13),
        if (sorted.isEmpty)
          _emptyState('No orders yet.', Icons.shopping_bag_outlined)
        else
          ...sorted.take(5).map(_orderCard),
      ],
    );
  }

  Widget _shopPage(
    String storeName,
    Map<String, dynamic> sellerData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          storeName,
          'Your shop information and current status.',
        ),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: lightPink,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.storefront,
                  size: 44,
                  color: pink,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                storeName,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: darkPink,
                ),
              ),
              const SizedBox(height: 18),
              _infoRow(
                'Seller Status',
                sellerData['sellerStatus']?.toString() ?? 'Not specified',
              ),
              _infoRow(
                'Account Role',
                sellerData['role']?.toString() ?? 'Seller',
              ),
              _infoRow(
                'Email',
                FirebaseAuth.instance.currentUser?.email ?? 'Not available',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _productsPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          'My Products',
          'Add, edit, and manage the products in your shop.',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _openAddProduct,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (products.isEmpty)
          _emptyState(
            'No products yet. Add your first product.',
            Icons.inventory_2_outlined,
          )
        else
          ...products.map((product) {
            final data = product.data();
            final name = data['name']?.toString() ?? 'Unnamed Product';
            final imageUrl = data['imageUrl']?.toString() ?? '';
            final stock = _toInt(data['stock']);
            final active = data['isActive'] == true;

            return _panel(
              margin: const EdgeInsets.only(bottom: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;

                  final image = ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: imageUrl.isEmpty
                        ? _productPlaceholder()
                        : Image.network(
                            imageUrl,
                            width: 78,
                            height: 78,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _productPlaceholder(),
                          ),
                  );

                  final details = Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _money(data['price']),
                          style: const TextStyle(
                            color: darkPink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Stock: $stock',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          active ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: active ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );

                  final actions = Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit product',
                        onPressed: () => _openEditProduct(
                          product.id,
                          data,
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: pink,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete product',
                        onPressed: () => _deleteProduct(product.id),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            image,
                            const SizedBox(width: 13),
                            details,
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: actions,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      image,
                      const SizedBox(width: 15),
                      details,
                      actions,
                    ],
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _ordersPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    final sortedOrders = [...orders]
      ..sort((a, b) {
        final aDate = a.data()['createdAt'];
        final bDate = b.data()['createdAt'];
        final aMillis =
            aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
        final bMillis =
            bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
        return bMillis.compareTo(aMillis);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          'Orders Received',
          'Manage orders placed by customers in your shop.',
        ),
        if (sortedOrders.isEmpty)
          _emptyState(
            'No orders received yet.',
            Icons.shopping_bag_outlined,
          )
        else
          ...sortedOrders.map(_orderCard),
      ],
    );
  }

  Widget _orderCard(
    QueryDocumentSnapshot<Map<String, dynamic>> orderSnapshot,
  ) {
    final order = orderSnapshot.data();
    final status = order['orderStatus']?.toString() ?? 'pending';
    final items = order['items'] as List<dynamic>? ?? [];

    final statusColors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'processing': Colors.deepPurple,
      'shipped': Colors.teal,
      'delivered': Colors.green,
      'rejected': Colors.red,
    };

    final statusColor = statusColors[status] ?? Colors.grey;
    final actionButtons = <Widget>[];

    if (status == 'pending') {
      actionButtons.add(
        OutlinedButton(
          onPressed: () => _confirmOrderAction(
            orderSnapshot.id,
            'rejected',
          ),
          child: const Text('Reject'),
        ),
      );

      actionButtons.add(
        ElevatedButton(
          onPressed: () => _confirmOrderAction(
            orderSnapshot.id,
            'confirmed',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: pink,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      );
    } else if (status == 'confirmed') {
      actionButtons.add(
        ElevatedButton(
          onPressed: () => _confirmOrderAction(
            orderSnapshot.id,
            'processing',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: pink,
            foregroundColor: Colors.white,
          ),
          child: const Text('Start Processing'),
        ),
      );
    } else if (status == 'processing') {
      actionButtons.add(
        ElevatedButton(
          onPressed: () => _confirmOrderAction(
            orderSnapshot.id,
            'shipped',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: pink,
            foregroundColor: Colors.white,
          ),
          child: const Text('Mark as Shipped'),
        ),
      );
    }

    return _panel(
      margin: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            children: [
              Text(
                'Order #${orderSnapshot.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
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
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _infoRow(
            'Customer',
            order['customerName']?.toString() ?? 'Customer',
          ),
          _infoRow('Date', _date(order['createdAt'])),
          _infoRow('Total Amount', _money(order['totalAmount'])),
          _infoRow(
            'Payment Method',
            order['paymentMethod']?.toString() ?? 'Not specified',
          ),
          _infoRow(
            'Shipping Method',
            order['shippingMethod']?.toString() ?? 'Not specified',
          ),
          const SizedBox(height: 10),
          const Text(
            'Products Ordered',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            if (item is! Map) return const SizedBox.shrink();

            final name = item['name']?.toString() ?? 'Product';
            final quantity = _toInt(item['quantity']);
            final price = _toDouble(item['price']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text('$name × $quantity')),
                  Text(_money(price * quantity)),
                ],
              ),
            );
          }),
          if (status == 'shipped') ...[
            const SizedBox(height: 12),
            const Text(
              'Waiting for the customer to confirm receipt.',
              style: TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          if (status == 'delivered') ...[
            const SizedBox(height: 12),
            const Text(
              'Customer confirmed that the order was received.',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          if (status == 'rejected') ...[
            const SizedBox(height: 12),
            const Text(
              'This order was rejected.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          if (actionButtons.isNotEmpty) ...[
            const Divider(height: 24),
            Wrap(
              spacing: 9,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: actionButtons,
            ),
          ],
        ],
      ),
    );
  }

  Widget _analyticsPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  ) {
    final deliveredOrders = orders.where(
      (o) => o.data()['orderStatus'] == 'delivered',
    );

    final revenue = deliveredOrders.fold<double>(
      0,
      (total, order) => total + _toDouble(order.data()['totalAmount']),
    );

    final deliveredCount = deliveredOrders.length;

    final pendingCount =
        orders.where((o) => o.data()['orderStatus'] == 'pending').length;

    final processingCount =
        orders.where((o) => o.data()['orderStatus'] == 'processing').length;

    final shippedCount =
        orders.where((o) => o.data()['orderStatus'] == 'shipped').length;

    final quantities = <String, int>{};

    for (final orderSnapshot in deliveredOrders) {
      final items =
          orderSnapshot.data()['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        if (item is! Map) continue;

        final name = item['name']?.toString() ?? 'Unnamed Product';

        quantities[name] =
            (quantities[name] ?? 0) + _toInt(item['quantity']);
      }
    }

    final bestSellers = quantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          'Analytics',
          'A summary of your shop performance.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850
                ? 4
                : constraints.maxWidth >= 500
                    ? 2
                    : 1;

            final width =
                (constraints.maxWidth - (columns - 1) * 14) / columns;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _statCard(
                  'Sales Revenue',
                  _money(revenue),
                  Icons.payments_outlined,
                  width,
                ),
                _statCard(
                  'Delivered Orders',
                  '$deliveredCount',
                  Icons.check_circle_outline,
                  width,
                ),
                _statCard(
                  'Pending Orders',
                  '$pendingCount',
                  Icons.pending_actions_outlined,
                  width,
                ),
                _statCard(
                  'Products Listed',
                  '${products.length}',
                  Icons.inventory_2_outlined,
                  width,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 27),
        _sectionTitle('Order Statistics'),
        const SizedBox(height: 12),
        _panel(
          child: Column(
            children: [
              _analyticsRow('Pending', pendingCount, Colors.orange),
              _analyticsRow(
                'Processing',
                processingCount,
                Colors.deepPurple,
              ),
              _analyticsRow('Shipped', shippedCount, Colors.teal),
              _analyticsRow('Delivered', deliveredCount, Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 27),
        _sectionTitle('Most Purchased Products'),
        const SizedBox(height: 12),
        if (bestSellers.isEmpty)
          _emptyState(
            'No completed purchases yet.',
            Icons.trending_up,
          )
        else
          _panel(
            child: Column(
              children: bestSellers.take(10).map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: pink,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.key)),
                      Text(
                        '${entry.value} sold',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkPink,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _personalInformationPage(
    String storeName,
    Map<String, dynamic> sellerData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          'Personal Information',
          'View your account details and update your shop name.',
        ),
        _panel(
          child: _PersonalInformationForm(
            storeName: storeName,
            sellerData: sellerData,
            sellerRef: _sellerRef,
            onMessage: _message,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF5E8ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: lightPink,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: darkPink, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF5E8ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(label)),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return _panel(
      child: Column(
        children: [
          Icon(icon, size: 45, color: Colors.grey.shade400),
          const SizedBox(height: 11),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder() {
    return Container(
      width: 78,
      height: 78,
      color: lightPink,
      child: const Icon(
        Icons.image_outlined,
        color: pink,
        size: 29,
      ),
    );
  }
}

class _PersonalInformationForm extends StatefulWidget {
  final String storeName;
  final Map<String, dynamic> sellerData;
  final DocumentReference<Map<String, dynamic>> sellerRef;
  final ValueChanged<String> onMessage;

  const _PersonalInformationForm({
    required this.storeName,
    required this.sellerData,
    required this.sellerRef,
    required this.onMessage,
  });

  @override
  State<_PersonalInformationForm> createState() =>
      _PersonalInformationFormState();
}

class _PersonalInformationFormState
    extends State<_PersonalInformationForm> {
  late final TextEditingController storeController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    storeController = TextEditingController(text: widget.storeName);
  }

  @override
  void didUpdateWidget(covariant _PersonalInformationForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.storeName != widget.storeName &&
        storeController.text != widget.storeName) {
      storeController.text = widget.storeName;
    }
  }

  @override
  void dispose() {
    storeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = storeController.text.trim();

    if (newName.isEmpty) {
      widget.onMessage('Shop name cannot be empty.');
      return;
    }

    setState(() => saving = true);

    try {
      await widget.sellerRef.update({
        'storeName': newName,
      });

      widget.onMessage('Shop name updated successfully.');
    } catch (e) {
      widget.onMessage('Unable to update shop name: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0xFFFCEAF0),
          child: Icon(
            Icons.person,
            size: 34,
            color: Color(0xFFD96B91),
          ),
        ),
        const SizedBox(height: 20),
        _detailRow(
          'Email Address',
          FirebaseAuth.instance.currentUser?.email ?? 'Not available',
        ),
        _detailRow(
          'Account Role',
          widget.sellerData['role']?.toString() ?? 'Seller',
        ),
        _detailRow(
          'Seller Status',
          widget.sellerData['sellerStatus']?.toString() ??
              'Not specified',
        ),
        const SizedBox(height: 17),
        const Text(
          'Shop Name',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: storeController,
          decoration: InputDecoration(
            hintText: 'Enter your shop name',
            filled: true,
            fillColor: const Color(0xFFFFF7FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Saving...' : 'Save Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD96B91),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 19,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}