package com.woodlands.healthy.fitness_ai

import androidx.annotation.NonNull
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import android.content.Context
import android.util.Size
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import android.graphics.PointF
import android.os.Handler
import android.os.Looper

/** FitnessAiPlugin */
class FitnessAiPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
  private var activityPluginBinding: ActivityPluginBinding? = null
  private var cameraProvider: ProcessCameraProvider? = null
  private var camera: Camera? = null
  private var preview: Preview? = null
  private var imageAnalyzer: ImageAnalysis? = null
  private lateinit var cameraExecutor: ExecutorService
  private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
  private var eventSink: EventChannel.EventSink? = null

  private val exerciseAnalyzer = ExerciseAnalyzer()
  private var isFrontCameraNative: Boolean = false

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "fitness_ai")
    channel.setMethodCallHandler(this)
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "fitness_ai/landmarks")
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
      }

      override fun onCancel(arguments: Any?) {
        eventSink = null
      }
    })
    cameraExecutor = Executors.newSingleThreadExecutor()
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.activityPluginBinding = binding
  }

  override fun onDetachedFromActivityForConfigChanges() {
    this.activityPluginBinding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.activityPluginBinding = binding
  }

  override fun onDetachedFromActivity() {
    this.activityPluginBinding = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "startAnalyzeExercise" -> {
        startAnalyzeExercise(call, result)
      }
      "stopAnalyzeExercise" -> {
        stopAnalyzeExercise(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun startAnalyzeExercise(call: MethodCall, result: Result) {
    try {
      val context = flutterPluginBinding.applicationContext
      val activity = activityPluginBinding?.activity
      
      if (activity == null) {
        result.error("LIFECYCLE_ERROR", "Activity not available", null)
        return
      }

      // Configure FitnessAI and ExerciseAnalyzer
      try {
        val args = call.arguments as? Map<*, *>
        val exercise = (args?.get("exercise") as? String) ?: ExerciseAnalyzer.EXERCISE_SQUAT
        val difficulty = (args?.get("difficulty") as? String) ?: ExerciseAnalyzer.DIFFICULTY_MEDIUM
        val thresholdsJson = (args?.get("thresholds") as? String)
        val modelPath = (args?.get("modelAssetPath") as? String) ?: ""
        isFrontCameraNative = (args?.get("isFrontCamera") as? Boolean) ?: false

        FitnessAI.init(context, modelPath)
        FitnessAI.setResultCallback { poseResult, width, height ->
          try {
            if (poseResult == null) return@setResultCallback
            val allLandmarks = poseResult.landmarks()
            if (allLandmarks == null || allLandmarks.isEmpty()) return@setResultCallback

            val firstPose = allLandmarks[0]
            val points = mutableListOf<PointF>()
            for (lm in firstPose) {
              try {
                // The tasks API typically provides normalized coordinates [0,1]
                val x = try { lm.x() } catch (e: Exception) { 0f }
                val y = try { lm.y() } catch (e: Exception) { 0f }
                points.add(PointF(x * width, y * height))
              } catch (_: Exception) { }
            }

            val feedback = exerciseAnalyzer.analyzePose(points)

            val overlayPoints = firstPose.map { lm ->
              val nx = try { lm.x() } catch (e: Exception) { 0f }
              val ny = try { lm.y() } catch (e: Exception) { 0f }
              val px = nx * width
              val py = ny * height
              mapOf("x" to px, "y" to py)
            }

            val payload = mapOf(
              "width" to width,
              "height" to height,
              "landmarks" to overlayPoints,
              "message" to feedback.message,
              "repCount" to feedback.repCount,
              "correctReps" to feedback.correctReps,
              "isCorrect" to feedback.isCorrect
            )

            Handler(Looper.getMainLooper()).post {
              eventSink?.success(payload)
            }
          } catch (_: Exception) { }
        }

        // Configure analyzer thresholds
        exerciseAnalyzer.setExercise(exercise)
        exerciseAnalyzer.setDifficulty(difficulty)
        if (!thresholdsJson.isNullOrEmpty()) {
          try {
            exerciseAnalyzer.loadThresholds(JSONObject(thresholdsJson))
          } catch (_: Exception) { }
        }
      } catch (_: Exception) {
        // Continue; configuration errors will surface via analysis
      }
      
      // Create texture entry for Flutter
      textureEntry = flutterPluginBinding.textureRegistry.createSurfaceTexture()
      
      // Request camera permissions and start camera
      ProcessCameraProvider.getInstance(context).addListener({
        try {
          cameraProvider = ProcessCameraProvider.getInstance(context).get()
          
          // Create preview use case
          preview = Preview.Builder()
            .setTargetResolution(Size(1080, 1920)) // Portrait mode với 9:16 ratio
            .build()
          
          // Create image analyzer use case
          imageAnalyzer = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
            .also {
              it.setAnalyzer(cameraExecutor) { imageProxy ->
                try {
                  // Feed frames into FitnessAI
                  FitnessAI.detect(imageProxy, isFrontCameraNative)
                } catch (_: Exception) {
                  try { imageProxy.close() } catch (_: Exception) {}
                }
              }
            }

          // Bind use cases to camera
          cameraProvider?.unbindAll()
          
          camera = cameraProvider?.bindToLifecycle(
            activity as LifecycleOwner,
            if (isFrontCameraNative) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            imageAnalyzer
          )
          
          // Disable auto focus
          camera?.cameraControl?.enableTorch(false)
          camera?.cameraControl?.setLinearZoom(0f)
          // Set focus mode to fixed focus (disable auto focus)
          try {
            camera?.cameraControl?.cancelFocusAndMetering()
          } catch (e: Exception) {
            // Focus control not supported, continue without it
          }
          
          // Set up preview surface
          preview?.surfaceProvider = object : Preview.SurfaceProvider {
              override fun onSurfaceRequested(request: SurfaceRequest) {
                  val surfaceTexture = textureEntry!!.surfaceTexture()
                  val resolution = request.resolution
                  
                  // Set the surface texture size to match camera resolution
                  surfaceTexture.setDefaultBufferSize(resolution.width, resolution.height)
                  
                  // Create surface and provide it
                  val surface = Surface(surfaceTexture)
                  request.provideSurface(surface, cameraExecutor) {
                      surface.release()
                  }
              }
          }
          
          result.success(textureEntry?.id())
        } catch (exc: Exception) {
          result.error("CAMERA_ERROR", "Failed to bind camera use cases", exc.message)
        }
      }, ContextCompat.getMainExecutor(context))
      
    } catch (exc: Exception) {
      result.error("ERROR", "Failed to start camera", exc.message)
    }
  }

  private fun stopAnalyzeExercise(result: Result) {
    try {
      cameraProvider?.unbindAll()
      textureEntry?.release()
      textureEntry = null
      result.success(null)
    } catch (exc: Exception) {
      result.error("ERROR", "Failed to stop camera", exc.message)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    cameraExecutor.shutdown()
  }
}
