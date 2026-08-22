import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared empty / error placeholder.
///
/// Every screen previously hand-rolled its own centred column, which meant
/// inconsistent spacing and — because none of them had horizontal padding —
/// text running into the screen edges on narrow devices.
class StatePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// When true the placeholder scrolls, so it still works inside a
  /// `RefreshIndicator` and cannot overflow on short screens.
  final bool scrollable;

  const StatePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
              ),
            ),
          ],
        ],
      ),
    );

    if (!scrollable) return Center(child: content);

    // A scrollable placeholder still needs to fill the viewport so the content
    // stays vertically centred.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}
