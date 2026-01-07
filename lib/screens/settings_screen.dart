import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Remove package_info_plus import for now - can be added back later if needed
// import 'package:package_info_plus/package_info_plus.dart';
import '../providers/user_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Remove PackageInfo dependency for now
  // PackageInfo? packageInfo;

  @override
  void initState() {
    super.initState();
    // Remove package info initialization for now
    // _initPackageInfo();
  }

  // Keep the method but make it optional
  // Future<void> _initPackageInfo() async {
  //   try {
  //     final info = await PackageInfo.fromPlatform();
  //     setState(() {
  //       packageInfo = info;
  //     });
  //   } catch (e) {
  //     // Plugin not properly initialized, use fallback values
  //     debugPrint('Package info plugin error: $e');
  //     // Don't set packageInfo, let the UI use fallback values
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final userNotifier = ref.read(userProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Details Section
          if (userState.isAuthenticated) ...[
            _buildSectionHeader('Account'),
            const SizedBox(height: 8),
            _buildUserInfoCard(userState),
            const SizedBox(height: 24),

            // Account Actions
            _buildSectionHeader('Account Actions'),
            const SizedBox(height: 8),
            _buildSignOutTile(userNotifier),
            const SizedBox(height: 8),
            _buildDeleteAccountTile(context, userNotifier),
            const SizedBox(height: 32),
          ],

          // App Information Section
          _buildSectionHeader('App Information'),
          const SizedBox(height: 8),
          _buildAppInfoCard(),
          const SizedBox(height: 32),

          // About Section
          _buildSectionHeader('About'),
          const SizedBox(height: 8),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildUserInfoCard(UserData userState) {
    final user = userState.user;
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? Text(
                          user.displayName?.substring(0, 1).toUpperCase() ??
                              user.email?.substring(0, 1).toUpperCase() ??
                              'U',
                          style: const TextStyle(fontSize: 24),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'Unknown User',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? 'No email',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (userState.userData != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildUserDataRow(
                'Member since',
                _formatDate(userState.userData!['createdAt']),
              ),
              if (userState.userData!['lastSignIn'] != null)
                _buildUserDataRow(
                  'Last sign in',
                  _formatDate(userState.userData!['lastSignIn']),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildSignOutTile(UserNotifier userNotifier) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Sign Out'),
        subtitle: const Text('Sign out of your account'),
        onTap: () async {
          final shouldSignOut = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );

          if (shouldSignOut == true) {
            await userNotifier.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out successfully')),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildDeleteAccountTile(
    BuildContext context,
    UserNotifier userNotifier,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text('Delete Account'),
        subtitle: const Text('Permanently delete your account and all data'),
        onTap: () => _showDeleteAccountDialog(context, userNotifier),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    UserNotifier userNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text('Delete Account'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'This includes:\n• Your profile information\n• Saved favorites\n• River run history\n• All personal data',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteAccount(userNotifier);
    }
  }

  Future<void> _deleteAccount(UserNotifier userNotifier) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      await userNotifier.deleteAccount();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Check if there was an error
        final userState = ref.read(userProvider);
        if (userState.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userState.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          // Account deleted successfully
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to login/home screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAppInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('App Name', 'BrownPaw'),
            _buildInfoRow('Version', '1.0.0'),
            _buildInfoRow('Build Number', '1'),
            _buildInfoRow('Package Name', 'com.brownpaw.app'),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BrownPaw',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your companion for tracking river conditions and planning your next whitewater adventure.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Copyright', '© ${DateTime.now().year} BrownPaw'),
            _buildInfoRow('Developer', 'BrownPaw Team'),
            const SizedBox(height: 16),
            Text(
              'Made with ❤️ for the whitewater community',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp.toString().contains('Timestamp')) {
        // Firebase Timestamp
        date = timestamp.toDate();
      } else {
        return 'Unknown';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
