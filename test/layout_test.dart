import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukku/ui/screens/player_layout.dart';

/// Layout regression tests.
///
/// The player used to size its artwork at a fixed fraction of the screen *width*
/// inside a `spaceBetween` Column that also contained two `Spacer`s. That
/// overflowed in landscape and at large system text scales.
void main() {
  group('PlayerLayout artwork sizing', () {
    // Representative viewports: small phone, typical phone, tall phone, tablet.
    const portraitViewports = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
      Size(768, 1024),
    ];

    test('portrait artwork always leaves room for the controls', () {
      for (final size in portraitViewports) {
        final art = PlayerLayout.portraitArtworkSize(size.width, size.height);
        if (art == null) continue;

        expect(
          art + PlayerLayout.portraitChromeHeight,
          lessThanOrEqualTo(size.height),
          reason: 'artwork + chrome overflows ${size.width}x${size.height}',
        );
        expect(
          art,
          lessThanOrEqualTo(size.width - PlayerLayout.horizontalPadding),
          reason: 'artwork wider than the viewport at $size',
        );
      }
    });

    test('very short viewports fall back to the scrollable layout', () {
      // Landscape-height portrait window (split screen) and a tiny window.
      expect(PlayerLayout.portraitArtworkSize(360, 400), isNull);
      expect(PlayerLayout.portraitArtworkSize(360, 480), isNull);
      // Extremely narrow: no room for artwork either.
      expect(PlayerLayout.portraitArtworkSize(150, 900), isNull);
    });

    test('landscape artwork fits both axes', () {
      for (final size in const [Size(640, 360), Size(844, 390), Size(1024, 768)]) {
        final art = PlayerLayout.landscapeArtworkSize(size.width, size.height);
        expect(art, lessThanOrEqualTo(size.height));
        expect(art, lessThan(size.width));
        expect(art, greaterThanOrEqualTo(PlayerLayout.minArtworkSize));
      }
    });

    test('isWide only reports true for landscape viewports', () {
      expect(PlayerLayout.isWide(640, 360), isTrue);
      expect(PlayerLayout.isWide(360, 640), isFalse);
    });
  });
}
