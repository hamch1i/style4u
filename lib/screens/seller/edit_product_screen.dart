
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditProductScreen({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  static const Color pink = Color(0xFFD96B91);
  static const Color background = Color(0xFFFFF8FA);
  static const Color darkPink = Color(0xFF79515F);

  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController stockController;

  final ImagePicker picker = ImagePicker();

  File? selectedImage;
  String? imageUrl;

  late String selectedCategory;
  late String selectedGender;

  bool isLoading = false;

  final List<String> categories = [
    'Tops',
    'Bottoms',
    'Dresses',
    'Outerwear',
    'Shoes',
    'Accessories',
  ];

  final List<String> genders = [
    'Female',
    'Male',
  ];

  @override
  void initState() {
    super.initState();

    final data = widget.productData;

    nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );

    descriptionController = TextEditingController(
      text: data['description']?.toString() ?? '',
    );

    priceController = TextEditingController(
      text: data['price']?.toString() ?? '',
    );

    stockController = TextEditingController(
      text: data['stock']?.toString() ?? '',
    );

    imageUrl = data['imageUrl']?.toString() ?? '';

    selectedCategory = data['category']?.toString() ?? 'Tops';
    selectedGender = data['gender']?.toString() ?? 'Female';

    // Keep an existing category available even if it is not
    // included in the current category list.
    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }

    if (!genders.contains(selectedGender)) {
      selectedGender = 'Female';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        selectedImage = File(image.path);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to select image: $e')),
      );
    }
  }

  Future<String?> uploadImage() async {
    if (selectedImage == null) return imageUrl;

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/f3ivl9wg/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = 'style4u_products';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        selectedImage!.path,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: $responseBody');
    }

    final decoded = Uri.decodeComponent(responseBody);
    final match = RegExp(r'"secure_url"\s*:\s*"([^"]+)"')
        .firstMatch(decoded);

    if (match == null) {
      throw Exception('Could not retrieve uploaded image URL.');
    }

    return match.group(1);
  }

  Future<void> saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final newImageUrl = await uploadImage();

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('products')
          .doc(widget.productId)
          .update({
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'price': double.parse(priceController.text.trim()),
        'stock': int.parse(stockController.text.trim()),
        'category': selectedCategory,
        'gender': selectedGender,
        'imageUrl': newImageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: pink),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: pink, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: pink,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Product Image',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: darkPink,
              ),
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: isLoading ? null : pickImage,
              child: Container(
                height: 210,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pink),
                ),
                clipBehavior: Clip.antiAlias,
                child: selectedImage != null
                    ? Image.file(
                        selectedImage!,
                        fit: BoxFit.cover,
                      )
                    : (imageUrl != null && imageUrl!.isNotEmpty)
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return const Icon(
                                Icons.image_not_supported_outlined,
                                color: pink,
                                size: 55,
                              );
                            },
                          )
                        : const Icon(
                            Icons.add_a_photo_outlined,
                            color: pink,
                            size: 55,
                          ),
              ),
            ),

            const SizedBox(height: 8),

            const Center(
              child: Text(
                'Tap the image to choose a new photo',
                style: TextStyle(color: darkPink),
              ),
            ),

            const SizedBox(height: 22),

            buildTextField(
              label: 'Product Name',
              controller: nameController,
              icon: Icons.shopping_bag_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a product name.';
                }
                return null;
              },
            ),

            buildTextField(
              label: 'Description',
              controller: descriptionController,
              icon: Icons.description_outlined,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description.';
                }
                return null;
              },
            ),

            buildTextField(
              label: 'Price (₱)',
              controller: priceController,
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');

                if (price == null || price <= 0) {
                  return 'Enter a valid price.';
                }

                return null;
              },
            ),

            buildTextField(
              label: 'Stock Quantity',
              controller: stockController,
              icon: Icons.inventory_2_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                final stock = int.tryParse(value?.trim() ?? '');

                if (stock == null || stock < 0) {
                  return 'Enter a valid stock quantity.';
                }

                return null;
              },
            ),

            const SizedBox(height: 4),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(
                  Icons.category_outlined,
                  color: pink,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                prefixIcon: const Icon(
                  Icons.people_outline,
                  color: pink,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: genders.map((gender) {
                return DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                );
              }).toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          selectedGender = value;
                        });
                      }
                    },
            ),

            const SizedBox(height: 25),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  isLoading ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
