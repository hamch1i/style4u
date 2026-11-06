
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class SellerEditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const SellerEditProductScreen({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<SellerEditProductScreen> createState() =>
      _SellerEditProductScreenState();
}

class _SellerEditProductScreenState
    extends State<SellerEditProductScreen> {
  static const Color pink = Color(0xFFD96B91);
  static const Color background = Color(0xFFFDF7F9);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Tops',
    'Bottoms',
    'Dresses',
    'Outerwear',
    'Shoes',
    'Accessories',
  ];

  final List<String> _genders = [
    'Female',
    'Male',
  ];

  late String _category;
  late String _gender;
  late String _imageUrl;
  late bool _isActive;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final data = widget.productData;

    _nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: data['description']?.toString() ?? '',
    );

    _priceController = TextEditingController(
      text: data['price']?.toString() ?? '',
    );

    _stockController = TextEditingController(
      text: data['stock']?.toString() ?? '',
    );

    final savedCategory = data['category']?.toString() ?? 'Tops';
    _category = _categories.contains(savedCategory)
        ? savedCategory
        : 'Tops';

    final savedGender = data['gender']?.toString() ?? 'Female';
    _gender = _genders.contains(savedGender)
        ? savedGender
        : 'Female';

    _imageUrl = data['imageUrl']?.toString() ?? '';
    _isActive = data['isActive'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
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
      _showMessage('Unable to select image: $e');
    }
  }

  Future<String> _uploadImage() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      return _imageUrl;
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

    if (response.statusCode != 200) {
      throw Exception('Image upload failed: $responseBody');
    }

    final result = jsonDecode(responseBody);

    final uploadedUrl = result['secure_url']?.toString();

    if (uploadedUrl == null || uploadedUrl.isEmpty) {
      throw Exception('Cloudinary did not return an image URL.');
    }

    return uploadedUrl;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final seller = FirebaseAuth.instance.currentUser;

    if (seller == null) {
      _showMessage('Please log in again.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final sellerRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(seller.uid);

      final sellerSnapshot = await sellerRef.get();

      if (!sellerSnapshot.exists) {
        throw Exception('Seller account not found.');
      }

      final sellerData = sellerSnapshot.data()!;

      if (sellerData['role'] != 'seller' ||
          sellerData['sellerStatus'] != 'approved') {
        throw Exception('Your seller account is not approved.');
      }

      final productRef = sellerRef
          .collection('products')
          .doc(widget.productId);

      final productSnapshot = await productRef.get();

      if (!productSnapshot.exists) {
        throw Exception('This product no longer exists.');
      }

      // Upload a new image only if one was selected.
      final updatedImageUrl = await _uploadImage();

      // Update the existing product document.
      await productRef.update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock': int.parse(_stockController.text.trim()),
        'category': _category,
        'gender': _gender,
        'imageUrl': updatedImageUrl,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Unable to update product: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF444444),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8DCE1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE8DCE1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: pink, width: 1.5),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        width: double.infinity,
        height: 230,
        fit: BoxFit.cover,
      );
    }

    if (_imageUrl.isNotEmpty) {
      return Image.network(
        _imageUrl,
        width: double.infinity,
        height: 230,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }

    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 230,
      color: const Color(0xFFF8E8EE),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 55,
            color: pink,
          ),
          SizedBox(height: 8),
          Text(
            'No product image',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: _inputDecoration(hint),
          validator: validator ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required.';
                }
                return null;
              },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: _inputDecoration('Select $label'),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: _isSaving ? null : onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  color: Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: pink,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Product',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Update your product information',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF0E4E9),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product Image',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildImagePreview(),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _pickImage,
                              icon: const Icon(Icons.upload_outlined),
                              label: const Text('Change Image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: pink,
                                side: const BorderSide(color: pink),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            _buildTextField(
                              label: 'Product Name',
                              controller: _nameController,
                              hint: 'Enter product name',
                            ),
                            const SizedBox(height: 20),

                            _buildTextField(
                              label: 'Description',
                              controller: _descriptionController,
                              hint: 'Enter product description',
                              maxLines: 4,
                            ),
                            const SizedBox(height: 20),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 500) {
                                  return Column(
                                    children: [
                                      _buildTextField(
                                        label: 'Price',
                                        controller: _priceController,
                                        hint: '0.00',
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
                                      const SizedBox(height: 20),
                                      _buildTextField(
                                        label: 'Stock',
                                        controller: _stockController,
                                        hint: '0',
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
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        label: 'Price',
                                        controller: _priceController,
                                        hint: '0.00',
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
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: _buildTextField(
                                        label: 'Stock',
                                        controller: _stockController,
                                        hint: '0',
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
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 500) {
                                  return Column(
                                    children: [
                                      _buildDropdown(
                                        label: 'Category',
                                        value: _category,
                                        items: _categories,
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _category = value;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      _buildDropdown(
                                        label: 'Gender',
                                        value: _gender,
                                        items: _genders,
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _gender = value;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        label: 'Category',
                                        value: _category,
                                        items: _categories,
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _category = value;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: _buildDropdown(
                                        label: 'Gender',
                                        value: _gender,
                                        items: _genders,
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _gender = value;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: pink,
                                title: const Text(
                                  'Product Availability',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  _isActive
                                      ? 'Customers can see this product.'
                                      : 'This product is currently unavailable.',
                                ),
                                value: _isActive,
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _isActive = value;
                                        });
                                      },
                              ),
                            ),

                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveChanges,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: pink,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
