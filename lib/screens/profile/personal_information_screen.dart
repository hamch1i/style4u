
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class PersonalInformationScreen extends StatefulWidget {
  final String role;

  const PersonalInformationScreen({
    super.key,
    this.role = 'user',
  });

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  final Color pink = const Color(0xFFD96B91);

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingImage = false;

  String profileImageUrl = '';

  final String cloudName = 'f3ivl9wg';
  final String uploadPreset = 'style4u_products';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Sellers use Users; customers use users.
  String get collectionName {
    return widget.role.toLowerCase() == 'seller' ? 'Users' : 'users';
  }

  DocumentReference<Map<String, dynamic>> get profileReference {
    return FirebaseFirestore.instance
        .collection(collectionName)
        .doc(currentUser!.uid);
  }

  @override
  void initState() {
    super.initState();
    loadPersonalInformation();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> loadPersonalInformation() async {
    final user = currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final snapshot = await profileReference.get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        nameController.text = (data['name'] ?? '').toString();
        phoneController.text = (data['phone'] ?? '').toString();
        addressController.text = (data['address'] ?? '').toString();

        profileImageUrl =
            (data['profileImageUrl'] ?? '').toString();
      }
    } catch (e) {
      showMessage('Unable to load profile information.');
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> chooseProfilePicture() async {
    try {
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (image == null) return;

      setState(() => isUploadingImage = true);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        ),
      );

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'style4u/profiles';

      request.files.add(
        await http.MultipartFile.fromPath('file', image.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final result = jsonDecode(responseBody);
        final uploadedUrl = result['secure_url']?.toString() ?? '';

        if (uploadedUrl.isNotEmpty) {
          profileImageUrl = uploadedUrl;

          if (mounted) {
            setState(() {});
            showMessage('Profile picture uploaded.');
          }
        } else {
          showMessage('Unable to get uploaded image URL.');
        }
      } else {
        showMessage('Image upload failed. Please try again.');
      }
    } catch (e) {
      showMessage('Unable to upload profile picture.');
    } finally {
      if (mounted) {
        setState(() => isUploadingImage = false);
      }
    }
  }

  Future<void> saveChanges() async {
    final user = currentUser;

    if (user == null) {
      showMessage('Please log in again.');
      return;
    }

    if (nameController.text.trim().isEmpty) {
      showMessage('Please enter your full name.');
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      showMessage('Please enter your contact number.');
      return;
    }

    if (!RegExp(r'^09\d{9}$')
        .hasMatch(phoneController.text.trim())) {
      showMessage('Enter a valid Philippine mobile number.');
      return;
    }

    if (addressController.text.trim().isEmpty) {
      showMessage('Please enter your delivery address.');
      return;
    }

    setState(() => isSaving = true);

    try {
      await profileReference.set({
        'name': nameController.text.trim(),
        'email': user.email ?? '',
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'profileImageUrl': profileImageUrl,
        'role': widget.role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      showMessage('Personal information saved successfully.');
    } catch (e) {
      showMessage('Unable to save information. Please try again.');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
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

  Widget buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
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

  Widget buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          readOnly: true,
          controller: TextEditingController(
            text: currentUser?.email ?? '',
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.email_outlined, color: pink),
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
        const SizedBox(height: 5),
        const Text(
          'Your email comes from your registered account.',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget buildProfilePicture() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 57,
                backgroundColor: pink.withValues(alpha: 0.15),
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 58,
                        color: pink,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: isUploadingImage
                      ? null
                      : chooseProfilePicture,
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: pink,
                    child: isUploadingImage
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed:
                isUploadingImage ? null : chooseProfilePicture,
            child: Text(
              'Change Profile Picture',
              style: TextStyle(
                color: pink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('Personal Information'),
        backgroundColor: pink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: pink),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildProfilePicture(),
                  const SizedBox(height: 20),

                  const Text(
                    'Personal Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),

                  buildTextField(
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    controller: nameController,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 17),

                  buildEmailField(),
                  const SizedBox(height: 17),

                  buildTextField(
                    label: 'Contact Number',
                    hint: '09XXXXXXXXX',
                    controller: phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 17),

                  buildTextField(
                    label: 'Delivery Address',
                    hint: 'House number, street, barangay, city',
                    controller: addressController,
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving || isUploadingImage
                          ? null
                          : saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
