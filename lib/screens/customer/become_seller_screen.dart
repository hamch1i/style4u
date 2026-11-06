
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BecomeSellerScreen extends StatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  State<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends State<BecomeSellerScreen> {
  final Color pink = const Color(0xFFD96B91);

  final TextEditingController storeNameController =
      TextEditingController();
  final TextEditingController reasonController =
      TextEditingController();

  bool isLoading = true;
  bool isSubmitting = false;

  String applicantName = '';
  String applicantEmail = '';
  String currentStatus = '';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>> get profileReference {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid);
  }

  DocumentReference<Map<String, dynamic>> get requestReference {
    return FirebaseFirestore.instance
        .collection('seller_requests')
        .doc(currentUser!.uid);
  }

  @override
  void initState() {
    super.initState();
    loadApplicationData();
  }

  @override
  void dispose() {
    storeNameController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  Future<void> loadApplicationData() async {
    final user = currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final results = await Future.wait([
        profileReference.get(),
        requestReference.get(),
      ]);

      final profileData = results[0].data() ?? {};
      final requestData = results[1].data() ?? {};

      applicantName = (profileData['name'] ?? '').toString();
      applicantEmail = user.email ?? '';

      currentStatus = (requestData['status'] ?? '').toString();

      if (requestData.isNotEmpty) {
        storeNameController.text =
            (requestData['storeName'] ?? '').toString();

        reasonController.text =
            (requestData['reason'] ?? '').toString();
      }
    } catch (e) {
      showMessage('Unable to load seller application information.');
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> submitApplication() async {
    final user = currentUser;

    if (user == null) {
      showMessage('Please log in again.');
      return;
    }

    final storeName = storeNameController.text.trim();
    final reason = reasonController.text.trim();

    if (storeName.isEmpty) {
      showMessage('Please enter your desired store name.');
      return;
    }

    if (reason.isEmpty) {
      showMessage('Please explain why you want to become a seller.');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.runTransaction((transaction) async {
        final profileSnapshot =
            await transaction.get(profileReference);

        final requestSnapshot =
            await transaction.get(requestReference);

        final profileData = profileSnapshot.data() ?? {};
        final role = (profileData['role'] ?? 'user')
            .toString()
            .toLowerCase();

        if (role == 'seller') {
          throw Exception('ALREADY_SELLER');
        }

        final existingStatus =
            (requestSnapshot.data()?['status'] ?? '')
                .toString()
                .toLowerCase();

        if (existingStatus == 'pending') {
          throw Exception('REQUEST_PENDING');
        }

        if (existingStatus == 'approved') {
          throw Exception('REQUEST_APPROVED');
        }

        transaction.set(
          requestReference,
          {
            'userId': user.uid,
            'applicantName':
                (profileData['name'] ?? applicantName).toString(),
            'applicantEmail': user.email ?? '',
            'storeName': storeName,
            'reason': reason,
            'status': 'pending',
            'requestedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;

      setState(() {
        currentStatus = 'pending';
      });

      showMessage('Your seller application was submitted!');
    } catch (e) {
      final error = e.toString();

      if (error.contains('ALREADY_SELLER')) {
        showMessage('Your account is already a seller.');
      } else if (error.contains('REQUEST_PENDING')) {
        showMessage('You already have a pending application.');
        await loadApplicationData();
      } else if (error.contains('REQUEST_APPROVED')) {
        showMessage('Your seller application is already approved.');
        await loadApplicationData();
      } else {
        showMessage('Unable to submit application. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
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

  Widget buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, color: pink),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Become a Style4U Seller',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Submit your application to open your own store on Style4U. '
            'Your application will be reviewed by the administrator '
            'before seller access is granted.',
            style: TextStyle(
              color: Colors.black54,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusCard() {
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_top;

    String title = 'Application Pending';
    String description =
        'Your application has been submitted and is waiting for admin approval.';

    if (currentStatus == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      title = 'Application Approved';
      description =
          'Your application has been approved. Your seller access will be handled by the administrator.';
    } else if (currentStatus == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
      title = 'Application Rejected';
      description =
          'Your previous application was rejected. You may update your details and submit another request.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, color: statusColor, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: pink),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: pink, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: value),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: pink),
            suffixIcon: const Icon(
              Icons.lock_outline,
              color: Colors.grey,
              size: 18,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = currentStatus == 'pending';
    final isApproved = currentStatus == 'approved';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('Become a Seller'),
        backgroundColor: pink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: pink),
            )
          : currentUser == null
              ? const Center(
                  child: Text('Please log in to continue.'),
                )
              : isApproved
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildStatusCard(),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildInformationCard(),
                          const SizedBox(height: 22),

                          if (isPending) ...[
                            buildStatusCard(),
                            const SizedBox(height: 20),
                          ],

                          if (currentStatus == 'rejected') ...[
                            buildStatusCard(),
                            const SizedBox(height: 20),
                          ],

                          const Text(
                            'Applicant Information',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          buildReadOnlyField(
                            label: 'Full Name',
                            value: applicantName,
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),

                          buildReadOnlyField(
                            label: 'Email Address',
                            value: applicantEmail,
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 22),

                          const Text(
                            'Store Information',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          buildTextField(
                            label: 'Store Name',
                            hint: 'Enter your desired store name',
                            controller: storeNameController,
                            icon: Icons.store_outlined,
                          ),
                          const SizedBox(height: 16),

                          buildTextField(
                            label: 'Why do you want to become a seller?',
                            hint: 'Tell us about your store and products...',
                            controller: reasonController,
                            icon: Icons.edit_note,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 25),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isPending || isSubmitting
                                  ? null
                                  : submitApplication,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: pink,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    pink.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      isPending
                                          ? 'Waiting for Admin Approval'
                                          : 'Submit Seller Request',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
