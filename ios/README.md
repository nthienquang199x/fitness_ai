# Fitness AI iOS Implementation

This directory contains the iOS implementation of the Fitness AI Flutter plugin, which provides real-time exercise analysis using MediaPipe pose detection.

## Features

- Real-time camera feed processing
- MediaPipe pose landmark detection
- Exercise form analysis for multiple exercises
- Rep counting and form feedback
- Support for different difficulty levels
- Configurable exercise thresholds

## Architecture

The iOS implementation consists of three main components:

### 1. FitnessAiPlugin.swift
Main plugin class that handles:
- Flutter method channel communication
- Camera setup and management
- Texture registration for camera preview
- Event channel for pose data streaming

### 2. FitnessAI.swift
MediaPipe integration class that:
- Initializes the PoseLandmarker
- Processes camera frames
- Provides pose detection results
- Handles live stream mode

### 3. ExerciseAnalyzer.swift
Exercise analysis engine that:
- Calculates pose metrics (angles, distances)
- Manages exercise state machines
- Provides form feedback
- Tracks rep counts and correctness

## Dependencies

The iOS implementation requires:

- **MediaPipeTasksVision**: For pose landmark detection
- **MediaPipeTasksCommon**: For common MediaPipe functionality
- **AVFoundation**: For camera capture and video processing
- **CoreMedia**: For media sample buffer handling
- **CoreVideo**: For pixel buffer management

## Setup

1. Ensure your iOS project has a minimum deployment target of iOS 12.0
2. The plugin will automatically install MediaPipe dependencies via CocoaPods
3. Camera permissions are handled automatically by the plugin

## Usage

### Starting Exercise Analysis

```dart
final int? textureId = await FitnessAiPlugin.startAnalyzeExercise(
  exercise: 'squat',
  difficulty: 'medium',
  thresholds: thresholdsJson,
  modelAssetPath: 'assets/models/pose_landmarker_heavy.task',
  isFrontCamera: false,
);
```

### Listening to Pose Data

```dart
FitnessAiPlugin.onLandmarks.listen((data) {
  final landmarks = data['landmarks'] as List;
  final message = data['message'] as String;
  final repCount = data['repCount'] as int;
  final correctReps = data['correctReps'] as int;
  final isCorrect = data['isCorrect'] as bool;
  
  // Handle pose data
});
```

### Stopping Exercise Analysis

```dart
await FitnessAiPlugin.stopAnalyzeExercise();
```

## Supported Exercises

The iOS implementation supports the same exercises as the Android version:

- Squat
- Push-up
- Mountain climber
- Burpee
- High knees
- Bicycle crunch
- Wall sit
- Tricep dip
- Step up
- Single leg deadlift
- Donkey kick
- Bird dog
- Leg raise
- Jumping jack
- Lunge
- Elevated push-up
- Glute bridge
- Bent leg inverted row
- Plank
- Bulgarian split squat
- Single leg hip thrust
- Inverted row
- Superman pose
- Abs alternating
- Bridge
- Side bridge

## Performance Considerations

- Camera frames are processed on a background queue to maintain UI responsiveness
- Texture updates are performed on the main thread as required by Flutter
- MediaPipe processing is optimized for real-time performance
- Memory management includes proper pixel buffer retention and release

## Troubleshooting

### Common Issues

1. **Camera Permission Denied**: Ensure camera permissions are granted in iOS Settings
2. **MediaPipe Initialization Failed**: Check that the model file path is correct
3. **Texture Not Displaying**: Verify that the texture ID is properly used in Flutter UI
4. **Performance Issues**: Ensure device supports the required iOS version and has sufficient processing power

### Debug Information

The plugin provides console logging for:
- MediaPipe initialization status
- Camera setup progress
- Exercise analysis results
- Error conditions

## Platform Differences

The iOS implementation maintains API compatibility with the Android version while leveraging iOS-specific features:

- Uses AVFoundation for camera management
- Implements FlutterTexture for efficient video rendering
- Leverages iOS Metal framework through MediaPipe
- Handles iOS-specific memory management patterns
