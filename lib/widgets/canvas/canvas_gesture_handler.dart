import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles gestures on the canvas including touch, stylus and multi-touch
class CanvasGestureHandler extends ConsumerStatefulWidget {
  final Widget child;

  const CanvasGestureHandler({super.key, required this.child});

  @override
  ConsumerState<CanvasGestureHandler> createState() =>
      _CanvasGestureHandlerState();
}

class _CanvasGestureHandlerState
    extends ConsumerState<CanvasGestureHandler> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
