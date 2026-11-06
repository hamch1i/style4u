
import 'package:flutter/material.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  final bool isPrivacyPolicy;

  const TermsAndPrivacyScreen({
    super.key,
    required this.isPrivacyPolicy,
  });

  final Color pink = const Color(0xFFD96B91);
  final Color darkBrown = const Color(0xFF59444F);

  @override
  Widget build(BuildContext context) {
    final title = isPrivacyPolicy
        ? 'Privacy Policy'
        : 'Terms and Conditions';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF59444F),
          ),
        ),
        backgroundColor: const Color(0xFFF8D4D9),
        foregroundColor: darkBrown,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF3C9),
              Color(0xFFFFE7D8),
              Color(0xFFF8D4D9),
              Color(0xFFF1C6D9),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(22),
              ),
              child: isPrivacyPolicy
                  ? _buildPrivacyPolicy()
                  : _buildTerms(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: pink,
        ),
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: darkBrown,
        ),
      ),
    );
  }

  Widget _buildTerms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Icon(
            Icons.shopping_bag_rounded,
            size: 48,
            color: pink,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'STYLE4U',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: pink,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Center(
          child: Text(
            'Terms and Conditions',
            style: TextStyle(
              fontSize: 16,
              color: darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        _heading('1. Acceptance of Terms'),
        _paragraph(
          'By creating an account and using Style4U, '
          'you agree to follow these Terms and Conditions. '
          'If you do not agree, please do not use the platform.',
        ),

        _heading('2. User Accounts'),
        _paragraph(
          'Users must provide accurate and complete information '
          'when creating an account. You are responsible for '
          'maintaining the confidentiality of your login credentials '
          'and for activities performed through your account.',
        ),

        _heading('3. Customer Responsibilities'),
        _paragraph(
          'Customers may browse products, search for items, '
          'manage their shopping cart, place orders, and update '
          'their profile information. Customers must provide '
          'accurate information when making purchases.',
        ),

        _heading('4. Seller Responsibilities'),
        _paragraph(
          'Sellers may access seller features only after '
          'approval by the Style4U administrator. Sellers are '
          'responsible for providing accurate product names, '
          'descriptions, prices, categories, and product images. '
          'Sellers must manage only their own listed products.',
        ),

        _heading('5. Product Information'),
        _paragraph(
          'Style4U aims to provide accurate product information. '
          'However, customers should review product descriptions, '
          'prices, and other available details before purchasing. '
          'Product availability may change.',
        ),

        _heading('6. Orders and Purchases'),
        _paragraph(
          'Customers are responsible for reviewing their cart '
          'and order information before confirming a purchase. '
          'Order processing, payment, delivery, cancellation, '
          'and refund arrangements must follow the policies '
          'provided by the platform and its authorized sellers.',
        ),

        _heading('7. Prohibited Activities'),
        _paragraph(
          'Users and sellers must not provide false information, '
          'misuse another person’s account, upload misleading '
          'content, or engage in activities that disrupt or '
          'compromise the platform.',
        ),

        _heading('8. Account Suspension'),
        _paragraph(
          'Style4U administrators may review accounts and '
          'take appropriate action when users or sellers '
          'violate platform rules or misuse the service.',
        ),

        _heading('9. Changes to These Terms'),
        _paragraph(
          'Style4U may update these Terms and Conditions '
          'when necessary. Users will be informed of important '
          'changes through the platform when applicable.',
        ),

        _heading('10. Contact and Questions'),
        _paragraph(
          'For questions or concerns regarding these terms, '
          'please contact the authorized Style4U administrator '
          'through the official support channel.',
        ),

        const SizedBox(height: 20),
        Center(
          child: Text(
            'Thank you for choosing Style4U!',
            style: TextStyle(
              color: pink,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Icon(
            Icons.privacy_tip_rounded,
            size: 48,
            color: pink,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'STYLE4U',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: pink,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Center(
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              fontSize: 16,
              color: darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        _heading('1. Introduction'),
        _paragraph(
          'Style4U values the privacy of its users. '
          'This Privacy Policy explains the personal information '
          'that may be collected and how it is used when '
          'accessing the platform.',
        ),

        _heading('2. Information We Collect'),
        _paragraph(
          'When you create an account, Style4U collects '
          'information such as your full name, email address, '
          'password authentication data, and account type.',
        ),
        _paragraph(
          'Additional information may be processed when you '
          'use platform features, such as profile details, '
          'shopping cart information, orders, and seller product '
          'information.',
        ),

        _heading('3. How We Use Your Information'),
        _paragraph(
          'Your information may be used to create and manage '
          'your account, verify login credentials, identify '
          'account roles, provide shopping features, process '
          'orders, and manage seller approval.',
        ),

        _heading('4. Data Storage and Security'),
        _paragraph(
          'Style4U uses Firebase services for account '
          'authentication and database storage. Reasonable '
          'security measures should be maintained to protect '
          'stored information against unauthorized access, '
          'loss, or misuse.',
        ),

        _heading('5. Sharing of Information'),
        _paragraph(
          'Account information may be accessible to authorized '
          'administrators when necessary for account management '
          'and platform operations. Information should not be '
          'shared with unauthorized individuals.',
        ),

        _heading('6. Data Retention'),
        _paragraph(
          'Personal information is retained only for as long '
          'as necessary for legitimate platform purposes and '
          'applicable legal requirements. Account deletion '
          'and data removal requests should be handled through '
          'the authorized platform administrator.',
        ),

        _heading('7. User Rights'),
        _paragraph(
          'Users may request access to, correction of, or '
          'deletion of their personal information, subject '
          'to applicable laws and legitimate retention '
          'requirements.',
        ),

        _heading('8. Third-Party Services'),
        _paragraph(
          'Style4U uses Firebase services. These services '
          'may process information according to their own '
          'privacy policies and applicable service agreements.',
        ),

        _heading('9. Policy Updates'),
        _paragraph(
          'This Privacy Policy may be updated to reflect '
          'changes in platform features, data practices, '
          'or applicable requirements.',
        ),

        _heading('10. Contact'),
        _paragraph(
          'For privacy-related questions, concerns, or '
          'requests, contact the authorized Style4U '
          'administrator through the official support channel.',
        ),

        const SizedBox(height: 20),
        Center(
          child: Text(
            'Your privacy matters to us.',
            style: TextStyle(
              color: pink,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
