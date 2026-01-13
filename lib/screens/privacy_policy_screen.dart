import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Privacy Policy',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: January 12, 2026',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),

          _buildSection(
            context,
            'Introduction',
            'BrownPaw ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
          ),

          _buildSection(
            context,
            'Information We Collect',
            'We collect information that you provide directly to us, including:\n\n'
                '• Account Information: When you create an account, we collect your email address, display name, and optional profile picture.\n\n'
                '• Activity Data: Information about your river descents, including river runs, dates, flows, ratings, notes, and photos you choose to share.\n\n'
                '• Usage Data: Information about how you use the app, such as favorited runs and app preferences.\n\n'
                '• Location Data: With your permission, we may collect your location to show nearby river runs on the map.',
          ),

          _buildSection(
            context,
            'How We Use Your Information',
            'We use the information we collect to:\n\n'
                '• Provide, maintain, and improve our services\n\n'
                '• Create and manage your account\n\n'
                '• Store and display your river descent logs\n\n'
                '• Show you relevant river run information based on your location and preferences\n\n'
                '• Communicate with you about updates and features\n\n'
                '• Ensure the security and integrity of our services',
          ),

          _buildSection(
            context,
            'Data Storage and Security',
            'Your data is stored securely using Firebase services, which employ industry-standard security measures. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
          ),

          _buildSection(
            context,
            'Third-Party Services',
            'We use the following third-party services:\n\n'
                '• Firebase (Google): For authentication, database, and storage\n\n'
                '• Google Sign-In: For account authentication\n\n'
                '• Apple Sign-In: For account authentication (iOS only)\n\n'
                '• Environment Canada: For river flow data\n\n'
                'These services may collect information used to identify you. Please refer to their respective privacy policies for more information.',
          ),

          _buildSection(
            context,
            'Data Sharing and Public Information',
            'By default, your descent logs are private and only visible to you. If you choose to make a descent public:\n\n'
                '• Your display name and descent details will be visible to other users\n\n'
                '• Your photos (if uploaded) will be visible to other users\n\n'
                '• Your email address and other personal information remain private\n\n'
                'We do not sell your personal information to third parties.',
          ),

          _buildSection(
            context,
            'Your Rights and Choices',
            'You have the right to:\n\n'
                '• Access and update your personal information through the app settings\n\n'
                '• Delete your account and associated data at any time\n\n'
                '• Choose whether to share your location\n\n'
                '• Control the visibility of your descent logs (public or private)\n\n'
                '• Opt out of non-essential communications',
          ),

          _buildSection(
            context,
            'Children\'s Privacy',
            'BrownPaw is not intended for use by children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.',
          ),

          _buildSection(
            context,
            'Data Retention',
            'We retain your personal information for as long as your account is active or as needed to provide you services. When you delete your account, we delete all associated personal data, including:\n\n'
                '• Your account information\n\n'
                '• Your descent logs\n\n'
                '• Your uploaded photos\n\n'
                'Some anonymized usage data may be retained for analytics purposes.',
          ),

          _buildSection(
            context,
            'Changes to This Privacy Policy',
            'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.',
          ),

          _buildSection(
            context,
            'Contact Us',
            'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                'Email: privacy@brownpaw.com\n\n'
                'We will respond to your inquiry within 30 days.',
          ),

          const SizedBox(height: 32),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Text(
            'Your Consent',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'By using BrownPaw, you consent to our Privacy Policy and agree to its terms.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
