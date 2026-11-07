
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> {
  static const Color pink = Color(0xFFD96B91);
  static const Color darkPink = Color(0xFFB94F78);
  static const Color background = Color(0xFFFFF7FA);

  final TextEditingController searchController = TextEditingController();

  String searchText = '';
  String selectedRole = 'All';

  final Map<String, Future<String>> _storeNameCache = {};

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // USER INFORMATION
  // --------------------------------------------------

  String _userName(Map<String, dynamic> data) {
    final name = data['name'] ??
        data['fullName'] ??
        data['displayName'] ??
        data['username'];

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }

    final firstName = data['firstName']?.toString().trim() ?? '';
    final lastName = data['lastName']?.toString().trim() ?? '';

    final combinedName = '$firstName $lastName'.trim();

    return combinedName.isEmpty ? 'No name' : combinedName;
  }

  String _userEmail(Map<String, dynamic> data) {
    return (data['email'] ?? data['emailAddress'] ?? 'No email')
        .toString();
  }

  String _role(Map<String, dynamic> data) {
    return (data['role'] ?? 'user').toString().toLowerCase();
  }

  String _sellerStatus(Map<String, dynamic> data) {
    return (data['sellerStatus'] ?? 'Not specified')
        .toString()
        .toLowerCase();
  }

  bool _isActive(Map<String, dynamic> data) {
    return data['isActive'] != false;
  }

  String _cleanName(dynamic value) {
    final name = value?.toString().trim() ?? '';

    if (name.isEmpty ||
        name.toLowerCase() == 'null' ||
        name.toLowerCase() == 'unnamed shop' ||
        name.toLowerCase() == 'your shop') {
      return '';
    }

    return name;
  }

  // --------------------------------------------------
  // STORE NAME RESOLUTION
  // --------------------------------------------------

  Future<String> _resolveStoreName(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    for (final key in [
      'storeName',
      'shopName',
      'businessName',
    ]) {
      final name = _cleanName(userData[key]);

      if (name.isNotEmpty) {
        return name;
      }
    }

    final collectionNames = ['Users', 'users'];

    for (final collectionName in collectionNames) {
      try {
        final productsSnapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(uid)
            .collection('products')
            .limit(50)
            .get();

        for (final product in productsSnapshot.docs) {
          final productData = product.data();

          for (final key in [
            'storeName',
            'shopName',
            'businessName',
          ]) {
            final name = _cleanName(productData[key]);

            if (name.isNotEmpty) {
              return name;
            }
          }
        }
      } catch (_) {
        // Continue checking the other collection path.
      }
    }

    return 'Shop name not set';
  }

  Future<String> _getStoreName(
    String uid,
    Map<String, dynamic> data,
  ) {
    for (final key in [
      'storeName',
      'shopName',
      'businessName',
    ]) {
      final name = _cleanName(data[key]);

      if (name.isNotEmpty) {
        return Future.value(name);
      }
    }

    return _storeNameCache.putIfAbsent(
      uid,
      () => _resolveStoreName(uid, data),
    );
  }

  // --------------------------------------------------
  // ACCOUNT COLORS
  // --------------------------------------------------

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'seller':
        return pink;
      case 'admin':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'seller':
        return Icons.storefront_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline;
    }
  }

  // --------------------------------------------------
  // DEACTIVATE / REACTIVATE ACCOUNT
  // --------------------------------------------------

  Future<void> _changeAccountStatus(
    _AccountRecord account,
    bool activate,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (account.uid == currentUid && !activate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot deactivate your own account.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final name = _userName(account.data);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            activate ? 'Reactivate Account?' : 'Deactivate Account?',
          ),
          content: Text(
            activate
                ? 'Are you sure you want to reactivate $name?'
                : 'Are you sure you want to deactivate $name? '
                    'This account will be marked inactive.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: activate ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(activate ? 'Reactivate' : 'Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final collectionNames = ['Users', 'users'];
      int updatedDocuments = 0;

      for (final collectionName in collectionNames) {
        final reference =
            firestore.collection(collectionName).doc(account.uid);

        final document = await reference.get();

        if (document.exists) {
          batch.update(reference, {
            'isActive': activate,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          updatedDocuments++;
        }
      }

      if (updatedDocuments == 0) {
        throw Exception('Account document could not be found.');
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activate
                ? '$name has been reactivated.'
                : '$name has been deactivated.',
          ),
          backgroundColor: activate ? Colors.green : darkPink,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update account: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --------------------------------------------------
  // ACCOUNT STATUS BADGE
  // --------------------------------------------------

  Widget _statusBadge(bool isActive) {
    final color = isActive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'DEACTIVATED',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --------------------------------------------------
  // COMBINE BOTH FIRESTORE USER COLLECTIONS
  // --------------------------------------------------

  Widget _buildAccounts(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> upperUsers,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> lowerUsers,
  ) {
    final Map<String, _AccountRecord> accounts = {};

    for (final doc in lowerUsers) {
      accounts[doc.id] = _AccountRecord(
        uid: doc.id,
        data: Map<String, dynamic>.from(doc.data()),
      );
    }

    for (final doc in upperUsers) {
      final existing = accounts[doc.id];

      accounts[doc.id] = _AccountRecord(
        uid: doc.id,
        data: {
          ...?existing?.data,
          ...doc.data(),
        },
      );
    }

    final allUsers = accounts.values.toList();

    allUsers.sort((a, b) {
      return _userName(a.data)
          .toLowerCase()
          .compareTo(_userName(b.data).toLowerCase());
    });

    final filteredUsers = allUsers.where((account) {
      final data = account.data;

      final name = _userName(data).toLowerCase();
      final email = _userEmail(data).toLowerCase();
      final role = _role(data);

      final matchesSearch = searchText.isEmpty ||
          name.contains(searchText) ||
          email.contains(searchText) ||
          role.contains(searchText);

      final matchesRole = selectedRole == 'All' ||
          role == selectedRole.toLowerCase();

      return matchesSearch && matchesRole;
    }).toList();

    final totalUsers = allUsers
        .where((account) => _role(account.data) == 'user')
        .length;

    final totalSellers = allUsers
        .where((account) => _role(account.data) == 'seller')
        .length;

    final totalAdmins = allUsers
        .where((account) => _role(account.data) == 'admin')
        .length;

    final totalInactive =
        allUsers.where((account) => !_isActive(account.data)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _summaryCard(
              'All Accounts',
              allUsers.length.toString(),
              Icons.people_outline,
              pink,
            ),
            _summaryCard(
              'Customers',
              totalUsers.toString(),
              Icons.person_outline,
              Colors.blue,
            ),
            _summaryCard(
              'Sellers',
              totalSellers.toString(),
              Icons.storefront_outlined,
              darkPink,
            ),
            _summaryCard(
              'Admins',
              totalAdmins.toString(),
              Icons.admin_panel_settings_outlined,
              Colors.orange,
            ),
            _summaryCard(
              'Deactivated',
              totalInactive.toString(),
              Icons.person_off_outlined,
              Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Registered Accounts',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${filteredUsers.length} accounts',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filteredUsers.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No users found.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final account = filteredUsers[index];
                            final data = account.data;

                            final name = _userName(data);
                            final email = _userEmail(data);
                            final role = _role(data);
                            final status = _sellerStatus(data);
                            final isActive = _isActive(data);

                            final roleColor = _roleColor(role);

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              leading: CircleAvatar(
                                radius: 23,
                                backgroundColor: roleColor.withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  _roleIcon(role),
                                  color: roleColor,
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isActive
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 7),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _statusBadge(isActive),
                                      if (role == 'seller')
                                        Text(
                                          'Seller: ${status.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: status == 'approved'
                                                ? Colors.green
                                                : status == 'rejected'
                                                    ? Colors.red
                                                    : Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (role == 'seller') ...[
                                    const SizedBox(height: 7),
                                    FutureBuilder<String>(
                                      future: _getStoreName(
                                        account.uid,
                                        data,
                                      ),
                                      builder: (context, snapshot) {
                                        final storeName = snapshot.data ??
                                            'Loading shop name...';

                                        return Row(
                                          children: [
                                            const Icon(
                                              Icons.store_outlined,
                                              size: 14,
                                              color: darkPink,
                                            ),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                storeName,
                                                style: const TextStyle(
                                                  color: darkPink,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              trailing: SizedBox(
                                width: 145,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        role.toUpperCase(),
                                        style: TextStyle(
                                          color: roleColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _changeAccountStatus(
                                        account,
                                        !isActive,
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: isActive
                                            ? Colors.red
                                            : Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: Icon(
                                        isActive
                                            ? Icons.block
                                            : Icons.check_circle_outline,
                                        size: 15,
                                      ),
                                      label: Text(
                                        isActive
                                            ? 'Deactivate'
                                            : 'Reactivate',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // SUMMARY CARD
  // --------------------------------------------------

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // MAIN SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: background,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Management',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'View, monitor, and manage all registered Style4U accounts.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 22),

          // SEARCH AND FILTER
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name, email, or role...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchText = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text('All Roles'),
                    ),
                    DropdownMenuItem(
                      value: 'user',
                      child: Text('Customers'),
                    ),
                    DropdownMenuItem(
                      value: 'seller',
                      child: Text('Sellers'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Admins'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      selectedRole = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // READ BOTH FIRESTORE USER COLLECTIONS
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .snapshots(),
              builder: (context, upperSnapshot) {
                return StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, lowerSnapshot) {
                    if (upperSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        lowerSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: pink,
                        ),
                      );
                    }

                    if (upperSnapshot.hasError &&
                        lowerSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load accounts.\n'
                          '${upperSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final upperUsers =
                        upperSnapshot.data?.docs ?? [];

                    final lowerUsers =
                        lowerSnapshot.data?.docs ?? [];

                    return _buildAccounts(
                      context,
                      upperUsers,
                      lowerUsers,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// ACCOUNT MODEL
// --------------------------------------------------

class _AccountRecord {
  final String uid;
  final Map<String, dynamic> data;

  const _AccountRecord({
    required this.uid,
    required this.data,
  });
}
