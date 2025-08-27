import Foundation
import UIKit
import simd

class ExerciseAnalyzer {
    
    // MARK: - Exercise Constants
    static let EXERCISE_SQUAT = "squat"
    static let EXERCISE_MOUNTAIN_CLIMBER = "mountain_climber"
    static let EXERCISE_BURPEE = "burpee"
    static let EXERCISE_HIGH_KNEES = "high_knees"
    static let EXERCISE_BICYCLE_CRUNCH = "bicycle_crunch"
    static let EXERCISE_WALL_SIT = "wall_sit"
    static let EXERCISE_TRICEP_DIP = "tricep_dip"
    static let EXERCISE_STEP_UP = "step_up"
    static let EXERCISE_SINGLE_LEG_DEADLIFT = "single_leg_deadlift"
    static let EXERCISE_DONKEY_KICK = "donkey_kick"
    static let EXERCISE_BIRD_DOG = "bird_dog"
    static let EXERCISE_LEG_RAISE = "leg_raise"
    static let EXERCISE_JUMPING_JACK = "jumping_jack"
    static let EXERCISE_LUNGE = "static_lunge"
    static let EXERCISE_ELEVATED_PUSHUP = "elevated_pushup"
    static let EXERCISE_GLUTE_BRIDGE = "glute_bridge"
    static let EXERCISE_BENT_LEG_INVERTED_ROW = "bent_leg_inverted_row"
    static let EXERCISE_PLANK = "plank"
    static let EXERCISE_BULGARIAN_SPLIT_SQUAT = "bulgarian_split_squat"
    static let EXERCISE_PUSHUP = "pushup"
    static let EXERCISE_SINGLE_LEG_HIP_THRUST = "single_leg_hip_thrust"
    static let EXERCISE_INVERTED_ROW = "inverted_row"
    static let EXERCISE_SUPERMAN_POSE = "superman_pose"
    static let EXERCISE_ABS_ALTERNATING = "abs_alternating"
    static let EXERCISE_BRIDGE = "bridge"
    static let EXERCISE_SIDE_BRIDGE = "side_bridge"
    
    // MARK: - Difficulty Constants
    static let DIFFICULTY_EASY = "easy"
    static let DIFFICULTY_MEDIUM = "medium"
    static let DIFFICULTY_HARD = "hard"
    
    // MARK: - State Constants
    static let STATE_START = 1
    static let STATE_DOWN = 2
    static let STATE_HOLD = 3
    static let STATE_UP = 4
    static let STATE_COMPLETE = 5
    
    // MARK: - Data Structures
    struct ExerciseMetrics {
        var kneeAngle: Float = 0.0
        var elbowAngle: Float = 0.0
        var hipAngle: Float = 0.0
        var bodyAlignment: Float = 0.0
        var hipHeight: Float = 0.0
        var hipToGround: Float = 0.0
        var kneeToShoulderDistance: Float = 0.0
        var kneeToElbowDistance: Float = 0.0
        var hipAbductionAngle: Float = 0.0
        var torsoAngle: Float = 0.0
        var hipRotationAngle: Float = 0.0
        var backAngle: Float = 0.0
    }
    
    struct ExerciseFeedback {
        let isCorrect: Bool
        let message: String
        let repCount: Int
        let correctReps: Int
    }
    
    struct ExerciseState {
        var currentState: Int = ExerciseAnalyzer.STATE_START
        var maxState: Int = ExerciseAnalyzer.STATE_START
        var repCount: Int = 0
        var correctReps: Int = 0
        var repLogged: Bool = false
        var metricBuffer: [[String: Float]] = []
        var repFrameBuffer: [[String: Float]] = []
        var angleHistory: [Float] = []
        var currentFeedback: [String] = []
    }
    
    // MARK: - Properties
    private var currentExercise = ExerciseAnalyzer.EXERCISE_SQUAT
    private var currentDifficulty = ExerciseAnalyzer.DIFFICULTY_MEDIUM
    private var exerciseState = ExerciseState()
    private var exerciseThresholds: [String: [String: [[String: Float]]]]?
    
    // MARK: - Public Methods
    func setExercise(_ exercise: String) {
        currentExercise = exercise
        exerciseState = ExerciseState()
        print("Exercise set to: \(exercise)")
    }
    
    func setDifficulty(_ difficulty: String) {
        currentDifficulty = difficulty
        print("Difficulty set to: \(difficulty)")
    }
    
    func loadThresholds(from jsonString: String) {
        do {
            guard let data = jsonString.data(using: .utf8) else {
                print("Error: Invalid JSON string")
                return
            }
            
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            
            // Parse the JSON structure
            exerciseThresholds = [:]
            
            for (exercise, exerciseData) in jsonObject {
                guard let difficultyMap = exerciseData as? [String: Any] else { continue }
                
                var difficultyData: [String: [[String: Float]]] = [:]
                
                for (difficulty, difficultyArray) in difficultyMap {
                    guard let thresholdArray = difficultyArray as? [[String: Any]] else { continue }
                    
                    var thresholdList: [[String: Float]] = []
                    
                    for thresholdObj in thresholdArray {
                        var thresholdMap: [String: Float] = [:]
                        
                        for (key, value) in thresholdObj {
                            if let doubleValue = value as? Double {
                                thresholdMap[key] = Float(doubleValue)
                            } else if let floatValue = value as? Float {
                                thresholdMap[key] = floatValue
                            }
                        }
                        
                        thresholdList.append(thresholdMap)
                    }
                    
                    difficultyData[difficulty] = thresholdList
                }
                
                exerciseThresholds?[exercise] = difficultyData
            }
            
            print("Thresholds loaded successfully for \(exerciseThresholds?.count ?? 0) exercises")
            
        } catch {
            print("Error loading thresholds: \(error)")
        }
    }
    
    func analyzePose(_ landmarks: [CGPoint]) -> ExerciseFeedback {
        guard landmarks.count >= 33 else {
            return ExerciseFeedback(isCorrect: false, message: "Cannot detect pose", repCount: exerciseState.repCount, correctReps: exerciseState.correctReps)
        }
        
        // Check if side view is required (except for jumping jack)
        if currentExercise != ExerciseAnalyzer.EXERCISE_JUMPING_JACK {
            let hipLeft = landmarks[23]
            let hipRight = landmarks[24]
            if abs(hipLeft.x - hipRight.x) > 0.1 * 640 { // Assuming 640 width
                return ExerciseFeedback(isCorrect: false, message: "Incorrect viewpoint: Please use a side view", repCount: exerciseState.repCount, correctReps: exerciseState.correctReps)
            }
        }
        
        let frameMetrics = calculateFrameMetrics(landmarks)
        
        // Add to metric buffer for smoothing
        exerciseState.metricBuffer.append(frameMetrics)
        if exerciseState.metricBuffer.count > 3 {
            exerciseState.metricBuffer.removeFirst()
        }
        
        // Calculate smoothed metrics
        let smoothedMetrics = calculateSmoothedMetrics(frameMetrics)
        
        // Handle static exercises differently
        let staticExercises = [ExerciseAnalyzer.EXERCISE_WALL_SIT, ExerciseAnalyzer.EXERCISE_PLANK, ExerciseAnalyzer.EXERCISE_SIDE_BRIDGE, ExerciseAnalyzer.EXERCISE_SUPERMAN_POSE]
        if staticExercises.contains(currentExercise) {
            return handleStaticExercise(smoothedMetrics)
        }
        
        // Add to rep frame buffer for dynamic exercises
        exerciseState.repFrameBuffer.append(smoothedMetrics)
        if exerciseState.repFrameBuffer.count > 30 {
            exerciseState.repFrameBuffer.removeFirst()
        }
        
        // Get key metric and state triggers
        let keyMetric = getKeyMetric()
        let stateTriggers = getStateTriggers()
        
        if let keyMetric = keyMetric, let value = smoothedMetrics[keyMetric], !stateTriggers.isEmpty {
            let secondaryMetric = getSecondaryMetric(smoothedMetrics)
            
            // Add to angle history for trend analysis
            exerciseState.angleHistory.append(value)
            if exerciseState.angleHistory.count > 10 {
                exerciseState.angleHistory.removeFirst()
            }
            
            if exerciseState.angleHistory.count >= 6 {
                let trend = calculateTrend(exerciseState.angleHistory)
                updateExerciseStateWithTrend(value: value, trend: trend, secondaryMetric: secondaryMetric, stateTriggers: stateTriggers)
            }
        }
        
        return ExerciseFeedback(
            isCorrect: true,
            message: exerciseState.currentFeedback.first ?? "Continue",
            repCount: exerciseState.repCount,
            correctReps: exerciseState.correctReps
        )
    }
    
    // MARK: - Private Methods
    private func calculateFrameMetrics(_ landmarks: [CGPoint]) -> [String: Float] {
        var metrics: [String: Float] = [:]
        
        switch currentExercise {
        case ExerciseAnalyzer.EXERCISE_SQUAT, ExerciseAnalyzer.EXERCISE_BURPEE, ExerciseAnalyzer.EXERCISE_STEP_UP, ExerciseAnalyzer.EXERCISE_LUNGE, ExerciseAnalyzer.EXERCISE_BULGARIAN_SPLIT_SQUAT:
            let hip = landmarks[24]
            let knee = landmarks[26]
            let ankle = landmarks[28]
            metrics["knee_angle"] = calculateAngle(p1: hip, p2: knee, p3: ankle)
            metrics["hip_to_ground"] = abs(Float(hip.y - ankle.y))
            if currentExercise == ExerciseAnalyzer.EXERCISE_BURPEE {
                metrics["body_alignment_angle"] = calculateAngle(p1: landmarks[12], p2: hip, p3: ankle)
            }
            
        case ExerciseAnalyzer.EXERCISE_ELEVATED_PUSHUP, ExerciseAnalyzer.EXERCISE_PUSHUP, ExerciseAnalyzer.EXERCISE_INVERTED_ROW, ExerciseAnalyzer.EXERCISE_TRICEP_DIP, ExerciseAnalyzer.EXERCISE_BENT_LEG_INVERTED_ROW:
            let shoulder = landmarks[12]
            let elbow = landmarks[14]
            let wrist = landmarks[16]
            let hip = landmarks[24]
            let ankle = landmarks[28]
            metrics["elbow_angle"] = calculateAngle(p1: shoulder, p2: elbow, p3: wrist)
            metrics["body_alignment_angle"] = calculateAngle(p1: shoulder, p2: hip, p3: ankle)
            
        case ExerciseAnalyzer.EXERCISE_GLUTE_BRIDGE, ExerciseAnalyzer.EXERCISE_BRIDGE, ExerciseAnalyzer.EXERCISE_SINGLE_LEG_HIP_THRUST:
            let shoulder = landmarks[12]
            let hip = landmarks[24]
            let knee = landmarks[26]
            metrics["hip_angle"] = calculateAngle(p1: shoulder, p2: hip, p3: knee)
            metrics["hip_height"] = abs(Float(hip.y - shoulder.y))
            
        case ExerciseAnalyzer.EXERCISE_MOUNTAIN_CLIMBER, ExerciseAnalyzer.EXERCISE_HIGH_KNEES:
            let shoulder = landmarks[12]
            let knee = landmarks[26]
            metrics["knee_to_shoulder_distance"] = abs(Float(knee.y - shoulder.y))
            
        case ExerciseAnalyzer.EXERCISE_ABS_ALTERNATING, ExerciseAnalyzer.EXERCISE_BICYCLE_CRUNCH:
            let shoulder = landmarks[11]
            let knee = landmarks[26]
            let hip = landmarks[24]
            metrics["knee_to_elbow_distance"] = abs(Float(knee.y - shoulder.y))
            metrics["torso_angle"] = calculateAngle(p1: shoulder, p2: hip, p3: landmarks[12])
            
        case ExerciseAnalyzer.EXERCISE_PLANK, ExerciseAnalyzer.EXERCISE_SIDE_BRIDGE, ExerciseAnalyzer.EXERCISE_SUPERMAN_POSE:
            let shoulder = landmarks[12]
            let hip = landmarks[24]
            let ankle = landmarks[28]
            metrics["body_alignment_angle"] = calculateAngle(p1: shoulder, p2: hip, p3: ankle)
            
        case ExerciseAnalyzer.EXERCISE_WALL_SIT:
            let hip = landmarks[24]
            let knee = landmarks[26]
            let ankle = landmarks[28]
            metrics["knee_angle"] = calculateAngle(p1: hip, p2: knee, p3: ankle)
            
        case ExerciseAnalyzer.EXERCISE_SINGLE_LEG_DEADLIFT, ExerciseAnalyzer.EXERCISE_BIRD_DOG, ExerciseAnalyzer.EXERCISE_LEG_RAISE, ExerciseAnalyzer.EXERCISE_DONKEY_KICK:
            let shoulder = landmarks[12]
            let hip = landmarks[24]
            let knee = landmarks[26]
            metrics["hip_angle"] = calculateAngle(p1: shoulder, p2: hip, p3: knee)
            if currentExercise == ExerciseAnalyzer.EXERCISE_BIRD_DOG {
                metrics["hip_rotation_angle"] = abs(Float(landmarks[23].y - landmarks[24].y))
            }
            if currentExercise == ExerciseAnalyzer.EXERCISE_SINGLE_LEG_DEADLIFT {
                metrics["back_angle"] = calculateAngle(p1: shoulder, p2: hip, p3: landmarks[11])
            }
            
        case ExerciseAnalyzer.EXERCISE_JUMPING_JACK:
            let shoulder = landmarks[12]
            let hipLeft = landmarks[23]
            let hipRight = landmarks[24]
            metrics["hip_abduction_angle"] = calculateAngle(p1: hipLeft, p2: shoulder, p3: hipRight)
            
        default:
            break
        }
        
        return metrics
    }
    
    private func calculateSmoothedMetrics(_ currentMetrics: [String: Float]) -> [String: Float] {
        var smoothed: [String: Float] = [:]
        
        for key in currentMetrics.keys {
            let values = exerciseState.metricBuffer.compactMap { $0[key] }
            if !values.isEmpty {
                smoothed[key] = values.reduce(0, +) / Float(values.count)
            }
        }
        
        return smoothed
    }
    
    private func getKeyMetric() -> String? {
        switch currentExercise {
        case ExerciseAnalyzer.EXERCISE_SQUAT, ExerciseAnalyzer.EXERCISE_BURPEE, ExerciseAnalyzer.EXERCISE_STEP_UP, ExerciseAnalyzer.EXERCISE_LUNGE, ExerciseAnalyzer.EXERCISE_BULGARIAN_SPLIT_SQUAT:
            return "knee_angle"
        case ExerciseAnalyzer.EXERCISE_MOUNTAIN_CLIMBER, ExerciseAnalyzer.EXERCISE_HIGH_KNEES:
            return "knee_to_shoulder_distance"
        case ExerciseAnalyzer.EXERCISE_BICYCLE_CRUNCH, ExerciseAnalyzer.EXERCISE_ABS_ALTERNATING:
            return "knee_to_elbow_distance"
        case ExerciseAnalyzer.EXERCISE_WALL_SIT, ExerciseAnalyzer.EXERCISE_TRICEP_DIP:
            return "knee_angle"
        case ExerciseAnalyzer.EXERCISE_SINGLE_LEG_DEADLIFT, ExerciseAnalyzer.EXERCISE_DONKEY_KICK, ExerciseAnalyzer.EXERCISE_BIRD_DOG, ExerciseAnalyzer.EXERCISE_LEG_RAISE:
            return "hip_angle"
        case ExerciseAnalyzer.EXERCISE_ELEVATED_PUSHUP, ExerciseAnalyzer.EXERCISE_PUSHUP, ExerciseAnalyzer.EXERCISE_INVERTED_ROW, ExerciseAnalyzer.EXERCISE_BENT_LEG_INVERTED_ROW:
            return "elbow_angle"
        case ExerciseAnalyzer.EXERCISE_GLUTE_BRIDGE, ExerciseAnalyzer.EXERCISE_BRIDGE:
            return "hip_height"
        case ExerciseAnalyzer.EXERCISE_PLANK, ExerciseAnalyzer.EXERCISE_SUPERMAN_POSE, ExerciseAnalyzer.EXERCISE_SIDE_BRIDGE:
            return "body_alignment_angle"
        case ExerciseAnalyzer.EXERCISE_JUMPING_JACK:
            return "hip_abduction_angle"
        default:
            return nil
        }
    }
    
    private func getSecondaryMetric(_ metrics: [String: Float]) -> Float? {
        return metrics["body_alignment_angle"] ?? metrics["torso_angle"] ?? metrics["hip_rotation_angle"] ?? metrics["back_angle"]
    }
    
    private func getStateTriggers() -> [String: (Float, Float)] {
        let baseTriggers: [String: Float]
        
        switch currentExercise {
        case ExerciseAnalyzer.EXERCISE_SQUAT, ExerciseAnalyzer.EXERCISE_STEP_UP, ExerciseAnalyzer.EXERCISE_LUNGE, ExerciseAnalyzer.EXERCISE_BULGARIAN_SPLIT_SQUAT:
            baseTriggers = [
                "state1": currentDifficulty == ExerciseAnalyzer.DIFFICULTY_EASY ? 140 : currentDifficulty == ExerciseAnalyzer.DIFFICULTY_MEDIUM ? 140 : 140,
                "state2": currentDifficulty == ExerciseAnalyzer.DIFFICULTY_EASY ? 110 : currentDifficulty == ExerciseAnalyzer.DIFFICULTY_MEDIUM ? 105 : 100,
                "state3": currentDifficulty == ExerciseAnalyzer.DIFFICULTY_EASY ? 80 : currentDifficulty == ExerciseAnalyzer.DIFFICULTY_MEDIUM ? 75 : 70,
                "state4": 60
            ]
        case ExerciseAnalyzer.EXERCISE_PUSHUP, ExerciseAnalyzer.EXERCISE_ELEVATED_PUSHUP, ExerciseAnalyzer.EXERCISE_INVERTED_ROW, ExerciseAnalyzer.EXERCISE_BENT_LEG_INVERTED_ROW:
            baseTriggers = [
                "state1": 150,
                "state2": currentDifficulty == ExerciseAnalyzer.DIFFICULTY_EASY ? 120 : currentDifficulty == ExerciseAnalyzer.DIFFICULTY_MEDIUM ? 115 : 110,
                "state3": currentDifficulty == ExerciseAnalyzer.DIFFICULTY_EASY ? 80 : currentDifficulty == ExerciseAnalyzer.DIFFICULTY_MEDIUM ? 75 : 70,
                "state4": 170
            ]
        default:
            return [:]
        }
        
        // Apply tolerance based on difficulty
        let tolerance: Float = currentDifficulty == ExerciseAnalyzer.DIFFICULTY_EASY ? 0.1 : currentDifficulty == ExerciseAnalyzer.DIFFICULTY_MEDIUM ? 0.05 : 0.02
        
        return baseTriggers.mapValues { value in
            (value * (1 - tolerance), value * (1 + tolerance))
        }
    }
    
    private func calculateTrend(_ angleHistory: [Float]) -> [Float] {
        var trend: [Float] = []
        for i in 1..<angleHistory.count {
            trend.append(angleHistory[i] - angleHistory[i - 1])
        }
        return trend
    }
    
    private func updateExerciseStateWithTrend(value: Float, trend: [Float], secondaryMetric: Float?, stateTriggers: [String: (Float, Float)]) {
        let trendMean = trend.suffix(3).reduce(0, +) / Float(min(3, trend.count))
        
        switch currentExercise {
        case ExerciseAnalyzer.EXERCISE_SQUAT, ExerciseAnalyzer.EXERCISE_BURPEE, ExerciseAnalyzer.EXERCISE_STEP_UP, ExerciseAnalyzer.EXERCISE_LUNGE, ExerciseAnalyzer.EXERCISE_BULGARIAN_SPLIT_SQUAT,
             ExerciseAnalyzer.EXERCISE_ELEVATED_PUSHUP, ExerciseAnalyzer.EXERCISE_PUSHUP, ExerciseAnalyzer.EXERCISE_INVERTED_ROW, ExerciseAnalyzer.EXERCISE_BENT_LEG_INVERTED_ROW,
             ExerciseAnalyzer.EXERCISE_SINGLE_LEG_DEADLIFT, ExerciseAnalyzer.EXERCISE_DONKEY_KICK, ExerciseAnalyzer.EXERCISE_LEG_RAISE, ExerciseAnalyzer.EXERCISE_SINGLE_LEG_HIP_THRUST:
            updateSquatLikeState(value: value, trendMean: trendMean, secondaryMetric: secondaryMetric, stateTriggers: stateTriggers)
        case ExerciseAnalyzer.EXERCISE_JUMPING_JACK:
            updateJumpingJackState(value: value, trendMean: trendMean, stateTriggers: stateTriggers)
        case ExerciseAnalyzer.EXERCISE_MOUNTAIN_CLIMBER, ExerciseAnalyzer.EXERCISE_HIGH_KNEES:
            updateMountainClimberState(value: value, trendMean: trendMean, stateTriggers: stateTriggers)
        case ExerciseAnalyzer.EXERCISE_BICYCLE_CRUNCH, ExerciseAnalyzer.EXERCISE_ABS_ALTERNATING, ExerciseAnalyzer.EXERCISE_GLUTE_BRIDGE, ExerciseAnalyzer.EXERCISE_BRIDGE:
            updateBicycleCrunchState(value: value, trendMean: trendMean, secondaryMetric: secondaryMetric, stateTriggers: stateTriggers)
        case ExerciseAnalyzer.EXERCISE_BIRD_DOG:
            updateBirdDogState(value: value, trendMean: trendMean, secondaryMetric: secondaryMetric, stateTriggers: stateTriggers)
        default:
            break
        }
    }
    
    private func updateSquatLikeState(value: Float, trendMean: Float, secondaryMetric: Float?, stateTriggers: [String: (Float, Float)]) {
        switch exerciseState.currentState {
        case ExerciseAnalyzer.STATE_START:
            if let state2Threshold = stateTriggers["state2"]?.1, trendMean < -1.0 && value < state2Threshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_DOWN
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_DOWN)
                exerciseState.repFrameBuffer.removeAll()
                if let lastMetrics = exerciseState.metricBuffer.last {
                    exerciseState.repFrameBuffer.append(lastMetrics)
                }
                exerciseState.repLogged = false
            }
        case ExerciseAnalyzer.STATE_DOWN:
            if let state3Threshold = stateTriggers["state3"]?.1, value < state3Threshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_HOLD
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_HOLD)
            } else if let state4Threshold = stateTriggers["state4"]?.1, 
                      (value < state4Threshold || (secondaryMetric != nil && secondaryMetric! < state4Threshold)) {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_HOLD:
            if let state4Threshold = stateTriggers["state4"]?.1, 
               (value < state4Threshold || (secondaryMetric != nil && secondaryMetric! < state4Threshold)) {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_UP:
            if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        default:
            break
        }
    }
    
    private func updateJumpingJackState(value: Float, trendMean: Float, stateTriggers: [String: (Float, Float)]) {
        switch exerciseState.currentState {
        case ExerciseAnalyzer.STATE_START:
            if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_DOWN
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_DOWN)
                exerciseState.repFrameBuffer.removeAll()
                if let lastMetrics = exerciseState.metricBuffer.last {
                    exerciseState.repFrameBuffer.append(lastMetrics)
                }
                exerciseState.repLogged = false
            }
        case ExerciseAnalyzer.STATE_DOWN:
            if let state3MinThreshold = stateTriggers["state3"]?.0, value > state3MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_HOLD
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_HOLD)
            } else if let state4MinThreshold = stateTriggers["state4"]?.0, value > state4MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MaxThreshold = stateTriggers["state2"]?.1, trendMean < -1.0 && value < state2MaxThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_HOLD:
            if let state4MinThreshold = stateTriggers["state4"]?.0, value > state4MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MaxThreshold = stateTriggers["state2"]?.1, trendMean < -1.0 && value < state2MaxThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_UP:
            if let state2MaxThreshold = stateTriggers["state2"]?.1, trendMean < -1.0 && value < state2MaxThreshold {
                completeRep()
            }
        default:
            break
        }
    }
    
    private func updateMountainClimberState(value: Float, trendMean: Float, stateTriggers: [String: (Float, Float)]) {
        switch exerciseState.currentState {
        case ExerciseAnalyzer.STATE_START:
            if let state2MaxThreshold = stateTriggers["state2"]?.1, trendMean < -1.0 && value < state2MaxThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_DOWN
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_DOWN)
                exerciseState.repFrameBuffer.removeAll()
                if let lastMetrics = exerciseState.metricBuffer.last {
                    exerciseState.repFrameBuffer.append(lastMetrics)
                }
                exerciseState.repLogged = false
            }
        case ExerciseAnalyzer.STATE_DOWN:
            if let state3MaxThreshold = stateTriggers["state3"]?.1, value < state3MaxThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_HOLD
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_HOLD)
            } else if let state4MaxThreshold = stateTriggers["state4"]?.1, value < state4MaxThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_HOLD:
            if let state4MaxThreshold = stateTriggers["state4"]?.1, value < state4MaxThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_UP:
            if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        default:
            break
        }
    }
    
    private func updateBicycleCrunchState(value: Float, trendMean: Float, secondaryMetric: Float?, stateTriggers: [String: (Float, Float)]) {
        switch exerciseState.currentState {
        case ExerciseAnalyzer.STATE_START:
            if let state2MaxThreshold = stateTriggers["state2"]?.1, trendMean < -1.0 && value < state2MaxThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_DOWN
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_DOWN)
                exerciseState.repFrameBuffer.removeAll()
                if let lastMetrics = exerciseState.metricBuffer.last {
                    exerciseState.repFrameBuffer.append(lastMetrics)
                }
                exerciseState.repLogged = false
            }
        case ExerciseAnalyzer.STATE_DOWN:
            if let state3MaxThreshold = stateTriggers["state3"]?.1, value < state3MaxThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_HOLD
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_HOLD)
            } else if let state4MinThreshold = stateTriggers["state4"]?.0, 
                      secondaryMetric != nil && secondaryMetric! > state4MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_HOLD:
            if let state4MinThreshold = stateTriggers["state4"]?.0, 
               secondaryMetric != nil && secondaryMetric! > state4MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_UP:
            if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        default:
            break
        }
    }
    
    private func updateBirdDogState(value: Float, trendMean: Float, secondaryMetric: Float?, stateTriggers: [String: (Float, Float)]) {
        switch exerciseState.currentState {
        case ExerciseAnalyzer.STATE_START:
            if let state2MaxThreshold = stateTriggers["state2"]?.1, trendMean < -1.0 && value < state2MaxThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_DOWN
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_DOWN)
                exerciseState.repFrameBuffer.removeAll()
                if let lastMetrics = exerciseState.metricBuffer.last {
                    exerciseState.repFrameBuffer.append(lastMetrics)
                }
                exerciseState.repLogged = false
            }
        case ExerciseAnalyzer.STATE_DOWN:
            if let state3MinThreshold = stateTriggers["state3"]?.0, value > state3MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_HOLD
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_HOLD)
            } else if let state4MinThreshold = stateTriggers["state4"]?.0, 
                      secondaryMetric != nil && secondaryMetric! > state4MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_HOLD:
            if let state4MinThreshold = stateTriggers["state4"]?.0, 
               secondaryMetric != nil && secondaryMetric! > state4MinThreshold {
                exerciseState.currentState = ExerciseAnalyzer.STATE_UP
                exerciseState.maxState = max(exerciseState.maxState, ExerciseAnalyzer.STATE_UP)
            } else if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        case ExerciseAnalyzer.STATE_UP:
            if let state2MinThreshold = stateTriggers["state2"]?.0, trendMean > 1.0 && value > state2MinThreshold {
                completeRep()
            }
        default:
            break
        }
    }
    
    private func completeRep() {
        exerciseState.repCount += 1
        
        if !exerciseState.repLogged {
            let isCorrect = analyzeRepCorrectness()
            
            if isCorrect && exerciseState.maxState >= ExerciseAnalyzer.STATE_HOLD {
                exerciseState.correctReps += 1
            }
            
            exerciseState.repLogged = true
            exerciseState.repFrameBuffer.removeAll()
            exerciseState.maxState = ExerciseAnalyzer.STATE_START
        }
        
        exerciseState.currentState = ExerciseAnalyzer.STATE_START
        exerciseState.maxState = ExerciseAnalyzer.STATE_START
    }
    
    private func handleStaticExercise(_ metrics: [String: Float]) -> ExerciseFeedback {
        let thresholds = getCurrentThresholds()
        if thresholds.isEmpty {
            return ExerciseFeedback(isCorrect: false, message: "No thresholds available for this exercise", repCount: exerciseState.repCount, correctReps: exerciseState.correctReps)
        }
        
        let isCorrect = analyzeRepCorrectness()
        
        if exerciseState.repCount == 0 {
            exerciseState.repCount = 1
            if isCorrect {
                exerciseState.correctReps = 1
            }
        }
        
        let message = isCorrect ? "Good form! Hold steady" : "Adjust your form"
        return ExerciseFeedback(isCorrect: isCorrect, message: message, repCount: exerciseState.repCount, correctReps: exerciseState.correctReps)
    }
    
    private func analyzeRepCorrectness() -> Bool {
        if exerciseState.repFrameBuffer.isEmpty { return false }
        
        let thresholds = getCurrentThresholds()
        if thresholds.isEmpty { return false }
        
        var isCorrect = true
        
        // Analyze all frames in the rep buffer
        for metrics in exerciseState.repFrameBuffer {
            for (key, thresholdValue) in thresholds {
                let metricValue = metrics[key] ?? 0.0
                if metricValue == 0.0 { continue }
                
                if key.hasSuffix("_min") {
                    if metricValue < thresholdValue {
                        isCorrect = false
                    }
                } else if key.hasSuffix("_max") {
                    if metricValue > thresholdValue {
                        isCorrect = false
                    }
                }
            }
        }
        
        // Additional checks
        if exerciseState.maxState < ExerciseAnalyzer.STATE_HOLD {
            isCorrect = false
        }
        
        return isCorrect
    }
    
    private func calculateAngle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Float {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
        
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let det = v1.dx * v2.dy - v1.dy * v2.dx
        
        let angle = atan2(det, dot)
        return Float(abs(angle * 180 / .pi))
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func getCurrentThresholds() -> [String: Float] {
        guard let exerciseData = exerciseThresholds?[currentExercise],
              let difficultyData = exerciseData[currentDifficulty],
              let firstThreshold = difficultyData.first else {
            print("No thresholds found for \(currentExercise) (\(currentDifficulty))")
            return [:]
        }
        return firstThreshold
    }
    
    func getExerciseState() -> ExerciseState {
        return exerciseState
    }
    
    func resetExercise() {
        exerciseState = ExerciseState()
    }
    
    func getAvailableExercises() -> [String] {
        guard let keys = exerciseThresholds?.keys else { return [] }
        return Array(keys)
    }
    
    func getAvailableDifficulties() -> [String] {
        return [ExerciseAnalyzer.DIFFICULTY_EASY, ExerciseAnalyzer.DIFFICULTY_MEDIUM, ExerciseAnalyzer.DIFFICULTY_HARD]
    }
}
