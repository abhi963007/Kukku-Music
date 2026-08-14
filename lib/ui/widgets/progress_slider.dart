// ignore_for_file: deprecated_member_use

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AudioProgressSlider extends StatelessWidget {
  final Duration position;
  final Duration bufferedPosition;
  final Duration totalDuration;
  final Function(Duration) onSeek;

  const AudioProgressSlider({
    super.key,
    required this.position,
    required this.bufferedPosition,
    required this.totalDuration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return ProgressBar(
      progress: position,
      buffered: bufferedPosition,
      total: totalDuration > Duration.zero ? totalDuration : const Duration(seconds: 1),
      onSeek: onSeek,
      progressBarColor: AppTheme.primary,
      baseBarColor: Colors.white.withOpacity(0.12),
      bufferedBarColor: Colors.white.withOpacity(0.25),
      thumbColor: AppTheme.primaryAccent,
      thumbRadius: 6.0,
      thumbGlowRadius: 16.0,
      timeLabelTextStyle: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      timeLabelPadding: 6,
    );
  }
}
