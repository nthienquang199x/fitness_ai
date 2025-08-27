import 'dart:async';
import 'dart:io';

import 'package:fitness_ai/fitness_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Example showing how to use PreviewCamera with custom overlay
class CustomOverlayExample extends StatefulWidget {
  const CustomOverlayExample({super.key});

  @override
  State<CustomOverlayExample> createState() => _CustomOverlayExampleState();
}

class _CustomOverlayExampleState extends State<CustomOverlayExample> {
  late final FitnessController _fitnessController;
  bool _showCamera = false;
  int _repsCount = 0;
  int _correctReps = 0;
  String _message = '';
  ExerciseType _currentExercise = ExerciseType.squat;
  bool _isRecording = false;
  StreamSubscription<Map<dynamic, dynamic>>? _subscription;
  String? _cachedModelPath;

  @override
  void initState() {
    super.initState();
    _fitnessController = FitnessController();
    _subscription = _fitnessController.resultsStream.listen((event) {
      setState(() {
        _repsCount = (event['repCount'] as int?) ?? _repsCount;
        _correctReps = (event['correctReps'] as int?) ?? _correctReps;
        _message = (event['message'] as String?) ?? '';
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _fitnessController.dispose();
    super.dispose();
  }

  Future<void> _startWorkout() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
        return;
      }
    }

    _cachedModelPath =
        await _copyModelToCache('assets/models/landmarker_model.task');

    setState(() {
      _showCamera = true;
      _repsCount = 0;
      _correctReps = 0;
      _message = '';
    });
  }

  /// Copy model asset to cache directory and return the cached path
  Future<String?> _copyModelToCache(String? modelAssetPath) async {
    if (modelAssetPath == null || modelAssetPath.isEmpty) {
      return null;
    }

    try {
      // Get cache directory
      final Directory cacheDir = await getTemporaryDirectory();
      final String modelFileName = modelAssetPath.split('/').last;
      final String cachedModelPath = '${cacheDir.path}/$modelFileName';

      // Check if model already exists in cache
      final File cachedFile = File(cachedModelPath);
      if (await cachedFile.exists()) {
        if (kDebugMode) {
          print('Model already exists in cache: $cachedModelPath');
        }
        return cachedModelPath;
      }

      // Copy model from assets to cache
      final ByteData data = await rootBundle.load(modelAssetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      await cachedFile.writeAsBytes(bytes);

      if (kDebugMode) {
        print('Model copied to cache: $cachedModelPath');
      }

      return cachedModelPath;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to copy model to cache: $e');
      }
      // Return original path if copying fails
      return modelAssetPath;
    }
  }

  void _stopWorkout() {
    setState(() {
      _showCamera = false;
      _isRecording = false;
    });
  }

  // Removed unused manual reps increment; counts come from native stream

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showCamera) {
      return Scaffold(
        body: Stack(
          children: [
            // Pure camera preview - no built-in controls
            AICamera(
              controller: _fitnessController,
              backgroundColor: Colors.black,
              aspectRatio: 9 / 16,
              exercise: _currentExercise,
              difficulty: 'medium',
              thresholdsAssetPath:
                  'assets/jsons/exercise_thresholds_custom_format.json',
              modelAssetPath: _cachedModelPath,
              isFrontCamera: true,
            ),

            // Custom external overlay
            _buildCustomOverlay(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Custom Overlay Demo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 100,
              color: Colors.purple[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'Custom Overlay Example',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This demo shows how to create\ncustom overlays for the camera preview',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startWorkout,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Workout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _stopWorkout,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    _currentExercise.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRecording ? Icons.fiber_manual_record : Icons.pause,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isRecording ? 'REC' : 'PAUSE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Center stats
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'REPS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_repsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'CORRECT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_correctReps',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_message.isNotEmpty)
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom controls
          Container(
            margin: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Record button
                Container(
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: _toggleRecording,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Icon(
                          _isRecording
                              ? Icons.pause
                              : Icons.fiber_manual_record,
                          color: _isRecording ? Colors.white : Colors.red,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

                // Switch exercise button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: () {
                        setState(() {
                          _currentExercise =
                              _currentExercise == ExerciseType.squat
                                  ? ExerciseType.pushup
                                  : ExerciseType.squat;
                          _repsCount = 0;
                          _correctReps = 0;
                          _message = '';
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Icon(
                          Icons.swap_horiz,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

                // Stop button
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: _stopWorkout,
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
