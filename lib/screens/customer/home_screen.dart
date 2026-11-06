
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  final String role;

  const HomeScreen({
    super.key,
    this.role = 'user',
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('Style4U'),
        backgroundColor: const Color(0xFFD96B91),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Color(0xFFD96B91),
            ),
            const SizedBox(height: 20),

            const Text(
              'Welcome to Style4U!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF79515F),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              isAdmin ? 'Admin Dashboard' : 'Happy Shopping!',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF79515F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
