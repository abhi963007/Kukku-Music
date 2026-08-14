// ignore_for_file: deprecated_member_use

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
    final settings = Get.find<SettingsController>();
    final downloadController = Get.find<DownloadViewController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            const Text(
              "Settings",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Audio Playback Quality
            _buildSectionHeader("Audio Streaming"),
            Obx(() => Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        RadioListTile<int>(
                          value: 1,
                          groupValue: settings.streamingQuality.value,
                          title: const Text("High Quality (128-160 kbps)", style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text("Highest clarity with Opus itag 251 / AAC itag 140",
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          activeColor: AppTheme.primary,
                          onChanged: (val) => settings.setStreamingQuality(val ?? 1),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        RadioListTile<int>(
                          value: 0,
                          groupValue: settings.streamingQuality.value,
                          title: const Text("Data Saver (48-50 kbps)", style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text("Lowest data usage with Opus itag 249 / AAC itag 139",
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          activeColor: AppTheme.primary,
                          onChanged: (val) => settings.setStreamingQuality(val ?? 0),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 24),

            // Section 2: Offline Downloads
            _buildSectionHeader("Downloads & Offline"),
            Obx(() => Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text("Download Format", style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            settings.downloadFormat.value == "opus" ? "Opus (.opus) - Best Quality" : "M4A (.m4a) - High Compatibility",
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: DropdownButton<String>(
                            value: settings.downloadFormat.value,
                            dropdownColor: AppTheme.surfaceLight,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: "opus", child: Text("Opus")),
                              DropdownMenuItem(value: "m4a", child: Text("M4A")),
                            ],
                            onChanged: (val) {
                              if (val != null) settings.setDownloadFormat(val);
                            },
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        SwitchListTile(
                          value: settings.cacheSongs.value,
                          activeColor: AppTheme.primary,
                          title: const Text("Auto-Cache Streamed Tracks", style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text("Saves songs to local disk during playback for instant offline replays",
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          onChanged: (val) => settings.toggleCacheSongs(val),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 24),

            // Section 3: Storage & Cache Management
            _buildSectionHeader("Storage & Cache"),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Current Stream Cache Size", style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      Obx(() => Text(
                            formatBytes(downloadController.totalCacheSizeBytes.value),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                          )),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                      label: const Text("Clear Cache Storage"),
                      onPressed: () async {
                        await downloadController.clearAllCache();
                        Get.snackbar("Cache Cleared", "Temporary streaming cache successfully wiped",
                            backgroundColor: AppTheme.surface, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: About
            _buildSectionHeader("About Kukku"),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Kukku Music v1.0.0", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  SizedBox(height: 4),
                  Text(
                    "High-performance YouTube Music streaming engine with background playback, lock caching, and direct audio stream extraction.",
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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
