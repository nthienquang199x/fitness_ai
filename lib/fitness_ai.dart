import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Export the new components
export 'src/controllers/fitness_controller.dart';
export 'src/models/exercise_type.dart';
export 'src/widgets/ai_camera.dart';

/// A Flutter plugin for fitness AI functionality.
class FitnessAiPlugin {
  static const MethodChannel _channel = MethodChannel('fitness_ai');

  /// Start exercise analysis with camera.
  /// Returns a texture ID that can be used to display camera preview in Flutter.
  static Future<int?> startAnalyzeExercise() async {
    try {
      final int? textureId =
          await _channel.invokeMethod('startAnalyzeExercise');
      return textureId;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to start exercise analysis: ${e.message}');
      }
      return null;
    }
  }

  /// Stop exercise analysis and release camera resources.
  static Future<void> stopAnalyzeExercise() async {
    try {
      await _channel.invokeMethod('stopAnalyzeExercise');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to stop exercise analysis: ${e.message}');
      }
    }
  }

  /// Register this plugin with the Flutter engine.
  /// This method is called automatically by the Flutter framework.
  static void registerWith() {
    // This method is called by the Flutter framework to register the plugin
    // The actual registration is handled by the native platform code
    if (kDebugMode) {
      print('FitnessAiPlugin registered');
    }
  }
}
