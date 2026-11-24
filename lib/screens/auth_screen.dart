import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brownpaw/providers/user_provider.dart';
import 'package:brownpaw/theme/app_theme.dart';

/// Sign-in, in the Riverstone look: silt paper, the paw in a pebble, and
/// one button per way in. Apple and Google show on every platform (the App
/// Store requires Apple wherever another social sign-in is offered).
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userProvider);
    final notifier = ref.read(userProvider.notifier);
    final p = Riverstone.of(context);
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final busy = userData.isLoading;

    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: Pebble.decoration(context),
                      child: ClipRRect(
                        borderRadius: Pebble.small,
                        child: Image.asset(
                          'images/brownpaw-logo.png',
                          height: 104,
                          width: 104,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.pets, size: 80, color: p.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Brownpaw', style: text.displaySmall),
                    const SizedBox(height: 6),
                    Text(
                      'Your whitewater logbook',
                      style: text.bodyLarge?.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: 20),
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FeaturePill(icon: Icons.water, label: 'Live flows'),
                        _FeaturePill(
                          icon: Icons.menu_book_rounded,
                          label: 'Logbook',
                        ),
                        _FeaturePill(icon: Icons.map_outlined, label: 'Guide'),
                      ],
                    ),
                    const Spacer(flex: 3),
                    const SizedBox(height: 32),
                    if (userData.errorMessage != null)
                      _ErrorNote(
                        message: userData.errorMessage!,
                        onClose: notifier.clearError,
                      ),
                    // Apple's guidelines: black on light, white on dark.
                    _SignInButton(
                      key: const Key('sign-in-apple'),
                      onPressed: busy ? null : notifier.signInWithApple,
                      isLoading: busy,
                      icon: const Icon(Icons.apple, size: 22),
                      label: 'Continue with Apple',
                      background: dark ? Colors.white : Colors.black,
                      foreground: dark ? Colors.black : Colors.white,
                    ),
                    const SizedBox(height: 12),
                    _SignInButton(
                      key: const Key('sign-in-google'),
                      onPressed: busy ? null : notifier.signInWithGoogle,
                      isLoading: busy,
                      icon: const _GoogleIcon(),
                      label: 'Continue with Google',
                      background: p.card,
                      foreground: p.ink,
                      border: p.faint,
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('continue-anonymously'),
                      onPressed: busy ? null : notifier.continueAnonymously,
                      style: TextButton.styleFrom(
                        foregroundColor: p.muted,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Continue without an account'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      style: text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = Riverstone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.glacierSoft,
        borderRadius: Pebble.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: p.glacier),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: p.ink),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = Riverstone.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: Pebble.small,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: p.high, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: Icon(Icons.close, size: 18, color: p.muted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget icon;
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.7),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: Pebble.small,
            side: border == null ? BorderSide.none : BorderSide(color: border!),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  // Shrinks rather than overflows on narrow screens or
                  // with large text settings.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppTheme.font,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: foreground,
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

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    // A coloured G, no asset needed.
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
