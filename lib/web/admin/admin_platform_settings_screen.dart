import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AdminPlatformSettingsScreen extends StatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  State<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends State<AdminPlatformSettingsScreen> {
  static const Color pink = Color(0xFFD96B91);

  static const String cloudName = 'f3ivl9wg';
  static const String uploadPreset = 'style4u_products';

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final ImagePicker picker = ImagePicker();

  final TextEditingController appNameController =
      TextEditingController();

  bool isSaving = false;
  bool isUploading = false;
  bool isActive = true;
  bool initialized = false;

  String currentLogoUrl = '';

  DocumentReference get settingsReference =>
      firestore.collection('AppSettings').doc('platform');

  @override
  void dispose() {
    appNameController.dispose();
    super.dispose();
  }

  Future<String> _uploadLogo(
    XFile selectedImage,
    Uint8List imageBytes,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'style4u/platform';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: selectedImage.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Cloudinary upload failed: ${response.body}',
      );
    }

    final result = jsonDecode(response.body);

    final secureUrl = result['secure_url'];

    if (secureUrl == null) {
      throw Exception('Cloudinary did not return an image URL.');
    }

    return secureUrl.toString();
  }

  Future<void> _chooseLogo() async {
    try {
      final selectedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (selectedImage == null) return;

      setState(() {
        isUploading = true;
      });

      final imageBytes = await selectedImage.readAsBytes();

      final uploadedUrl = await _uploadLogo(
        selectedImage,
        imageBytes,
      );

      if (!mounted) return;

      setState(() {
        currentLogoUrl = uploadedUrl;
        isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo uploaded successfully. Save changes to apply it.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo upload failed: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    final appName = appNameController.text.trim();

    if (appName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the application name.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await settingsReference.set({
        'appName': appName,
        'appLogoUrl': currentLogoUrl,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Platform settings saved successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _togglePlatform(bool value) async {
    final action = value ? 'reactivate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            value
                ? 'Reactivate Style4U?'
                : 'Deactivate Entire Platform?',
          ),
          content: Text(
            value
                ? 'The Style4U platform will be marked as active.'
                : 'The entire Style4U platform will be marked as inactive.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: value ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                value ? 'Reactivate' : 'Deactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await settingsReference.set({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        isActive = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Style4U platform $action' 'd.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update platform: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: settingsReference.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load platform settings.'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final data = snapshot.data!.data()
            as Map<String, dynamic>? ?? {};

        if (!initialized) {
          appNameController.text =
              (data['appName'] ?? 'Style4U').toString();

          currentLogoUrl =
              (data['appLogoUrl'] ?? '').toString();

          isActive = data['isActive'] ?? true;

          initialized = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Platform Settings',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage the global Style4U application branding '
                    'and platform status.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  _section(
                    title: 'Application Branding',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Application Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: appNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter application name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Application Logo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: pink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          child: currentLogoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(15),
                                  child: Image.network(
                                    currentLogoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(
                                      Icons.image_not_supported,
                                      size: 45,
                                      color: pink,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.shopping_bag,
                                  size: 55,
                                  color: pink,
                                ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed:
                              isUploading ? null : _chooseLogo,
                          icon: isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload),
                          label: Text(
                            isUploading ? 'Uploading...' : 'Upload Logo',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This changes the global Style4U logo, '
                          'not individual seller shop logos.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Platform Activation',
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Style4U Platform',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        isActive
                            ? 'The platform is currently active.'
                            : 'The platform is currently deactivated.',
                      ),
                      value: isActive,
                      activeThumbColor: pink,
                      onChanged: _togglePlatform,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed:
                          isSaving || isUploading ? null : _saveSettings,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isSaving ? 'Saving...' : 'Save Platform Settings',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pink,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
          const Divider(height: 28),
          child,
        ],
      ),
    );
  }
}