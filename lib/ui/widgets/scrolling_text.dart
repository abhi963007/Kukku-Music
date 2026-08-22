import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// Text that scrolls horizontally only when it does not fit.
///
/// The `marquee` package always animates, which looks broken for short titles,
/// so overflow is measured first and a plain [Text] is used when the string
/// fits. This is what gives long song titles a readable marquee in the player
/// instead of a truncating ellipsis.
class ScrollingText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign alignment;
  final double height;
  final double velocity;

  const ScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.alignment = TextAlign.center,
    this.height = 28,
    this.velocity = 26,
  });

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scaledHeight = scaler.scale(height);

    return SizedBox(
      height: scaledHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();

          final overflows = painter.width > constraints.maxWidth;
          if (!overflows) {
            return Align(
              alignment: alignment == TextAlign.start
                  ? Alignment.centerLeft
                  : Alignment.center,
              child: Text(
                text,
                maxLines: 1,
                textAlign: alignment,
                style: style,
              ),
            );
          }

          return Marquee(
            text: text,
            style: style,
            blankSpace: 48,
            velocity: velocity,
            pauseAfterRound: const Duration(seconds: 2),
            startPadding: 0,
            accelerationDuration: const Duration(milliseconds: 600),
            accelerationCurve: Curves.easeOut,
            decelerationDuration: const Duration(milliseconds: 400),
            decelerationCurve: Curves.easeIn,
            showFadingOnlyWhenScrolling: true,
            fadingEdgeStartFraction: 0.06,
            fadingEdgeEndFraction: 0.06,
          );
        },
      ),
    );
  }
}
