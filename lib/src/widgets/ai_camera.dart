import 'package:fitness_ai/src/models/exercise_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/fitness_controller.dart';
import 'landmark_overlay.dart';

/// A simple camera preview widget that only displays the camera feed.
/// All UI controls and interactions should be handled externally.
class AICamera extends StatefulWidget {
  /// The fitness controller that manages camera operations
  final FitnessController controller;

  /// Background color for the camera preview area
  final Color backgroundColor;

  /// Aspect ratio for the camera preview (width/height)
  final double aspectRatio;

  /// Exercise key (e.g., 'squat')
  final ExerciseType exercise;

  /// Difficulty ('easy' | 'medium' | 'hard')
  final String difficulty;

  /// Optional path to thresholds JSON asset
  final String? thresholdsAssetPath;

  /// Optional path to mediapipe tflite asset
  final String? modelAssetPath;

  /// Use front camera
  final bool isFrontCamera;

  const AICamera({
    super.key,
    required this.controller,
    this.backgroundColor = Colors.black,
    this.aspectRatio = 9 / 16, // Default portrait ratio
    this.exercise = ExerciseType.squat,
    this.difficulty = 'medium',
    this.thresholdsAssetPath,
    this.modelAssetPath,
    this.isFrontCamera = false,
  });

  @override
  State<AICamera> createState() => _AICameraState();
}

class _AICameraState extends State<AICamera> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Offset> _landmarks = const [];
  Size _inputSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _startCameraIfNeeded();
    _subscribeResults();
  }

  Future<void> _startCameraIfNeeded() async {
    // Only start camera if controller doesn't have a texture ID yet
    if (widget.controller.textureId == null && !widget.controller.isAnalyzing) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        String? thresholdsJson;
        if (widget.thresholdsAssetPath != null) {
          thresholdsJson =
              await rootBundle.loadString(widget.thresholdsAssetPath!);
        }
        await widget.controller.startAnalyzeExercise(
          exercise: widget.exercise,
          difficulty: widget.difficulty,
          thresholdsJson: thresholdsJson,
          modelAssetPath: widget.modelAssetPath,
          isFrontCamera: widget.isFrontCamera,
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  void _subscribeResults() {
    widget.controller.resultsStream.listen((event) {
      final width = (event['width'] as num?)?.toDouble() ?? 0;
      final height = (event['height'] as num?)?.toDouble() ?? 0;
      final landmarks = (event['landmarks'] as List?)
              ?.map((e) => Offset(
                    (e['x'] as num).toDouble(),
                    (e['y'] as num).toDouble(),
                  ))
              .toList() ??
          [];
      setState(() {
        _inputSize = Size(width, height);
        _landmarks = landmarks;
      });
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // Show error state
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    // Show camera if texture ID is available
    if (widget.controller.textureId != null) {
      return _buildCameraScreen();
    }

    // Default loading state
    return _buildLoadingScreen();
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: widget.backgroundColor,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Starting camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      color: widget.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error occurred',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraScreen() {
    return OverflowBox(
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Texture(
              textureId: widget.controller.textureId!,
              filterQuality: FilterQuality.high,
            ),
            LandmarkOverlay(points: _landmarks, inputSize: _inputSize),
          ],
        ),
      ),
    );
  }
}
