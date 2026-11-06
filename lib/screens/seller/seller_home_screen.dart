
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'my_products_screen.dart';
import '../customer/cart_screen.dart';
import '../customer/product_details_screen.dart';
import '../customer/store_profile_screen.dart';
import '../customer/my_orders_screen.dart';
import '../customer/wishlist_screen.dart';
import '../profile/personal_information_screen.dart';
import '../chat/chat_screen.dart';
import '../notifications/notifications_screen.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  int selectedIndex = 0;

  final Color pink = const Color(0xFFD96B91);
  final Color blue = const Color(0xFF4A90E2);

  final TextEditingController searchController = TextEditingController();

  String selectedGender = 'All';
  String selectedCategory = 'All';

  Color get activeColor {
    return selectedGender == 'Male' ? blue : pink;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String normalizeGender(String value) {
    final gender = value.toLowerCase().trim();

    if (gender == 'female' ||
        gender == 'women' ||
        gender == 'woman') {
      return 'female';
    }

    if (gender == 'male' ||
        gender == 'men' ||
        gender == 'man') {
      return 'male';
    }

    return gender;
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
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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
          role: 'seller',
        ),
      ),
    );
  }

  void openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(
          role: 'seller',
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

  void openStoreProfile(String sellerId, String storeName) {
    if (sellerId.trim().isEmpty) {
      showMessage('Unable to identify this store.');
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
                      backgroundColor: activeColor,
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
                        color: activeColor,
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
              WishlistHeaderButton(color: activeColor),

              PopupMenuButton<String>(
                tooltip: 'Account',
                icon: Icon(
                  Icons.account_circle_outlined,
                  size: 30,
                  color: activeColor,
                ),
                onSelected: (value) {
                  if (value == 'logout') {
                    confirmLogout();
                  } else if (value == 'edit') {
                    openPersonalInformation();
                  } else {
                    setState(() {
                      selectedIndex = 4;
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
            onChanged: (value) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Search clothes, shoes, accessories...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              prefixIcon: Icon(Icons.search, color: activeColor),
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
                  color: activeColor.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: activeColor,
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

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: genders.map((gender) {
          final selected = selectedGender == gender;

          final label = gender == 'Female'
              ? 'Women'
              : gender == 'Male'
                  ? 'Men'
                  : 'All';

          final chipColor = gender == 'Male' ? blue : pink;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: chipColor,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black,
              ),
              onSelected: (value) {
                setState(() {
                  selectedGender = gender;
                  selectedCategory = 'All';
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildCategoryFilters(List<String> categories) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              selectedColor: activeColor,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black,
              ),
              onSelected: (value) {
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

  Widget buildHome() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('products')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Unable to load products.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        final allCategories = documents
            .map((doc) => (doc.data()['category'] ?? '')
                .toString()
                .trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        final categories = ['All', ...allCategories];

        final currentCategory = categories.contains(selectedCategory)
            ? selectedCategory
            : 'All';

        final searchText = searchController.text.toLowerCase().trim();

        final products = documents.where((doc) {
          final data = doc.data();

          final name =
              (data['name'] ?? '').toString().toLowerCase();

          final description =
              (data['description'] ?? '').toString().toLowerCase();

          final category =
              (data['category'] ?? '').toString().trim();

          final gender = normalizeGender(
            (data['gender'] ?? '').toString(),
          );

          final storeName =
              (data['storeName'] ?? '').toString().toLowerCase();

          final matchesSearch =
              name.contains(searchText) ||
              description.contains(searchText) ||
              category.toLowerCase().contains(searchText) ||
              storeName.contains(searchText);

          final matchesGender = selectedGender == 'All' ||
              gender == selectedGender.toLowerCase();

          final matchesCategory = currentCategory == 'All' ||
              category.toLowerCase() ==
                  currentCategory.toLowerCase();

          return matchesSearch &&
              matchesGender &&
              matchesCategory;
        }).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeader(),
              buildGenderFilters(),
              const SizedBox(height: 12),
              buildCategoryFilters(categories),
              const SizedBox(height: 12),

              if (products.isEmpty)
                const SizedBox(
                  height: 250,
                  child: Center(
                    child: Text('No products found.'),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data();

                    final sellerIdFromData =
                        (data['sellerId'] ?? '').toString().trim();

                    final sellerIdFromPath =
                        doc.reference.parent.parent?.id ?? '';

                    final sellerId = sellerIdFromData.isNotEmpty
                        ? sellerIdFromData
                        : sellerIdFromPath;

                    final storeName =
                        (data['storeName'] ?? 'Store').toString();

                    final imageUrl =
                        (data['imageUrl'] ?? '').toString();

                    final price = data['price'] is num
                        ? (data['price'] as num).toDouble()
                        : double.tryParse(
                              (data['price'] ?? '0').toString(),
                            ) ??
                            0.0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailsScreen(
                              productDoc: doc,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    color: Colors.grey.shade100,
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return const Icon(
                                                Icons.image_not_supported,
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 55,
                                            color: Colors.grey,
                                          ),
                                  ),

                                  // Working Wishlist heart
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: WishlistButton(
                                      productDoc: doc,
                                      color: activeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (data['name'] ?? 'Product').toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₱${price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: activeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      openStoreProfile(
                                        sellerId,
                                        storeName,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 3,
                                        bottom: 3,
                                      ),
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              storeName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: activeColor,
                                                fontSize: 12,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: activeColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.open_in_new,
                                            size: 11,
                                            color: activeColor,
                                          ),
                                        ],
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
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget buildMessage() {
    return const ChatInboxScreen(role: 'seller');
  }

  Widget buildProfile() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final name = (data['name'] ?? 'Seller Account').toString();
        final imageUrl = (data['profileImageUrl'] ?? '').toString();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const SizedBox(height: 25),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: activeColor.withValues(alpha: 0.15),
                  backgroundImage: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : null,
                  child: imageUrl.isEmpty
                      ? Icon(
                          Icons.store,
                          size: 45,
                          color: activeColor,
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
                      backgroundColor: activeColor,
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
                      foregroundColor: activeColor,
                      side: BorderSide(color: activeColor),
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
                      foregroundColor: activeColor,
                      side: BorderSide(color: activeColor),
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
                      foregroundColor: activeColor,
                      side: BorderSide(color: activeColor),
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
                      backgroundColor: activeColor,
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildHome(),
      const CartScreen(showAppBar: false),
      buildMessage(),
      const MyProductsScreen(),
      buildProfile(),
    ];

    final titles = [
      '',
      'My Cart',
      'Messages',
      'My Products',
      'My Profile',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: selectedIndex == 0
          ? null
          : AppBar(
              backgroundColor: activeColor,
              foregroundColor: Colors.white,
              title: Text(titles[selectedIndex]),
              elevation: 0,
            ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: activeColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Message',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'My Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
