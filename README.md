# Fitness AI Plugin

A Flutter plugin for fitness AI functionality including exercise analysis using camera.

## Features

- **Camera Integration**: Access device camera for exercise analysis
- **Texture Support**: Display camera preview in Flutter UI using Texture widget
- **Exercise Analysis**: Framework for implementing AI-powered exercise analysis
- **Cross-platform**: Support for Android and iOS (Android implemented first)

## Getting Started

### Android Setup

1. Add camera permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

2. Add CameraX dependencies to your `android/app/build.gradle`:

```gradle
dependencies {
    implementation "androidx.camera:camera-core:1.4.2"
    implementation "androidx.camera:camera-camera2:1.4.2"
    implementation "androidx.camera:camera-lifecycle:1.4.2"
    implementation "androidx.camera:camera-view:1.4.2"
}
```

### Usage

```dart
import 'package:fitness_ai/fitness_ai.dart';

class ExerciseAnalysisPage extends StatefulWidget {
  @override
  _ExerciseAnalysisPageState createState() => _ExerciseAnalysisPageState();
}

class _ExerciseAnalysisPageState extends State<ExerciseAnalysisPage> {
  int? _textureId;
  bool _isAnalyzing = false;

  Future<void> _startAnalysis() async {
    try {
      setState(() => _isAnalyzing = true);
      
      final textureId = await FitnessAiPlugin.startAnalyzeExercise();
      
      setState(() {
        _textureId = textureId;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      print('Error: $e');
    }
  }

  Future<void> _stopAnalysis() async {
    try {
      await FitnessAiPlugin.stopAnalyzeExercise();
      setState(() => _textureId = null);
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Exercise Analysis')),
      body: Column(
        children: [
          if (_textureId != null)
            Container(
              height: 300,
              child: Texture(textureId: _textureId!),
            ),
          ElevatedButton(
            onPressed: _isAnalyzing ? null : _startAnalysis,
            child: Text(_isAnalyzing ? 'Starting...' : 'Start Analysis'),
          ),
          if (_textureId != null)
            ElevatedButton(
              onPressed: _stopAnalysis,
              child: Text('Stop Analysis'),
            ),
        ],
      ),
    );
  }
}
```

## API Reference

### `startAnalyzeExercise()`

Starts the camera and begins exercise analysis. Returns a texture ID that can be used with Flutter's `Texture` widget to display the camera preview.

**Returns:** `Future<int?>` - The texture ID for camera preview, or `null` if failed

**Throws:** `PlatformException` if camera cannot be started

### `stopAnalyzeExercise()`

Stops the camera and releases all resources.

**Returns:** `Future<void>`

**Throws:** `PlatformException` if camera cannot be stopped

## Example App

Run the example app to see the camera functionality in action:

```bash
cd example
flutter run
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
