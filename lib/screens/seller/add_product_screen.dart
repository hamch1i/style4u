
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color pink = Color(0xFFD96B91);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  String? _selectedCategory = 'Tops';
  String? _selectedGender = 'Female';

  bool _isLoading = false;

  final List<String> categories = [
    'Tops',
    'Bottoms',
    'Dresses',
    'Outerwear',
    'Shoes',
    'Accessories',
  ];

  Future<void> pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to select image: $e')),
      );
    }
  }

  Future<String> uploadImageToCloudinary() async {
    if (_selectedImage == null) {
      throw Exception('Please select a product image.');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/f3ivl9wg/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = 'style4u_products';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        _selectedImage!.path,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception('Image upload failed: ${response.body}');
    }

    final result = jsonDecode(response.body);

    return result['secure_url'];
  }

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product image.'),
        ),
      );
      return;
    }

    final seller = FirebaseAuth.instance.currentUser;

    if (seller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get seller information from Firestore.
      final sellerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(seller.uid)
          .get();

      if (!sellerDoc.exists) {
        throw Exception('Seller account information was not found.');
      }

      final sellerData = sellerDoc.data() ?? {};

      if (sellerData['role'] != 'seller') {
        throw Exception('This account is not registered as a seller.');
      }

      if (sellerData['sellerStatus'] != 'approved') {
        throw Exception('Your seller account is not yet approved.');
      }

      // Use the seller's actual store name.
      final storeName =
          (sellerData['storeName'] ?? 'Urban Thread').toString();

      // Upload product image to Cloudinary.
      final imageUrl = await uploadImageToCloudinary();

      // Save product under Users/{sellerUID}/products.
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(seller.uid)
          .collection('products')
          .add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock': int.parse(_stockController.text.trim()),
        'category': _selectedCategory,
        'gender': _selectedGender,
        'imageUrl': imageUrl,
        'isActive': true,
        'sellerId': seller.uid,
        'storeName': storeName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('Add Product'),
        backgroundColor: pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product Information',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF79515F),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Product Image',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: _isLoading ? null : pickImage,
                child: Container(
                  width: double.infinity,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pink),
                  ),
                  child: _selectedImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 55,
                              color: pink,
                            ),
                            SizedBox(height: 8),
                            Text('Tap to select product image'),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 55,
                                  color: pink,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              _buildLabel('Product Name'),

              _buildTextField(
                controller: _nameController,
                hint: 'Enter product name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Product name is required.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              _buildLabel('Description'),

              _buildTextField(
                controller: _descriptionController,
                hint: 'Enter product description',
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              _buildLabel('Price (₱)'),

              _buildTextField(
                controller: _priceController,
                hint: 'Enter product price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final price = double.tryParse(value ?? '');

                  if (price == null || price <= 0) {
                    return 'Enter a valid price.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 15),

              _buildLabel('Stock Quantity'),

              _buildTextField(
                controller: _stockController,
                hint: 'Enter available stock',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final stock = int.tryParse(value ?? '');

                  if (stock == null || stock < 0) {
                    return 'Enter a valid stock quantity.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 15),

              _buildLabel('Category'),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _inputDecoration('Select category'),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
              ),

              const SizedBox(height: 15),

              _buildLabel('Gender'),

              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: _inputDecoration('Select gender'),
                items: const [
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text('Female'),
                  ),
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text('Male'),
                  ),
                ],
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Save Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF79515F),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8C9D4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: pink,
          width: 1.5,
        ),
      ),
    );
  }
}
