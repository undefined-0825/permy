import 'package:flutter/services.dart';

class Haptics {
  const Haptics._();

  static Future<void> selection() {
    return HapticFeedback.selectionClick();
  }

  static Future<void> success() {
    return HapticFeedback.heavyImpact();
  }

  static Future<void> lightImpact() {
    return HapticFeedback.lightImpact();
  }

  static Future<void> mediumImpact() {
    return HapticFeedback.mediumImpact();
  }
}
