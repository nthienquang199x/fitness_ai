package com.woodlands.healthy.fitness_ai

import android.graphics.PointF
import android.util.Log
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.sqrt

class ExerciseAnalyzer {
    
    companion object {
        // Exercise constants
        const val EXERCISE_SQUAT = "squat"
        const val EXERCISE_MOUNTAIN_CLIMBER = "mountain_climber"
        const val EXERCISE_BURPEE = "burpee"
        const val EXERCISE_HIGH_KNEES = "high_knees"
        const val EXERCISE_BICYCLE_CRUNCH = "bicycle_crunch"
        const val EXERCISE_WALL_SIT = "wall_sit"
        const val EXERCISE_TRICEP_DIP = "tricep_dip"
        const val EXERCISE_STEP_UP = "step_up"
        const val EXERCISE_SINGLE_LEG_DEADLIFT = "single_leg_deadlift"
        const val EXERCISE_DONKEY_KICK = "donkey_kick"
        const val EXERCISE_BIRD_DOG = "bird_dog"
        const val EXERCISE_LEG_RAISE = "leg_raise"
        const val EXERCISE_JUMPING_JACK = "jumping_jack"
        const val EXERCISE_LUNGE = "static_lunge"
        const val EXERCISE_ELEVATED_PUSHUP = "elevated_pushup"
        const val EXERCISE_GLUTE_BRIDGE = "glute_bridge"
        const val EXERCISE_BENT_LEG_INVERTED_ROW = "bent_leg_inverted_row"
        const val EXERCISE_PLANK = "plank"
        const val EXERCISE_BULGARIAN_SPLIT_SQUAT = "bulgarian_split_squat"
        const val EXERCISE_PUSHUP = "pushup"
        const val EXERCISE_SINGLE_LEG_HIP_THRUST = "single_leg_hip_thrust"
        const val EXERCISE_INVERTED_ROW = "inverted_row"
        const val EXERCISE_SUPERMAN_POSE = "superman_pose"
        const val EXERCISE_ABS_ALTERNATING = "abs_alternating"
        const val EXERCISE_BRIDGE = "bridge"
        const val EXERCISE_SIDE_BRIDGE = "side_bridge"
        
        // Difficulty constants
        const val DIFFICULTY_EASY = "easy"
        const val DIFFICULTY_MEDIUM = "medium"
        const val DIFFICULTY_HARD = "hard"
        
        // State constants
        const val STATE_START = 1
        const val STATE_DOWN = 2
        const val STATE_HOLD = 3
        const val STATE_UP = 4
        const val STATE_COMPLETE = 5
    }
    
    data class ExerciseMetrics(
        var kneeAngle: Float = 0f,
        var elbowAngle: Float = 0f,
        var hipAngle: Float = 0f,
        var bodyAlignment: Float = 0f,
        var hipHeight: Float = 0f,
        var hipToGround: Float = 0f,
        var kneeToShoulderDistance: Float = 0f,
        var kneeToElbowDistance: Float = 0f,
        var hipAbductionAngle: Float = 0f,
        var torsoAngle: Float = 0f,
        var hipRotationAngle: Float = 0f,
        var backAngle: Float = 0f
    )
    
    data class ExerciseFeedback(
        val isCorrect: Boolean,
        val message: String,
        val repCount: Int,
        val correctReps: Int
    )
    
    data class ExerciseState(
        var currentState: Int = STATE_START,
        var maxState: Int = STATE_START,
        var repCount: Int = 0,
        var correctReps: Int = 0,
        var repLogged: Boolean = false,
        var metricBuffer: MutableList<Map<String, Float>> = mutableListOf(),
        var repFrameBuffer: MutableList<Map<String, Float>> = mutableListOf(),
        var angleHistory: MutableList<Float> = mutableListOf(),
        var currentFeedback: List<String> = emptyList()
    )
    
    private var currentExercise = EXERCISE_SQUAT
    private var currentDifficulty = DIFFICULTY_MEDIUM
    private var exerciseState = ExerciseState()
    private var exerciseThresholds: Map<String, Map<String, List<Map<String, Float>>>>? = null
    
    fun setExercise(exercise: String) {
        currentExercise = exercise
        exerciseState = ExerciseState()
        Log.d("ExerciseAnalyzer", "Exercise set to: $exercise")
    }
    
    fun setDifficulty(difficulty: String) {
        currentDifficulty = difficulty
        Log.d("ExerciseAnalyzer", "Difficulty set to: $difficulty")
    }
    
    fun loadThresholds(thresholds: JSONObject) {
        try {
            val jsonObject = thresholds
            exerciseThresholds = mutableMapOf()
            val iterator = jsonObject.keys()
            while (iterator.hasNext()) {
                val exercise = iterator.next()
                val difficultyMap = jsonObject.getJSONObject(exercise)
                val difficultyIterator = difficultyMap.keys()
                val difficultyData = mutableMapOf<String, List<Map<String, Float>>>()
                
                while (difficultyIterator.hasNext()) {
                    val difficulty = difficultyIterator.next()
                    val thresholdArray = difficultyMap.getJSONArray(difficulty)
                    val thresholdList = mutableListOf<Map<String, Float>>()
                    
                    for (i in 0 until thresholdArray.length()) {
                        val thresholdObj = thresholdArray.getJSONObject(i)
                        val thresholdMap = mutableMapOf<String, Float>()
                        val thresholdIterator = thresholdObj.keys()
                        
                        while (thresholdIterator.hasNext()) {
                            val key = thresholdIterator.next()
                            thresholdMap[key] = thresholdObj.getDouble(key).toFloat()
                        }
                        thresholdList.add(thresholdMap)
                    }
                    difficultyData[difficulty] = thresholdList
                }
                (exerciseThresholds as MutableMap)[exercise] = difficultyData
            }
            
            Log.d("ExerciseAnalyzer", "Thresholds loaded successfully for ${exerciseThresholds?.size} exercises")
        } catch (e: Exception) {
            Log.e("ExerciseAnalyzer", "Error loading thresholds: ${e.message}")
        }
    }
    
    fun analyzePose(landmarks: List<PointF>): ExerciseFeedback {
        if (landmarks.size < 33) {
            return ExerciseFeedback(false, "Cannot detect pose", exerciseState.repCount, exerciseState.correctReps)
        }
        
        // Check if side view is required (except for jumping jack)
        if (currentExercise != EXERCISE_JUMPING_JACK) {
            val hipLeft = landmarks[23]
            val hipRight = landmarks[24]
            if (abs(hipLeft.x - hipRight.x) > 0.1f * 640f) { // Assuming 640 width
                return ExerciseFeedback(false, "Incorrect viewpoint: Please use a side view", exerciseState.repCount, exerciseState.correctReps)
            }
        }
        
        val frameMetrics = calculateFrameMetrics(landmarks)
        
        // Add to metric buffer for smoothing
        exerciseState.metricBuffer.add(frameMetrics)
        if (exerciseState.metricBuffer.size > 3) {
            exerciseState.metricBuffer.removeAt(0)
        }
        
        // Calculate smoothed metrics
        val smoothedMetrics = calculateSmoothedMetrics(frameMetrics)
        
        // Handle static exercises differently
        val staticExercises = listOf(EXERCISE_WALL_SIT, EXERCISE_PLANK, EXERCISE_SIDE_BRIDGE, EXERCISE_SUPERMAN_POSE)
        if (currentExercise in staticExercises) {
            return handleStaticExercise(smoothedMetrics)
        }
        
        // Add to rep frame buffer for dynamic exercises
        exerciseState.repFrameBuffer.add(smoothedMetrics)
        if (exerciseState.repFrameBuffer.size > 30) {
            exerciseState.repFrameBuffer.removeAt(0)
        }
        
        // Get key metric and state triggers
        val keyMetric = getKeyMetric()
        val stateTriggers = getStateTriggers()
        
        if (keyMetric != null && smoothedMetrics.containsKey(keyMetric) && stateTriggers.isNotEmpty()) {
            val value = smoothedMetrics[keyMetric] ?: 0f
            val secondaryMetric = getSecondaryMetric(smoothedMetrics)
            
            // Add to angle history for trend analysis
            exerciseState.angleHistory.add(value)
            if (exerciseState.angleHistory.size > 10) {
                exerciseState.angleHistory.removeAt(0)
            }
            
            if (exerciseState.angleHistory.size >= 6) {
                val trend = calculateTrend(exerciseState.angleHistory)
                updateExerciseStateWithTrend(value, trend, secondaryMetric, stateTriggers)
            }
        }
        
        return ExerciseFeedback(
            true,
            exerciseState.currentFeedback.firstOrNull() ?: "Continue",
            exerciseState.repCount,
            exerciseState.correctReps
        )
    }
    
    private fun calculateFrameMetrics(landmarks: List<PointF>): Map<String, Float> {
        val metrics = mutableMapOf<String, Float>()
        
        when (currentExercise) {
            in listOf(EXERCISE_SQUAT, EXERCISE_BURPEE, EXERCISE_STEP_UP, EXERCISE_LUNGE, EXERCISE_BULGARIAN_SPLIT_SQUAT) -> {
                val hip = landmarks[24]
                val knee = landmarks[26]
                val ankle = landmarks[28]
                metrics["knee_angle"] = calculateAngle(hip, knee, ankle)
                metrics["hip_to_ground"] = abs(hip.y - ankle.y)
                if (currentExercise == EXERCISE_BURPEE) {
                    metrics["body_alignment_angle"] = calculateAngle(landmarks[12], hip, ankle)
                }
            }
            in listOf(EXERCISE_ELEVATED_PUSHUP, EXERCISE_PUSHUP, EXERCISE_INVERTED_ROW, EXERCISE_TRICEP_DIP, EXERCISE_BENT_LEG_INVERTED_ROW) -> {
                val shoulder = landmarks[12]
                val elbow = landmarks[14]
                val wrist = landmarks[16]
                val hip = landmarks[24]
                val ankle = landmarks[28]
                metrics["elbow_angle"] = calculateAngle(shoulder, elbow, wrist)
                metrics["body_alignment_angle"] = calculateAngle(shoulder, hip, ankle)
            }
            in listOf(EXERCISE_GLUTE_BRIDGE, EXERCISE_BRIDGE, EXERCISE_SINGLE_LEG_HIP_THRUST) -> {
                val shoulder = landmarks[12]
                val hip = landmarks[24]
                val knee = landmarks[26]
                metrics["hip_angle"] = calculateAngle(shoulder, hip, knee)
                metrics["hip_height"] = abs(hip.y - shoulder.y)
            }
            in listOf(EXERCISE_MOUNTAIN_CLIMBER, EXERCISE_HIGH_KNEES) -> {
                val shoulder = landmarks[12]
                val knee = landmarks[26]
                metrics["knee_to_shoulder_distance"] = abs(knee.y - shoulder.y)
            }
            in listOf(EXERCISE_ABS_ALTERNATING, EXERCISE_BICYCLE_CRUNCH) -> {
                val shoulder = landmarks[11]
                val knee = landmarks[26]
                val hip = landmarks[24]
                metrics["knee_to_elbow_distance"] = abs(knee.y - shoulder.y)
                metrics["torso_angle"] = calculateAngle(shoulder, hip, landmarks[12])
            }
            in listOf(EXERCISE_PLANK, EXERCISE_SIDE_BRIDGE, EXERCISE_SUPERMAN_POSE) -> {
                val shoulder = landmarks[12]
                val hip = landmarks[24]
                val ankle = landmarks[28]
                metrics["body_alignment_angle"] = calculateAngle(shoulder, hip, ankle)
            }
            EXERCISE_WALL_SIT -> {
                val hip = landmarks[24]
                val knee = landmarks[26]
                val ankle = landmarks[28]
                metrics["knee_angle"] = calculateAngle(hip, knee, ankle)
            }
            in listOf(EXERCISE_SINGLE_LEG_DEADLIFT, EXERCISE_BIRD_DOG, EXERCISE_LEG_RAISE, EXERCISE_DONKEY_KICK) -> {
                val shoulder = landmarks[12]
                val hip = landmarks[24]
                val knee = landmarks[26]
                metrics["hip_angle"] = calculateAngle(shoulder, hip, knee)
                if (currentExercise == EXERCISE_BIRD_DOG) {
                    metrics["hip_rotation_angle"] = abs(landmarks[23].y - landmarks[24].y)
                }
                if (currentExercise == EXERCISE_SINGLE_LEG_DEADLIFT) {
                    metrics["back_angle"] = calculateAngle(shoulder, hip, landmarks[11])
                }
            }
            EXERCISE_JUMPING_JACK -> {
                val shoulder = landmarks[12]
                val hipLeft = landmarks[23]
                val hipRight = landmarks[24]
                metrics["hip_abduction_angle"] = calculateAngle(hipLeft, shoulder, hipRight)
            }
        }
        
        return metrics
    }
    
    private fun calculateSmoothedMetrics(currentMetrics: Map<String, Float>): Map<String, Float> {
        val smoothed = mutableMapOf<String, Float>()
        
        for (key in currentMetrics.keys) {
            val values = exerciseState.metricBuffer.mapNotNull { it[key] }
            if (values.isNotEmpty()) {
                smoothed[key] = values.average().toFloat()
            }
        }
        
        return smoothed
    }
    
    private fun getKeyMetric(): String? {
        return when (currentExercise) {
            in listOf(EXERCISE_SQUAT, EXERCISE_BURPEE, EXERCISE_STEP_UP, EXERCISE_LUNGE, EXERCISE_BULGARIAN_SPLIT_SQUAT) -> "knee_angle"
            in listOf(EXERCISE_MOUNTAIN_CLIMBER, EXERCISE_HIGH_KNEES) -> "knee_to_shoulder_distance"
            in listOf(EXERCISE_BICYCLE_CRUNCH, EXERCISE_ABS_ALTERNATING) -> "knee_to_elbow_distance"
            in listOf(EXERCISE_WALL_SIT, EXERCISE_TRICEP_DIP) -> "knee_angle"
            in listOf(EXERCISE_SINGLE_LEG_DEADLIFT, EXERCISE_DONKEY_KICK, EXERCISE_BIRD_DOG, EXERCISE_LEG_RAISE) -> "hip_angle"
            in listOf(EXERCISE_ELEVATED_PUSHUP, EXERCISE_PUSHUP, EXERCISE_INVERTED_ROW, EXERCISE_BENT_LEG_INVERTED_ROW) -> "elbow_angle"
            in listOf(EXERCISE_GLUTE_BRIDGE, EXERCISE_BRIDGE) -> "hip_height"
            in listOf(EXERCISE_PLANK, EXERCISE_SUPERMAN_POSE, EXERCISE_SIDE_BRIDGE) -> "body_alignment_angle"
            EXERCISE_JUMPING_JACK -> "hip_abduction_angle"
            else -> null
        }
    }
    
    private fun getSecondaryMetric(metrics: Map<String, Float>): Float? {
        return metrics["body_alignment_angle"] ?: metrics["torso_angle"] ?: metrics["hip_rotation_angle"] ?: metrics["back_angle"]
    }
    
    private fun getStateTriggers(): Map<String, Pair<Float, Float>> {
        val baseTriggers = when (currentExercise) {
            in listOf(EXERCISE_SQUAT, EXERCISE_STEP_UP, EXERCISE_LUNGE, EXERCISE_BULGARIAN_SPLIT_SQUAT) -> {
                when (currentDifficulty) {
                    DIFFICULTY_EASY -> mapOf(
                        "state1" to 140f,
                        "state2" to 110f,
                        "state3" to 80f,
                        "state4" to 60f
                    )
                    DIFFICULTY_MEDIUM -> mapOf(
                        "state1" to 140f,
                        "state2" to 105f,
                        "state3" to 75f,
                        "state4" to 60f
                    )
                    DIFFICULTY_HARD -> mapOf(
                        "state1" to 140f,
                        "state2" to 100f,
                        "state3" to 70f,
                        "state4" to 60f
                    )
                    else -> emptyMap()
                }
            }
            in listOf(EXERCISE_PUSHUP, EXERCISE_ELEVATED_PUSHUP, EXERCISE_INVERTED_ROW, EXERCISE_BENT_LEG_INVERTED_ROW) -> {
                when (currentDifficulty) {
                    DIFFICULTY_EASY -> mapOf(
                        "state1" to 150f,
                        "state2" to 120f,
                        "state3" to 80f,
                        "state4" to 170f
                    )
                    DIFFICULTY_MEDIUM -> mapOf(
                        "state1" to 150f,
                        "state2" to 115f,
                        "state3" to 75f,
                        "state4" to 170f
                    )
                    DIFFICULTY_HARD -> mapOf(
                        "state1" to 150f,
                        "state2" to 110f,
                        "state3" to 70f,
                        "state4" to 170f
                    )
                    else -> emptyMap()
                }
            }
            else -> emptyMap()
        }
        
        // Apply tolerance based on difficulty
        val tolerance = when (currentDifficulty) {
            DIFFICULTY_EASY -> 0.1f
            DIFFICULTY_MEDIUM -> 0.05f
            DIFFICULTY_HARD -> 0.02f
            else -> 0.05f
        }
        
        return baseTriggers.mapValues { (_, value) ->
            val baseValue = value
            baseValue * (1 - tolerance) to baseValue * (1 + tolerance)
        }
    }
    
    private fun calculateTrend(angleHistory: List<Float>): List<Float> {
        val trend = mutableListOf<Float>()
        for (i in 1 until angleHistory.size) {
            trend.add(angleHistory[i] - angleHistory[i - 1])
        }
        return trend
    }
    
    private fun updateExerciseStateWithTrend(value: Float, trend: List<Float>, secondaryMetric: Float?, stateTriggers: Map<String, Pair<Float, Float>>) {
        val trendMean = trend.takeLast(3).average().toFloat()
        
        when (currentExercise) {
            in listOf(EXERCISE_SQUAT, EXERCISE_BURPEE, EXERCISE_STEP_UP, EXERCISE_LUNGE, EXERCISE_BULGARIAN_SPLIT_SQUAT,
                     EXERCISE_ELEVATED_PUSHUP, EXERCISE_PUSHUP, EXERCISE_INVERTED_ROW, EXERCISE_BENT_LEG_INVERTED_ROW,
                     EXERCISE_SINGLE_LEG_DEADLIFT, EXERCISE_DONKEY_KICK, EXERCISE_LEG_RAISE, EXERCISE_SINGLE_LEG_HIP_THRUST) -> {
                updateSquatLikeState(value, trendMean, secondaryMetric, stateTriggers)
            }
            EXERCISE_JUMPING_JACK -> {
                updateJumpingJackState(value, trendMean, stateTriggers)
            }
            in listOf(EXERCISE_MOUNTAIN_CLIMBER, EXERCISE_HIGH_KNEES) -> {
                updateMountainClimberState(value, trendMean, stateTriggers)
            }
            in listOf(EXERCISE_BICYCLE_CRUNCH, EXERCISE_ABS_ALTERNATING, EXERCISE_GLUTE_BRIDGE, EXERCISE_BRIDGE) -> {
                updateBicycleCrunchState(value, trendMean, secondaryMetric, stateTriggers)
            }
            EXERCISE_BIRD_DOG -> {
                updateBirdDogState(value, trendMean, secondaryMetric, stateTriggers)
            }
        }
    }
    
    private fun updateSquatLikeState(value: Float, trendMean: Float, secondaryMetric: Float?, stateTriggers: Map<String, Pair<Float, Float>>) {
        when (exerciseState.currentState) {
            STATE_START -> {
                val state2Threshold = stateTriggers["state2"]?.second
                if (trendMean < -1.0f && state2Threshold != null && value < state2Threshold) {
                    exerciseState.currentState = STATE_DOWN
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_DOWN)
                    exerciseState.repFrameBuffer.clear()
                    exerciseState.repFrameBuffer.add(exerciseState.metricBuffer.lastOrNull() ?: emptyMap())
                    exerciseState.repLogged = false
                }
            }
            STATE_DOWN -> {
                val state3Threshold = stateTriggers["state3"]?.second
                val state4Threshold = stateTriggers["state4"]?.second
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if (state3Threshold != null && value < state3Threshold) {
                    exerciseState.currentState = STATE_HOLD
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_HOLD)
                } else if ((state4Threshold != null && value < state4Threshold) || 
                          (secondaryMetric != null && state4Threshold != null && secondaryMetric < state4Threshold)) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_HOLD -> {
                val state4Threshold = stateTriggers["state4"]?.second
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if ((state4Threshold != null && value < state4Threshold) || 
                    (secondaryMetric != null && state4Threshold != null && secondaryMetric < state4Threshold)) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_UP -> {
                val state2MinThreshold = stateTriggers["state2"]?.first
                if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
        }
    }
    
    private fun updateJumpingJackState(value: Float, trendMean: Float, stateTriggers: Map<String, Pair<Float, Float>>) {
        when (exerciseState.currentState) {
            STATE_START -> {
                val state2MinThreshold = stateTriggers["state2"]?.first
                if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    exerciseState.currentState = STATE_DOWN
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_DOWN)
                    exerciseState.repFrameBuffer.clear()
                    exerciseState.repFrameBuffer.add(exerciseState.metricBuffer.lastOrNull() ?: emptyMap())
                    exerciseState.repLogged = false
                }
            }
            STATE_DOWN -> {
                val state3MinThreshold = stateTriggers["state3"]?.first
                val state4MinThreshold = stateTriggers["state4"]?.first
                val state2MaxThreshold = stateTriggers["state2"]?.second
                
                if (state3MinThreshold != null && value > state3MinThreshold) {
                    exerciseState.currentState = STATE_HOLD
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_HOLD)
                } else if (state4MinThreshold != null && value > state4MinThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MaxThreshold != null && trendMean < -1.0f && value < state2MaxThreshold) {
                    completeRep()
                }
            }
            STATE_HOLD -> {
                val state4MinThreshold = stateTriggers["state4"]?.first
                val state2MaxThreshold = stateTriggers["state2"]?.second
                
                if (state4MinThreshold != null && value > state4MinThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MaxThreshold != null && trendMean < -1.0f && value < state2MaxThreshold) {
                    completeRep()
                }
            }
            STATE_UP -> {
                val state2MaxThreshold = stateTriggers["state2"]?.second
                if (state2MaxThreshold != null && trendMean < -1.0f && value < state2MaxThreshold) {
                    completeRep()
                }
            }
        }
    }
    
    private fun updateMountainClimberState(value: Float, trendMean: Float, stateTriggers: Map<String, Pair<Float, Float>>) {
        when (exerciseState.currentState) {
            STATE_START -> {
                val state2MaxThreshold = stateTriggers["state2"]?.second
                if (state2MaxThreshold != null && trendMean < -1.0f && value < state2MaxThreshold) {
                    exerciseState.currentState = STATE_DOWN
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_DOWN)
                    exerciseState.repFrameBuffer.clear()
                    exerciseState.repFrameBuffer.add(exerciseState.metricBuffer.lastOrNull() ?: emptyMap())
                    exerciseState.repLogged = false
                }
            }
            STATE_DOWN -> {
                val state3MaxThreshold = stateTriggers["state3"]?.second
                val state4MaxThreshold = stateTriggers["state4"]?.second
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if (state3MaxThreshold != null && value < state3MaxThreshold) {
                    exerciseState.currentState = STATE_HOLD
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_HOLD)
                } else if (state4MaxThreshold != null && value < state4MaxThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_HOLD -> {
                val state4MaxThreshold = stateTriggers["state4"]?.second
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if (state4MaxThreshold != null && value < state4MaxThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_UP -> {
                val state2MinThreshold = stateTriggers["state2"]?.first
                if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
        }
    }
    
    private fun updateBicycleCrunchState(value: Float, trendMean: Float, secondaryMetric: Float?, stateTriggers: Map<String, Pair<Float, Float>>) {
        when (exerciseState.currentState) {
            STATE_START -> {
                val state2MaxThreshold = stateTriggers["state2"]?.second
                if (state2MaxThreshold != null && trendMean < -1.0f && value < state2MaxThreshold) {
                    exerciseState.currentState = STATE_DOWN
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_DOWN)
                    exerciseState.repFrameBuffer.clear()
                    exerciseState.repFrameBuffer.add(exerciseState.metricBuffer.lastOrNull() ?: emptyMap())
                    exerciseState.repLogged = false
                }
            }
            STATE_DOWN -> {
                val state3MaxThreshold = stateTriggers["state3"]?.second
                val state4MinThreshold = stateTriggers["state4"]?.first
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if (state3MaxThreshold != null && value < state3MaxThreshold) {
                    exerciseState.currentState = STATE_HOLD
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_HOLD)
                } else if (secondaryMetric != null && state4MinThreshold != null && secondaryMetric > state4MinThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_HOLD -> {
                val state4MinThreshold = stateTriggers["state4"]?.first
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if (secondaryMetric != null && state4MinThreshold != null && secondaryMetric > state4MinThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_UP -> {
                val state2MinThreshold = stateTriggers["state2"]?.first
                if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
        }
    }
    
    private fun updateBirdDogState(value: Float, trendMean: Float, secondaryMetric: Float?, stateTriggers: Map<String, Pair<Float, Float>>) {
        when (exerciseState.currentState) {
            STATE_START -> {
                val state2MaxThreshold = stateTriggers["state2"]?.second
                if (state2MaxThreshold != null && trendMean < -1.0f && value < state2MaxThreshold) {
                    exerciseState.currentState = STATE_DOWN
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_DOWN)
                    exerciseState.repFrameBuffer.clear()
                    exerciseState.repFrameBuffer.add(exerciseState.metricBuffer.lastOrNull() ?: emptyMap())
                    exerciseState.repLogged = false
                }
            }
            STATE_DOWN -> {
                val state3MinThreshold = stateTriggers["state3"]?.first
                val state4MinThreshold = stateTriggers["state4"]?.first
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if (state3MinThreshold != null && value > state3MinThreshold) {
                    exerciseState.currentState = STATE_HOLD
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_HOLD)
                } else if (secondaryMetric != null && state4MinThreshold != null && secondaryMetric > state4MinThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_HOLD -> {
                val state4MinThreshold = stateTriggers["state4"]?.first
                val state2MinThreshold = stateTriggers["state2"]?.first
                
                if (secondaryMetric != null && state4MinThreshold != null && secondaryMetric > state4MinThreshold) {
                    exerciseState.currentState = STATE_UP
                    exerciseState.maxState = maxOf(exerciseState.maxState, STATE_UP)
                } else if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
            STATE_UP -> {
                val state2MinThreshold = stateTriggers["state2"]?.first
                if (state2MinThreshold != null && trendMean > 1.0f && value > state2MinThreshold) {
                    completeRep()
                }
            }
        }
    }
    
    private fun completeRep() {
        exerciseState.repCount++
        
        if (!exerciseState.repLogged) {
            val isCorrect = analyzeRepCorrectness()
            
            if (isCorrect && exerciseState.maxState >= STATE_HOLD) {
                exerciseState.correctReps++
            }
            
            exerciseState.repLogged = true
            exerciseState.repFrameBuffer.clear()
            exerciseState.maxState = STATE_START
        }
        
        exerciseState.currentState = STATE_START
        exerciseState.maxState = STATE_START
    }
    
    private fun handleStaticExercise(metrics: Map<String, Float>): ExerciseFeedback {
        val thresholds = getCurrentThresholds()
        if (thresholds.isEmpty()) {
            return ExerciseFeedback(false, "No thresholds available for this exercise", exerciseState.repCount, exerciseState.correctReps)
        }
        
        val isCorrect = analyzeRepCorrectness()
        
        if (exerciseState.repCount == 0) {
            exerciseState.repCount = 1
            if (isCorrect) {
                exerciseState.correctReps = 1
            }
        }
        
        val message = if (isCorrect) "Good form! Hold steady" else "Adjust your form"
        return ExerciseFeedback(isCorrect, message, exerciseState.repCount, exerciseState.correctReps)
    }
    
    private fun analyzeRepCorrectness(): Boolean {
        if (exerciseState.repFrameBuffer.isEmpty()) return false
        
        val thresholds = getCurrentThresholds()
        if (thresholds.isEmpty()) return false
        
        var isCorrect = true
        
        // Analyze all frames in the rep buffer
        for (metrics in exerciseState.repFrameBuffer) {
            for ((key, thresholdValue) in thresholds) {
                val metricValue = metrics[key] ?: 0f
                if (metricValue == 0f) continue
                
                when {
                    key.endsWith("_min") -> {
                        if (metricValue < thresholdValue) {
                            isCorrect = false
                        }
                    }
                    key.endsWith("_max") -> {
                        if (metricValue > thresholdValue) {
                            isCorrect = false
                        }
                    }
                }
            }
        }
        
        // Additional checks like in Python code
        if (exerciseState.maxState < 3) {
            isCorrect = false
        }
        
        return isCorrect
    }
    
    private fun calculateAngle(pointA: PointF, pointB: PointF, pointC: PointF): Float {
        val vectorAB = PointF(pointA.x - pointB.x, pointA.y - pointB.y)
        val vectorCB = PointF(pointC.x - pointB.x, pointC.y - pointB.y)
        
        val dotProduct = vectorAB.x * vectorCB.x + vectorAB.y * vectorCB.y
        val magnitudeAB = sqrt(vectorAB.x * vectorAB.x + vectorAB.y * vectorAB.y)
        val magnitudeCB = sqrt(vectorCB.x * vectorCB.x + vectorCB.y * vectorCB.y)
        
        if (magnitudeAB == 0f || magnitudeCB == 0f) return 0f
        
        val cosAngle = dotProduct / (magnitudeAB * magnitudeCB)
        val angle = acos(cosAngle.coerceIn(-1f, 1f))
        
        return Math.toDegrees(angle.toDouble()).toFloat()
    }
    
    private fun getCurrentThresholds(): Map<String, Float> {
        val exerciseData = exerciseThresholds?.get(currentExercise)
        val difficultyData = exerciseData?.get(currentDifficulty)
        
        if (difficultyData.isNullOrEmpty()) {
            Log.w("ExerciseAnalyzer", "No thresholds found for $currentExercise ($currentDifficulty)")
            return emptyMap()
        }
        
        return difficultyData.firstOrNull() ?: emptyMap()
    }
    
    fun getExerciseState(): ExerciseState = exerciseState
    
    fun resetExercise() {
        exerciseState = ExerciseState()
    }
    
    fun getAvailableExercises(): List<String> {
        return exerciseThresholds?.keys?.toList() ?: emptyList()
    }
    
    fun getAvailableDifficulties(): List<String> {
        return listOf(DIFFICULTY_EASY, DIFFICULTY_MEDIUM, DIFFICULTY_HARD)
    }
}
