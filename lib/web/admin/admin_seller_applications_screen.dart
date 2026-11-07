
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminSellerApplicationsScreen extends StatefulWidget {
  const AdminSellerApplicationsScreen({super.key});

  @override
  State<AdminSellerApplicationsScreen> createState() =>
      _AdminSellerApplicationsScreenState();
}

class _AdminSellerApplicationsScreenState
    extends State<AdminSellerApplicationsScreen> {
  static const Color pink = Color(0xFFD96B91);
  static const Color darkPink = Color(0xFFB94F78);
  static const Color background = Color(0xFFFFF7FA);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String selectedFilter = 'pending';
  String? processingUid;

  CollectionReference<Map<String, dynamic>> get requests =>
      firestore.collection('seller_requests');

  String readText(dynamic value, [String fallback = 'Not provided']) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  String formatDate(dynamic value) {
    if (value is! Timestamp) return 'Date unavailable';

    final date = value.toDate();

    return '${date.month}/${date.day}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> confirmAction({
    required String title,
    required String message,
    required String action,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> approveApplication(
    String uid,
    Map<String, dynamic> application,
  ) async {
    final confirmed = await confirmAction(
      title: 'Approve Seller Application',
      message:
          'Approve ${readText(application['applicantName'])} '
          'as a Style4U seller?',
      action: 'Approve',
      color: Colors.green,
    );

    if (!confirmed) return;

    setState(() => processingUid = uid);

    try {
      final requestRef = requests.doc(uid);
      final lowercaseRef = firestore.collection('users').doc(uid);
      final uppercaseRef = firestore.collection('Users').doc(uid);

      await firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);
        final lowercaseSnapshot = await transaction.get(lowercaseRef);
        final uppercaseSnapshot = await transaction.get(uppercaseRef);

        if (!requestSnapshot.exists) {
          throw Exception('Application does not exist.');
        }

        final requestData = requestSnapshot.data()!;
        final status =
            (requestData['status'] ?? '').toString().toLowerCase();

        if (status != 'pending') {
          throw Exception('This application has already been reviewed.');
        }

        if (!lowercaseSnapshot.exists && !uppercaseSnapshot.exists) {
          throw Exception('Customer account was not found.');
        }

        final storeName = readText(
          requestData['storeName'],
          '',
        );

        if (storeName.isEmpty) {
          throw Exception('Store name is missing.');
        }

        final updateData = <String, dynamic>{
          'role': 'seller',
          'sellerStatus': 'approved',
          'storeName': storeName,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (lowercaseSnapshot.exists) {
          transaction.update(lowercaseRef, updateData);
        }

        if (uppercaseSnapshot.exists) {
          transaction.update(uppercaseRef, updateData);
        } else {
          final profileData = lowercaseSnapshot.data() ?? {};

          transaction.set(uppercaseRef, {
            ...profileData,
            ...updateData,
            'uid': uid,
          });
        }

        transaction.update(requestRef, {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        });
      });

      showMessage('Seller application approved successfully.');
    } catch (error) {
      showMessage(
        'Approval failed: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => processingUid = null);
    }
  }

  Future<void> rejectApplication(
    String uid,
    Map<String, dynamic> application,
  ) async {
    final confirmed = await confirmAction(
      title: 'Reject Seller Application',
      message:
          'Reject ${readText(application['applicantName'])}\'s application?',
      action: 'Reject',
      color: Colors.red,
    );

    if (!confirmed) return;

    setState(() => processingUid = uid);

    try {
      await firestore.runTransaction((transaction) async {
        final requestRef = requests.doc(uid);
        final snapshot = await transaction.get(requestRef);

        if (!snapshot.exists) {
          throw Exception('Application does not exist.');
        }

        final status =
            (snapshot.data()?['status'] ?? '').toString().toLowerCase();

        if (status != 'pending') {
          throw Exception('This application has already been reviewed.');
        }

        transaction.update(requestRef, {
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        });
      });

      showMessage('Seller application rejected.');
    } catch (error) {
      showMessage(
        'Rejection failed: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => processingUid = null);
    }
  }

  Widget statusBadge(String status) {
    final normalized = status.toLowerCase();

    final color = normalized == 'approved'
        ? Colors.green
        : normalized == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget summaryCard(String title, int count, IconData icon, Color color) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: darkPink),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget applicationCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final uid = document.id;
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final isProcessing = processingUid == uid;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFCE8EF),
                child: Icon(Icons.storefront_outlined, color: darkPink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      readText(data['storeName']),
                      style: const TextStyle(
                        color: darkPink,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(readText(data['applicantName'])),
                  ],
                ),
              ),
              statusBadge(status),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          infoRow(
            Icons.email_outlined,
            'Email',
            readText(data['applicantEmail']),
          ),
          infoRow(Icons.person_outline, 'User ID', uid),
          infoRow(
            Icons.calendar_today_outlined,
            'Submitted',
            formatDate(data['requestedAt']),
          ),
          const Text(
            'Reason for becoming a seller',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(readText(data['reason'])),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => rejectApplication(uid, data),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => approveApplication(uid, data),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(isProcessing ? 'Processing...' : 'Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 55, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            selectedFilter == 'pending'
                ? 'There are no pending seller applications.'
                : 'No seller applications found.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seller Applications',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            Text(
              'Review customer requests to become Style4U sellers.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 25),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: requests.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load seller applications. Check Firestore permissions.',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: pink),
                    ),
                  );
                }

                final documents = snapshot.data!.docs;

                final pending = documents
                    .where((doc) =>
                        (doc.data()['status'] ?? 'pending')
                            .toString()
                            .toLowerCase() ==
                        'pending')
                    .length;

                final approved = documents
                    .where((doc) =>
                        (doc.data()['status'] ?? '')
                            .toString()
                            .toLowerCase() ==
                        'approved')
                    .length;

                final rejected = documents
                    .where((doc) =>
                        (doc.data()['status'] ?? '')
                            .toString()
                            .toLowerCase() ==
                        'rejected')
                    .length;

                final filtered = documents.where((doc) {
                  final status = (doc.data()['status'] ?? 'pending')
                      .toString()
                      .toLowerCase();

                  return selectedFilter == 'all' ||
                      status == selectedFilter;
                }).toList();

                filtered.sort((a, b) {
                  final aDate = a.data()['requestedAt'];
                  final bDate = b.data()['requestedAt'];

                  final aTime = aDate is Timestamp
                      ? aDate.millisecondsSinceEpoch
                      : 0;
                  final bTime = bDate is Timestamp
                      ? bDate.millisecondsSinceEpoch
                      : 0;

                  return bTime.compareTo(aTime);
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        summaryCard(
                          'Pending',
                          pending,
                          Icons.pending_actions_outlined,
                          Colors.orange,
                        ),
                        summaryCard(
                          'Approved',
                          approved,
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                        summaryCard(
                          'Rejected',
                          rejected,
                          Icons.cancel_outlined,
                          Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Applications',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DropdownButton<String>(
                          value: selectedFilter,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('Pending'),
                            ),
                            DropdownMenuItem(
                              value: 'approved',
                              child: Text('Approved'),
                            ),
                            DropdownMenuItem(
                              value: 'rejected',
                              child: Text('Rejected'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Applications'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedFilter = value);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      emptyState()
                    else
                      ...filtered.map(applicationCard),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
