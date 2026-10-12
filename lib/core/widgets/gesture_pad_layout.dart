import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/constants.dart';
import 'gesture_pad.dart';
import 'page_padding.dart';

/// Standard in-app screen layout: [content] on top, the [GesturePad] taking
/// roughly the bottom third.
class GesturePadLayout extends StatelessWidget {
  /// Creates the layout.
  const GesturePadLayout({
    super.key,
    required this.content,
    required this.padHint,
  });

  /// Everything above the pad. Receives a bounded height; make it scrollable
  /// if it can grow (large text).
  final Widget content;

  /// Screen-reader hint for the pad (the main gestures on this screen).
  final String padHint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padHeight = math.max(
              constraints.maxHeight * AppDimens.gesturePadHeightFraction,
              AppDimens.gesturePadMinHeight,
            );
            return PagePadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: content),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: padHeight,
                    child: GesturePad(hint: padHint),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
