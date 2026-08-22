/// Pure layout math for the full-screen player.
///
/// Extracted from the widget so it can be unit-tested: the original bug was a
/// fixed `width * 0.76` artwork inside a `spaceBetween` Column with two
/// `Spacer`s, which overflowed in landscape and at large text scales.
class PlayerLayout {
  PlayerLayout._();

  /// Vertical space the portrait layout needs for everything except artwork:
  /// top bar, metadata, seek bar, transport controls and the download action.
  static const double portraitChromeHeight = 348;

  /// Below this the artwork is dropped in favour of a scrollable layout.
  static const double minArtworkSize = 140;

  /// Horizontal padding applied either side of the artwork in portrait.
  static const double horizontalPadding = 48;

  /// Artwork edge length for a portrait viewport, or `null` when the viewport is
  /// too short to fit artwork plus controls (caller should scroll instead).
  ///
  /// The result is always `<= maxHeight - portraitChromeHeight`, so the column
  /// it sits in can never overflow.
  static double? portraitArtworkSize(double maxWidth, double maxHeight) {
    final available = maxHeight - portraitChromeHeight;
    if (available < minArtworkSize) return null;

    final maxByWidth = maxWidth - horizontalPadding;
    if (maxByWidth < minArtworkSize) return null;

    return available < maxByWidth ? available : maxByWidth;
  }

  /// Artwork edge length for the landscape / wide layout, where a square that
  /// filled the width would leave no room for the controls beside it.
  static double landscapeArtworkSize(double maxWidth, double maxHeight) {
    final byHeight = maxHeight - 32;
    final byWidth = maxWidth * 0.42;
    final size = byHeight < byWidth ? byHeight : byWidth;
    return size < minArtworkSize ? minArtworkSize : size;
  }

  /// True when the viewport should use the side-by-side layout.
  static bool isWide(double maxWidth, double maxHeight) => maxWidth > maxHeight;
}
