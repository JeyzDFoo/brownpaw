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
            'Last updated: November 24, 2026',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),

          _buildSection(
            context,
            'The short version',
            '• Brownpaw is a private logbook. Your runs are visible only to you.\n\n• We store what you put in the app (your account, logbook, starred gauges and alerts) so it syncs between your devices.\n\n• Your location never leaves your phone.\n\n• No ads, no tracking, no analytics, and we never sell or share your data.\n\n• You can delete your account and everything in it from Me at any time.',
          ),

          _buildSection(
            context,
            'What we store',
            'Your account: if you sign in with Apple or Google, your email address, name and a sign-in identifier (with Apple\'s Hide My Email we only see the relay address). If you continue without an account, only an anonymous identifier. You can add an optional profile photo.\n\nYour logbook: each run you log, its date, the river flow at the time, and anything you add such as notes, a rating, difficulty and who you paddled with.\n\nYour gauges and alerts: the gauges you star, the flow levels you want alerts for, and a push notification token per device.\n\nRuns you add: stored with your account and visible only to you.',
          ),

          _buildSection(
            context,
            'What we don\'t collect',
            '• Location. When you allow it, Brownpaw reads your location on your phone, only while the app is open, to suggest which run you\'re at and show runs near you. It is not sent to us.\n\n• Analytics, advertising or tracking.\n\n• Contacts, health data or browsing history.',
          ),

          _buildSection(
            context,
            'How we use it',
            'Only to run Brownpaw: to show your logbook on every device you sign in on, fill in river flows for your runs, and send the flow alerts you set up. We don\'t use your data for advertising and don\'t sell, rent or share it.',
          ),

          _buildSection(
            context,
            'Who processes it',
            '• Google Firebase (Authentication, Firestore, Storage, Cloud Messaging, Hosting) stores your data and delivers notifications for us.\n\n• Google and Apple handle sign-in if you choose them.\n\n• OpenStreetMap serves map tiles and sees your device\'s IP address when maps load.\n\nRiver levels come from public data from the Water Survey of Canada and other gauge operators. No personal data is sent to them.',
          ),

          _buildSection(
            context,
            'Security and storage',
            'Data is encrypted in transit and at rest on Google\'s servers, and security rules allow only you to read your logbook. The app keeps a copy on your device so it works without signal. Servers may be outside Canada.',
          ),

          _buildSection(
            context,
            'Keeping and deleting your data',
            'We keep your data while your account exists. You can delete any logbook entry at any time. Me > Delete account permanently deletes your account, logbook, profile photo, starred gauges and alerts, and revokes Apple sign-in if you used it. If you can\'t get into the app, email us and we\'ll delete it within 30 days.',
          ),

          _buildSection(
            context,
            'Your rights',
            'You can see and edit your data in the app. For a copy of your data or any privacy request, email us and we\'ll reply within 30 days. You can turn off location and notifications in your device settings; the app works without them.',
          ),

          _buildSection(
            context,
            'Children',
            'Brownpaw is not directed at children under 13, and we don\'t knowingly collect data from them. Contact us and we\'ll delete any such account.',
          ),

          _buildSection(
            context,
            'Changes',
            'If we change this policy we\'ll update the date above, and for significant changes we\'ll let you know in the app.',
          ),

          _buildSection(context, 'Contact', 'Email: privacy@brownpaw.app'),

          const SizedBox(height: 32),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Text(
            'On the web',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'The same policy is at brownclaw.web.app/privacy.',
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
