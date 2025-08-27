package com.woodlands.healthy.fitness_ai

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import androidx.camera.core.ImageProxy
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import androidx.core.graphics.createBitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult

interface IFitnessAI{
    fun init(context: Context, path: String)
    fun detect(imageProxy: ImageProxy, isFrontCamera: Boolean)
    fun setResultCallback(callback: (PoseLandmarkerResult?, width: Int, height: Int) -> Unit)
}

object FitnessAI : IFitnessAI {

    private lateinit var landmarker: PoseLandmarker
    private var resultCallback: ((PoseLandmarkerResult?, width: Int, height: Int) -> Unit)? = null

    override fun init(context: Context, path: String) {
        println("QQQQQQQQQrrrrrr1")
        val baseOptionBuilder = if (path.isNotEmpty()) {
            BaseOptions.builder().setModelAssetPath(path).setDelegate(Delegate.GPU)
        } else {
            BaseOptions.builder().setDelegate(Delegate.GPU)
        }
        val baseOptions = baseOptionBuilder.build()
        val optionsBuilder = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setMinPoseDetectionConfidence(0.2f)
            .setMinTrackingConfidence(0.2f)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setErrorListener { error ->
                println("MediaPipe error: $error")
            }
            .setResultListener(this::returnLivestreamResult)

        val options = optionsBuilder.build()
        landmarker = PoseLandmarker.createFromOptions(context, options)
    }

    override fun setResultCallback(callback: (PoseLandmarkerResult?, width: Int, height: Int) -> Unit) {
        resultCallback = callback
    }

    private fun returnLivestreamResult(
        result: PoseLandmarkerResult,
        input: MPImage
    ) {
        // Call the callback with the result
        resultCallback?.invoke(result, input.width, input.height)
    }

    override fun detect(imageProxy: ImageProxy, isFrontCamera: Boolean) {
        val frameTime = SystemClock.uptimeMillis()

        val bitmapBuffer =
            createBitmap(imageProxy.width, imageProxy.height)

        imageProxy.use { bitmapBuffer.copyPixelsFromBuffer(imageProxy.planes[0].buffer) }
        imageProxy.close()

        val matrix = Matrix().apply {
            postRotate(imageProxy.imageInfo.rotationDegrees.toFloat())

            if (isFrontCamera) {
                postScale(
                    -1f,
                    1f,
                    imageProxy.width.toFloat(),
                    imageProxy.height.toFloat()
                )
            }
        }
        val rotatedBitmap = Bitmap.createBitmap(
            bitmapBuffer, 0, 0, bitmapBuffer.width, bitmapBuffer.height,
            matrix, true
        )

        val mpImage = BitmapImageBuilder(rotatedBitmap).build()

        landmarker.detectAsync(mpImage, frameTime)
    }

}