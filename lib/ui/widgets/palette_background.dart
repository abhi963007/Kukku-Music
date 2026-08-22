import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../utils/helper.dart';
import '../theme/app_theme.dart';

/// Ambient player background: the album art, heavily blurred, under a gradient
/// tinted with the artwork's dominant colour.
///
/// Two deliberate choices:
///  * The blur uses [ImageFiltered] on the artwork itself rather than a
///    full-screen [BackdropFilter]. BackdropFilter forces a `saveLayer` over
///    the entire screen every frame, which was a measurable cost on the player.
///  * Palettes are memoised per art URL so re-opening the player, or a rebuild,
///    never re-decodes the same image.
class PaletteBackground extends StatefulWidget {
  final String artUri;

  const PaletteBackground({super.key, required this.artUri});

  @override
  State<PaletteBackground> createState() => _PaletteBackgroundState();
}

class _PaletteBackgroundState extends State<PaletteBackground> {
  static final Map<String, Color> _paletteCache = {};
  static const int _maxCacheEntries = 60;

  Color _accent = AppTheme.surfaceLight;

  @override
  void initState() {
    super.initState();
    _resolvePalette();
  }

  @override
  void didUpdateWidget(PaletteBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artUri != widget.artUri) _resolvePalette();
  }

  Future<void> _resolvePalette() async {
    final url = widget.artUri;
    if (url.isEmpty) {
      if (mounted) setState(() => _accent = AppTheme.surfaceLight);
      return;
    }

    final cached = _paletteCache[url];
    if (cached != null) {
      if (mounted) setState(() => _accent = cached);
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        // Small sample: enough for a dominant hue, cheap to decode.
        size: const ui.Size(120, 120),
        maximumColorCount: 12,
      );
      final picked = palette.darkVibrantColor?.color ??
          palette.vibrantColor?.color ??
          palette.darkMutedColor?.color ??
          palette.dominantColor?.color ??
          AppTheme.surfaceLight;

      // Keep the tint dark enough for white text to stay legible on top.
      final hsl = HSLColor.fromColor(picked);
      final accent = hsl
          .withLightness(hsl.lightness.clamp(0.12, 0.34))
          .withSaturation(hsl.saturation.clamp(0.0, 0.62))
          .toColor();

      if (_paletteCache.length >= _maxCacheEntries) {
        _paletteCache.remove(_paletteCache.keys.first);
      }
      _paletteCache[url] = accent;
      if (mounted && widget.artUri == url) setState(() => _accent = accent);
    } catch (e) {
      printERROR('Palette generation failed for $url', e);
      if (mounted) setState(() => _accent = AppTheme.surfaceLight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppTheme.background),
        if (widget.artUri.isNotEmpty)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 40,
              sigmaY: 40,
              tileMode: TileMode.clamp,
            ),
            child: Opacity(
              opacity: 0.55,
              child: CachedNetworkImage(
                imageUrl: widget.artUri,
                fit: BoxFit.cover,
                // The image is blurred beyond recognition, so a small decode is
                // plenty and saves a lot of memory on large artwork.
                memCacheWidth: 200,
                memCacheHeight: 200,
                placeholder: (_, _) => const ColoredBox(color: AppTheme.background),
                errorWidget: (_, _, _) => const ColoredBox(color: AppTheme.background),
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _accent.withValues(alpha: 0.78),
                AppTheme.background.withValues(alpha: 0.86),
                AppTheme.background,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
