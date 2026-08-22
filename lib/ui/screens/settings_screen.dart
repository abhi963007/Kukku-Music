import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
            _SectionHeader("Groq AI Engine"),
            _AiSettingsCard(),
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

class _AiSettingsCard extends StatelessWidget {
  const _AiSettingsCard();

  static const List<Map<String, String>> _models = [
    {
      'id': 'openai/gpt-oss-120b',
      'name': 'High Intelligence Engine',
      'desc': 'Deep musical knowledge & contextual track metadata',
    },
    {
      'id': 'qwen/qwen3.6-27b',
      'name': 'Multilingual Specialist',
      'desc': 'Optimized for regional languages and Indian soundtracks',
    },
    {
      'id': 'openai/gpt-oss-20b',
      'name': 'Ultra-Fast Engine',
      'desc': 'Sub-second real-time radio and seamless queue continuation',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currentModel = boxGet<String>('AppPrefs', 'groqModel', 'openai/gpt-oss-120b');

    return _SettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Smart Discovery Engine",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      "Real-time track credits & seamless radio flow",
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  "ACTIVE",
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Discovery Model",
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_models.length, (index) {
            final m = _models[index];
            final isSelected = m['id'] == currentModel;

            return InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () {
                boxPut('AppPrefs', 'groqModel', m['id']!);
                (context as Element).markNeedsBuild();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.surfaceLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                    width: isSelected ? 1.2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppTheme.primaryAccent : AppTheme.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['name']!,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryAccent : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            m['desc']!,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
