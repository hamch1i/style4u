
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class SellerAddProductScreen extends StatefulWidget {
  const SellerAddProductScreen({super.key});

  @override
  State<SellerAddProductScreen> createState() =>
      _SellerAddProductScreenState();
}

class _SellerAddProductScreenState
    extends State<SellerAddProductScreen> {
  static const Color pink = Color(0xFFD96B91);
  static const Color darkPink = Color(0xFF79515F);
  static const Color background = Color(0xFFFFF8FA);

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

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

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select image: $e'),
        ),
      );
    }
  }

  Future<String> uploadImageToCloudinary() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      throw Exception('Please select a product image.');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/f3ivl9wg/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = 'style4u_products';
    request.fields['folder'] = 'style4u/products';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        _selectedImageBytes!,
        filename: _selectedImage!.name,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception('Image upload failed: $responseBody');
    }

    final result = jsonDecode(responseBody);

    final imageUrl = result['secure_url']?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Cloudinary did not return an image URL.');
    }

    return imageUrl;
  }

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null || _selectedImageBytes == null) {
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
      final sellerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(seller.uid)
          .get();

      if (!sellerDoc.exists) {
        throw Exception('Seller account information not found.');
      }

      final sellerData = sellerDoc.data() ?? {};

      if (sellerData['role'] != 'seller') {
        throw Exception('This account is not registered as a seller.');
      }

      if (sellerData['sellerStatus'] != 'approved') {
        throw Exception('Your seller account is not yet approved.');
      }

      final storeName =
          (sellerData['storeName'] ?? 'My Shop').toString();

      final imageUrl = await uploadImageToCloudinary();

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

  Widget buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: darkPink,
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint) {
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
        borderSide: const BorderSide(
          color: Color(0xFFE8C9D4),
        ),
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

  Widget buildTextField({
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
      decoration: inputDecoration(hint),
    );
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
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: pink,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Information',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: darkPink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add a new item to your store.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 28),

                      buildLabel('Product Image'),

                      InkWell(
                        onTap: _isLoading ? null : pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          height: 260,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: pink),
                          ),
                          child: _selectedImageBytes == null
                              ? const Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 55,
                                      color: pink,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Click to select product image',
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Choose an image from your computer',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    width: double.infinity,
                                    height: 260,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      buildLabel('Product Name'),
                      buildTextField(
                        controller: _nameController,
                        hint: 'Enter product name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Product name is required.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      buildLabel('Description'),
                      buildTextField(
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

                      const SizedBox(height: 18),

                      buildLabel('Price (₱)'),
                      buildTextField(
                        controller: _priceController,
                        hint: 'Enter product price',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final price = double.tryParse(
                            value?.trim() ?? '',
                          );

                          if (price == null || price <= 0) {
                            return 'Enter a valid price.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      buildLabel('Stock Quantity'),
                      buildTextField(
                        controller: _stockController,
                        hint: 'Enter available stock',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final stock = int.tryParse(
                            value?.trim() ?? '',
                          );

                          if (stock == null || stock < 0) {
                            return 'Enter a valid stock quantity.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      buildLabel('Category'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: inputDecoration('Select category'),
                        items: categories.map((category) {
                          return DropdownMenuItem<String>(
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

                      const SizedBox(height: 18),

                      buildLabel('Gender'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: inputDecoration('Select gender'),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem<String>(
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
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : saveProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isLoading
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
                            _isLoading ? 'Saving...' : 'Save Product',
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
