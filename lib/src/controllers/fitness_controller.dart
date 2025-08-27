import 'package:fitness_ai/src/models/exercise_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class IFitnessController {
  Future<int?> startAnalyzeExercise({
    ExerciseType exercise,
    String difficulty,
    String? thresholdsJson,
    String? modelAssetPath,
    bool isFrontCamera,
  });
  Future<void> stopAnalyzeExercise();
  Stream<Map<dynamic, dynamic>> get resultsStream;
  void dispose();
}

class FitnessController extends IFitnessController {
  static const MethodChannel _channel = MethodChannel('fitness_ai');
  static const EventChannel _eventChannel =
      EventChannel('fitness_ai/landmarks');

  int? _currentTextureId;
  bool _isAnalyzing = false;
  Stream<Map<dynamic, dynamic>>? _resultsStream;

  /// Get current texture ID
  int? get textureId => _currentTextureId;

  /// Check if camera is currently analyzing
  bool get isAnalyzing => _isAnalyzing;

  @override
  Stream<Map<dynamic, dynamic>> get resultsStream => _resultsStream ??=
      _eventChannel.receiveBroadcastStream().map<Map<dynamic, dynamic>>(
          (event) => Map<dynamic, dynamic>.from(event));

  @override
  Future<int?> startAnalyzeExercise({
    ExerciseType exercise = ExerciseType.squat,
    String difficulty = 'medium',
    String? thresholdsJson,
    String? modelAssetPath,
    bool isFrontCamera = false,
  }) async {
    if (_isAnalyzing) {
      if (kDebugMode) {
        print('Exercise analysis is already running');
      }
      return _currentTextureId;
    }

    try {
      _isAnalyzing = true;

      final int? textureId =
          await _channel.invokeMethod('startAnalyzeExercise', {
        'exercise': exercise.value,
        'difficulty': difficulty,
        'thresholds': thresholdsJson,
        'modelAssetPath': modelAssetPath,
        'isFrontCamera': isFrontCamera,
      });
      _currentTextureId = textureId;

      if (kDebugMode) {
        print('Started exercise analysis with texture ID: $textureId');
      }

      return textureId;
    } on PlatformException catch (e) {
      _isAnalyzing = false;
      if (kDebugMode) {
        print('Failed to start exercise analysis: ${e.message}');
      }
      rethrow;
    } catch (e) {
      _isAnalyzing = false;
      if (kDebugMode) {
        print('Unexpected error starting exercise analysis: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> stopAnalyzeExercise() async {
    if (!_isAnalyzing) {
      if (kDebugMode) {
        print('Exercise analysis is not running');
      }
      return;
    }

    try {
      await _channel.invokeMethod('stopAnalyzeExercise');
      _currentTextureId = null;
      _isAnalyzing = false;

      if (kDebugMode) {
        print('Stopped exercise analysis');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to stop exercise analysis: ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error stopping exercise analysis: $e');
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    if (_isAnalyzing) {
      stopAnalyzeExercise().catchError((error) {
        if (kDebugMode) {
          print('Error during dispose: $error');
        }
      });
    }
    _currentTextureId = null;
    _isAnalyzing = false;
  }
}
