import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GradientConfig {
  final Color startColor;
  final Color endColor;
  final bool isRadial;
  final bool createInNewLayer;

  const GradientConfig({
    this.startColor = const Color(0xFF1E88E5), // Blue (opaque)
    this.endColor = const Color(0x001E88E5),   // Blue (0% transparent)
    this.isRadial = false,
    this.createInNewLayer = true,
  });

  double get startOpacity => startColor.a;
  double get endOpacity => endColor.a;

  GradientConfig copyWith({
    Color? startColor,
    Color? endColor,
    bool? isRadial,
    bool? createInNewLayer,
  }) {
    return GradientConfig(
      startColor: startColor ?? this.startColor,
      endColor: endColor ?? this.endColor,
      isRadial: isRadial ?? this.isRadial,
      createInNewLayer: createInNewLayer ?? this.createInNewLayer,
    );
  }
}

final gradientConfigProvider =
    StateNotifierProvider<GradientConfigNotifier, GradientConfig>(
  (ref) => GradientConfigNotifier(),
);

class GradientConfigNotifier extends StateNotifier<GradientConfig> {
  GradientConfigNotifier() : super(const GradientConfig());

  void setStartColor(Color c) {
    state = state.copyWith(startColor: c);
  }

  void setEndColor(Color c) {
    state = state.copyWith(endColor: c);
  }

  void setStartOpacity(double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    state = state.copyWith(
      startColor: state.startColor.withValues(alpha: clamped),
    );
  }

  void setEndOpacity(double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    state = state.copyWith(
      endColor: state.endColor.withValues(alpha: clamped),
    );
  }

  void setIsRadial(bool isRadial) {
    state = state.copyWith(isRadial: isRadial);
  }

  void setCreateInNewLayer(bool createInNewLayer) {
    state = state.copyWith(createInNewLayer: createInNewLayer);
  }

  void swapColors() {
    state = state.copyWith(
      startColor: state.endColor,
      endColor: state.startColor,
    );
  }

  void setPreset(Color start, Color end, {bool isRadial = false}) {
    state = state.copyWith(
      startColor: start,
      endColor: end,
      isRadial: isRadial,
    );
  }
}
