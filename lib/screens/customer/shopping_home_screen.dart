
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cart_screen.dart';
import 'product_details_screen.dart';
import 'store_profile_screen.dart';
import 'my_orders_screen.dart';
import 'wishlist_screen.dart';
import '../profile/personal_information_screen.dart';
import 'become_seller_screen.dart';
import '../chat/chat_screen.dart';
import '../notifications/notifications_screen.dart';

class ShoppingHomeScreen extends StatefulWidget {
  final String role;

  const ShoppingHomeScreen({
    super.key,
    required this.role,
  });

  @override
  State<ShoppingHomeScreen> createState() => _ShoppingHomeScreenState();
}

class _ShoppingHomeScreenState extends State<ShoppingHomeScreen> {
  final TextEditingController searchController = TextEditingController();

  String selectedGender = 'All';
  String selectedCategory = 'All';
  int selectedNavIndex = 0;

  final Color normalPink = const Color(0xFFD96B91);
  final Color femalePink = const Color(0xFFD96B91);
  final Color maleBlue = const Color(0xFF568BCB);

  Color get primaryColor {
    switch (selectedGender) {
      case 'Female':
        return femalePink;
      case 'Male':
        return maleBlue;
      default:
        return normalPink;
    }
  }

  Color get backgroundColor {
    switch (selectedGender) {
      case 'Female':
        return const Color(0xFFFFF4F8);
      case 'Male':
        return const Color(0xFFF1F7FF);
      default:
        return const Color(0xFFFFF8FA);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get productsStream {
    return FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get sellersStream {
    return FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'seller')
        .snapshots();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Log Out'),
          content: const Text(
            'Are you sure you want to log out of your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD96B91),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) return;

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }

  String normalizeGender(String value) {
    final gender = value.toLowerCase().trim();

    if (gender == 'female' || gender == 'women') {
      return 'Female';
    }

    if (gender == 'male' || gender == 'men') {
      return 'Male';
    }

    return value;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showComingSoon(String feature) {
    showMessage('$feature coming soon!');
  }

  void openPersonalInformation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PersonalInformationScreen(
          role: 'user',
        ),
      ),
    );
  }

  void openMyOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyOrdersScreen(),
      ),
    );
  }

  void openBecomeSeller() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BecomeSellerScreen(),
      ),
    );
  }

  void openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(
          role: 'user',
        ),
      ),
    );
  }

  void openProductDetails(
    DocumentSnapshot<Map<String, dynamic>> productDoc,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          productDoc: productDoc,
        ),
      ),
    );
  }

  void openStoreProfile(String sellerId, String storeName) {
    if (sellerId.trim().isEmpty) {
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

  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/style4u_logo.png',
                  width: 43,
                  height: 43,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return CircleAvatar(
                      backgroundColor: primaryColor,
                      child: const Icon(
                        Icons.shopping_bag,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Style4U',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'Your style, your choice.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Wishlist shortcut
              WishlistHeaderButton(color: primaryColor),

              PopupMenuButton<String>(
                tooltip: 'Account',
                icon: Icon(
                  Icons.account_circle_outlined,
                  size: 30,
                  color: primaryColor,
                ),
                onSelected: (value) {
                  if (value == 'logout') {
                    confirmLogout();
                  } else if (value == 'edit') {
                    openPersonalInformation();
                  } else {
                    setState(() {
                      selectedNavIndex = 3;
                    });
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline),
                        SizedBox(width: 10),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('Personal Information'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 10),
                        Text(
                          'Log Out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search clothes, shoes, accessories, shops...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              prefixIcon: Icon(Icons.search, color: primaryColor),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGenderFilters() {
    final genders = ['All', 'Female', 'Male'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: genders.map((gender) {
          final isSelected = selectedGender == gender;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedGender = gender;
                    selectedCategory = 'All';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      gender == 'Female'
                          ? 'Women'
                          : gender == 'Male'
                              ? 'Men'
                              : 'All',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISCOVER YOUR STYLE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Find Your\nPerfect Look!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Explore styles that match you.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SHOP NOW',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.shopping_bag_outlined,
            size: 85,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildCategoryFilters(List<String> categories) {
    return SizedBox(
      height: 43,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? primaryColor
                    : Colors.grey.shade200,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() {
                  selectedCategory = category;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget buildShopCard(
    String sellerId,
    Map<String, dynamic> sellerData,
  ) {
    final storeName =
        (sellerData['storeName'] ?? '').toString().trim();

    if (storeName.isEmpty) {
      return const SizedBox.shrink();
    }

    final imageUrl =
        (sellerData['storeImageUrl'] ??
                sellerData['profileImageUrl'] ??
                sellerData['photoUrl'] ??
                '')
            .toString();

    return SizedBox(
      width: 175,
      child: Card(
        color: Colors.white,
        elevation: 2,
        margin: const EdgeInsets.only(right: 10, bottom: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openStoreProfile(sellerId, storeName),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 29,
                    backgroundColor: const Color(0xFFFFE8F0),
                    backgroundImage:
                        imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty
                        ? const Icon(
                            Icons.storefront_outlined,
                            color: Color(0xFFD96B91),
                            size: 30,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  storeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF79515F),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront,
                      color: Color(0xFFD96B91),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Visit Shop',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: primaryColor,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildShopSearchResults(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sellers,
    String searchText,
  ) {
    if (searchText.isEmpty) {
      return const SizedBox.shrink();
    }

    final matchingSellers = sellers.where((seller) {
      final data = seller.data();
      final name = (data['storeName'] ?? '').toString().toLowerCase();
      return name.contains(searchText);
    }).toList();

    if (matchingSellers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              const Text(
                'Matching Shops',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${matchingSellers.length} shops',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: matchingSellers.length,
            itemBuilder: (context, index) {
              final seller = matchingSellers[index];

              return buildShopCard(
                seller.id,
                seller.data(),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget buildProductCard(
    DocumentSnapshot<Map<String, dynamic>> productDoc,
  ) {
    final product = productDoc.data() ?? {};

    final name = (product['name'] ?? 'Unnamed Product').toString();
    final imageUrl = (product['imageUrl'] ?? '').toString();
    final storeName = (product['storeName'] ?? 'Unknown Store').toString();

    final sellerIdFromData =
        (product['sellerId'] ?? '').toString().trim();

    final sellerIdFromPath =
        productDoc.reference.parent.parent?.id ?? '';

    final sellerId = sellerIdFromData.isNotEmpty
        ? sellerIdFromData
        : sellerIdFromPath;

    final price = product['price'] is num
        ? (product['price'] as num).toDouble()
        : double.tryParse((product['price'] ?? '0').toString()) ?? 0.0;

    final stock = product['stock'] is num
        ? (product['stock'] as num).toInt()
        : int.tryParse((product['stock'] ?? '0').toString()) ?? 0;

    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: primaryColor.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => openProductDetails(productDoc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 45,
                            color: Colors.grey,
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade100,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 45,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),

                  // Working Wishlist heart
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistButton(
                      productDoc: productDoc,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
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
                  const SizedBox(height: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openStoreProfile(sellerId, storeName),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 10,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            size: 11,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '₱${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        stock > 0
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                        size: 12,
                        color: stock > 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          stock > 0 ? 'Stock: $stock' : 'Out of stock',
                          style: TextStyle(
                            color: stock > 0 ? Colors.green : Colors.red,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 35,
                    child: ElevatedButton.icon(
                      onPressed: () => openProductDetails(productDoc),
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 15,
                      ),
                      label: const Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
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

  Widget buildProfile() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final name = (data['name'] ?? 'Customer Account').toString();
        final imageUrl = (data['profileImageUrl'] ?? '').toString();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const SizedBox(height: 25),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                  backgroundImage:
                      imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 45,
                          color: primaryColor,
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: openPersonalInformation,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Personal Information'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openMyOrders,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('My Orders'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openBecomeSeller,
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Become a Seller'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openNotifications,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Notifications'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showComingSoon('Help Center'),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Help Center'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: confirmLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildChat() {
    return const ChatInboxScreen(role: 'user');
  }

  Widget buildBottomNavigation() {
    final items = [
      const _NavItem(Icons.home_outlined, 'Home'),
      const _NavItem(Icons.shopping_cart_outlined, 'Cart'),
      const _NavItem(Icons.chat_bubble_outline, 'Chat'),
      const _NavItem(Icons.person_outline, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = selectedNavIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () {
                  if (index == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  } else {
                    setState(() {
                      selectedNavIndex = index;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected ? primaryColor : Colors.grey,
                        size: 23,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? primaryColor : Colors.grey,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget buildHomeContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: productsStream,
      builder: (context, productSnapshot) {
        if (productSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Unable to load products.\n${productSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (productSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        final documents = productSnapshot.data?.docs ?? [];

        final allCategories = documents
            .map((doc) =>
                (doc.data()['category'] ?? '').toString().trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        final categories = ['All', ...allCategories];
        final searchText = searchController.text.toLowerCase().trim();

        final filteredProducts = documents.where((doc) {
          final data = doc.data();

          final name =
              (data['name'] ?? '').toString().toLowerCase();

          final description =
              (data['description'] ?? '').toString().toLowerCase();

          final category = (data['category'] ?? '').toString();

          final gender = normalizeGender(
            (data['gender'] ?? '').toString(),
          );

          final storeName =
              (data['storeName'] ?? '').toString().toLowerCase();

          final matchesSearch =
              searchText.isEmpty ||
              name.contains(searchText) ||
              description.contains(searchText) ||
              category.toLowerCase().contains(searchText) ||
              storeName.contains(searchText);

          final matchesGender = selectedGender == 'All' ||
              gender.toLowerCase() == selectedGender.toLowerCase();

          final matchesCategory = selectedCategory == 'All' ||
              category.toLowerCase() == selectedCategory.toLowerCase();

          return matchesSearch && matchesGender && matchesCategory;
        }).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sellersStream,
          builder: (context, sellerSnapshot) {
            if (sellerSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Unable to load shops.\n${sellerSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final sellers = sellerSnapshot.data?.docs ?? [];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHeader(),
                  buildGenderFilters(),
                  buildBanner(),
                  buildSectionTitle(
                    'Shop by Category',
                    subtitle: 'Find what you are looking for',
                  ),
                  const SizedBox(height: 12),
                  buildCategoryFilters(categories),
                  const SizedBox(height: 22),

                  buildShopSearchResults(sellers, searchText),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Discover Products',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${filteredProducts.length} items',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (filteredProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 45,
                        horizontal: 20,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 55,
                              color: primaryColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Try another category or search.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.53,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        return buildProductCard(
                          filteredProducts[index],
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitles = [
      'Style4U',
      'My Cart',
      'Messages',
      'My Profile',
    ];

    final stackIndex = selectedNavIndex == 0
        ? 0
        : selectedNavIndex == 2
            ? 1
            : 2;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: selectedNavIndex == 0
          ? null
          : AppBar(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(pageTitles[selectedNavIndex]),
            ),
      bottomNavigationBar: buildBottomNavigation(),
      body: SafeArea(
        child: IndexedStack(
          index: stackIndex,
          children: [
            buildHomeContent(),
            buildChat(),
            buildProfile(),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}
