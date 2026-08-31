import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Seek bar with elapsed / remaining labels.
///
/// Two correctness fixes over the previous version:
///  * `progress` is clamped to `total`. `ProgressBar` asserts internally when
///    the reported position exceeds the duration, which happens briefly on
///    track changes because the position and duration streams update
///    independently.
///  * When the duration is unknown the bar renders empty and non-interactive
///    instead of substituting a 1-second total, which pinned the thumb at 100%.
class AudioProgressSlider extends StatelessWidget {
  final Duration position;
  final Duration bufferedPosition;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;

  const AudioProgressSlider({
    super.key,
    required this.position,
    required this.bufferedPosition,
    required this.totalDuration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final hasDuration = totalDuration > Duration.zero;
    final total = hasDuration ? totalDuration : const Duration(seconds: 1);
    final progress = hasDuration
        ? (position > totalDuration ? totalDuration : position)
        : Duration.zero;
    final buffered = hasDuration
        ? (bufferedPosition > totalDuration ? totalDuration : bufferedPosition)
        : Duration.zero;

    return ProgressBar(
      progress: progress,
      buffered: buffered,
      total: total,
      onSeek: hasDuration ? onSeek : null,
      barHeight: 4,
      progressBarColor: AppTheme.primary,
      baseBarColor: Colors.white.withValues(alpha: 0.14),
      bufferedBarColor: Colors.white.withValues(alpha: 0.26),
      thumbColor: AppTheme.primaryAccent,
      thumbRadius: 6.0,
      thumbGlowRadius: 18.0,
      timeLabelLocation: TimeLabelLocation.below,
      timeLabelType: TimeLabelType.totalTime,
      timeLabelTextStyle: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        // Fixed advance so the labels stop shifting the bar as digits change.
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      timeLabelPadding: 6,
    );
  }
}
