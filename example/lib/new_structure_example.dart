import 'package:fitness_ai/fitness_ai.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Example showing how to use the new structure with
/// separate FitnessController and PreviewCamera widgets
class NewStructureExample extends StatefulWidget {
  const NewStructureExample({super.key});

  @override
  State<NewStructureExample> createState() => _NewStructureExampleState();
}

class _NewStructureExampleState extends State<NewStructureExample> {
  // Create fitness controller instance
  late final FitnessController _fitnessController;

  bool _showCamera = false;
  final bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _fitnessController = FitnessController();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    // Dispose controller when widget is disposed
    _fitnessController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      print('Camera permission granted');
    } else {
      print('Camera permission denied');
    }
  }

  Future<void> _startAnalyzeExercise() async {
    try {
      // Check camera permission first
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          _showSnackBar('Camera permission is required');
          return;
        }
      }

      setState(() {
        _showCamera = true;
      });
    } catch (e) {
      _showSnackBar('Error starting exercise analysis: $e');
    }
  }

  void _stopAnalyzeExercise() {
    setState(() {
      _showCamera = false;
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness AI - New Structure',
      home: Scaffold(
        backgroundColor: Colors.black,
        body: _showCamera ? _buildCameraView() : _buildInitialScreen(),
      ),
    );
  }

  Widget _buildCameraView() {
    return Scaffold(
      body: Stack(
        children: [
          // Pure camera preview - no controls
          AICamera(
            controller: _fitnessController,
            backgroundColor: Colors.black,
            aspectRatio: 9 / 16,
          ),

          // External controls overlay
          _buildExternalControls(),
        ],
      ),
    );
  }

  Widget _buildExternalControls() {
    return SafeArea(
      child: Column(
        children: [
          // Top controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _stopAnalyzeExercise,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'New Structure Demo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom controls
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
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
                      onTap: () {
                        _stopAnalyzeExercise();
                        _showSnackBar('Exercise analysis stopped');
                      },
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

  Widget _buildInitialScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: const Text(
                'Fitness AI - New Structure',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),

            const Spacer(),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'New Structure Demo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Using FitnessController + PreviewCamera',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Separated concerns for better maintainability',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Start button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton(
                onPressed: _isStarting ? null : _startAnalyzeExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 8,
                ),
                child: _isStarting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Starting...',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : const Text(
                        'Start New Structure Demo',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Info cards
            _buildInfoCard(
              'FitnessController',
              'Manages camera operations and state',
              Icons.settings,
              Colors.blue,
            ),

            const SizedBox(height: 12),

            _buildInfoCard(
              'PreviewCamera',
              'Displays camera feed with customizable UI',
              Icons.videocam,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
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
