
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  static const Color pink = Color(0xFFD96B91);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('Style4U'),
        backgroundColor: pink,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: pink),
            SizedBox(height: 20),
            Text(
              'Welcome to Style4U!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF79515F),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Discover your style.',
              style: TextStyle(color: Color(0xFF79515F)),
            ),
          ],
        ),
      ),
    );
  }
}
