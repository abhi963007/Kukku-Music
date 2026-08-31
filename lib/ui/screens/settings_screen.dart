import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/download_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // The parent Scaffold reserves the mini player + nav bar space, so the
          // old trailing 120px was just dead scroll.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            Text(
              "Settings",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 20),
            _SectionHeader("Account"),
            _UserProfileCard(),
            SizedBox(height: 24),
            _SectionHeader("Audio Streaming"),
            _StreamingQualityCard(),
            SizedBox(height: 24),
            _SectionHeader("Downloads & Offline"),
            _DownloadsCard(),
            SizedBox(height: 24),
            _SectionHeader("Storage & Cache"),
            _StorageCard(),
            SizedBox(height: 24),
            _SectionHeader("About Kukku"),
            _AboutCard(),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryAccent,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Card shell shared by every settings group.
class _SettingsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _SettingsCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: child,
      ),
    );
  }
}

class _StreamingQualityCard extends StatelessWidget {
  const _StreamingQualityCard();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();

    return Obx(() => _SettingsCard(
          // `RadioGroup` replaces the per-tile `groupValue`/`onChanged` pair,
          // which Flutter deprecated after 3.32.
          child: RadioGroup<int>(
            groupValue: settings.streamingQuality.value,
            onChanged: (value) => settings.setStreamingQuality(value ?? 1),
            child: const Column(
              children: [
                RadioListTile<int>(
                  value: 1,
                  activeColor: AppTheme.primary,
                  title: Text(
                    "High quality (128–160 kbps)",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Best clarity. Uses more mobile data.",
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                Divider(height: 1),
                RadioListTile<int>(
                  value: 0,
                  activeColor: AppTheme.primary,
                  title: Text(
                    "Data saver (48–50 kbps)",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Lowest data usage. Noticeably lower fidelity.",
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

class _DownloadsCard extends StatelessWidget {
  const _DownloadsCard();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();

    return Obx(() => _SettingsCard(
          child: Column(
            children: [
              ListTile(
                title: const Text("Download format",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  settings.downloadFormat.value == "opus"
                      ? "Opus (.opus) — smaller files, best quality"
                      : "M4A (.m4a) — widest compatibility",
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: DropdownButton<String>(
                  value: settings.downloadFormat.value,
                  dropdownColor: AppTheme.surfaceLight,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  items: const [
                    DropdownMenuItem(value: "opus", child: Text("Opus")),
                    DropdownMenuItem(value: "m4a", child: Text("M4A")),
                  ],
                  onChanged: (val) {
                    if (val != null) settings.setDownloadFormat(val);
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.cacheSongs.value,
                // `activeColor` is deprecated on Switch tiles.
                activeThumbColor: AppTheme.background,
                activeTrackColor: AppTheme.primary,
                title: const Text("Auto-cache streamed tracks",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  "Saves tracks to this device while they play, so you can replay them offline.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onChanged: settings.toggleCacheSongs,
              ),
            ],
          ),
        ));
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context) {
    final downloads = Get.find<DownloadViewController>();

    return _SettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() => _StorageRow(
                label: "Streaming cache",
                value: formatBytes(downloads.totalCacheSizeBytes.value),
              )),
          const SizedBox(height: 10),
          Obx(() => _StorageRow(
                label: "Offline Downloads",
                value: formatBytes(downloads.totalDownloadSizeBytes.value),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              label: const Text("Clear streaming cache"),
              onPressed: () => _confirmClearCache(context, downloads),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache(
    BuildContext context,
    DownloadViewController downloads,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Clear Cache?", style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          "This will remove temporarily cached songs. Downloaded offline songs will not be deleted.",
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await downloads.clearAllCache();
    Get.snackbar(
      "Cache cleared",
      "Temporary streaming cache has been removed",
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }
}

class _StorageRow extends StatelessWidget {
  final String label;
  final String value;

  const _StorageRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return const _SettingsCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Kukku Music v1.0.0",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Streaming music player with intelligent discovery, background playback, "
            "media-notification controls, offline caching and direct audio stream extraction.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard();

  void _showLogoutDialog(BuildContext context, AuthController auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: const Text('Sign Out', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to sign out of your Kukku account?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              auth.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return _SettingsCard(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final name = auth.userName;
        final email = auth.userEmail;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return Row(
          children: [
            // User Avatar / Initials
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name & Email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email.isNotEmpty ? email : 'Signed in with Supabase',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Sign Out Button
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Sign Out',
              onPressed: () => _showLogoutDialog(context, auth),
            ),
          ],
        );
      }),
    );
  }
}
