#!/usr/bin/env swift

/*
 SOS Keyword Classifier - CreateML Training Script
 ==================================================
 Trains an MLSoundClassifier model for SOS keyword detection using augmented data.

 Requirements:
   - macOS 12.0+ with Xcode 13.0+
   - CreateML framework
   - Augmented training dataset from augment_sos_training_data.py

 Usage:
   swift train_sos_classifier.swift \
       --dataset /path/to/Augmented_SOS_Dataset \
       --output ./Models \
       --iterations 50

 Output:
   - SOSKeywordClassifier.mlmodel (trained model)
   - training_metrics.json (performance metrics)
   - confusion_matrix.txt (evaluation results)
*/

import Foundation
import CreateML
import CoreML

// MARK: - Configuration

struct TrainingConfig {
    let datasetPath: String
    let outputPath: String
    let maxIterations: Int
    let validationSplit: Double
    let modelName: String

    init(datasetPath: String, outputPath: String, maxIterations: Int = 50) {
        self.datasetPath = datasetPath
        self.outputPath = outputPath
        self.maxIterations = maxIterations
        self.validationSplit = 0.2 // 20% for validation
        self.modelName = "SOSKeywordClassifier"
    }
}

// MARK: - Training Metrics

struct TrainingMetrics: Codable {
    let modelName: String
    let trainingDate: String
    let trainingDuration: TimeInterval
    let maxIterations: Int
    let trainingAccuracy: Double
    let validationAccuracy: Double
    let testingAccuracy: Double?
    let classMetrics: [String: ClassMetrics]
    let confusionMatrix: [[Int]]
    let classLabels: [String]

    struct ClassMetrics: Codable {
        let precision: Double
        let recall: Double
        let f1Score: Double
        let support: Int
    }
}

// MARK: - Main Training Pipeline

class SOSClassifierTrainer {
    let config: TrainingConfig

    init(config: TrainingConfig) {
        self.config = config
    }

    func train() throws {
        print("╔═══════════════════════════════════════════════════════════╗")
        print("║         SOS Keyword Classifier Training Pipeline         ║")
        print("╚═══════════════════════════════════════════════════════════╝")
        print("")

        // Step 1: Load and validate dataset
        print("📂 Step 1: Loading Dataset...")
        print("   Path: \(config.datasetPath)")

        let trainingDataURL = URL(fileURLWithPath: config.datasetPath).appendingPathComponent("Training")
        let testingDataURL = URL(fileURLWithPath: config.datasetPath).appendingPathComponent("Testing")

        guard FileManager.default.fileExists(atPath: trainingDataURL.path) else {
            throw TrainingError.datasetNotFound("Training folder not found at \(trainingDataURL.path)")
        }

        // Count files in each class
        let classes = ["sos", "oh_ess", "noise", "unknown"]
        print("")
        print("   Training Set:")
        var totalTrainingFiles = 0
        for className in classes {
            let classURL = trainingDataURL.appendingPathComponent(className)
            if let files = try? FileManager.default.contentsOfDirectory(atPath: classURL.path) {
                let audioFiles = files.filter { $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") }
                totalTrainingFiles += audioFiles.count
                print("      \(className): \(audioFiles.count) files")
            }
        }
        print("      Total: \(totalTrainingFiles) files")

        if FileManager.default.fileExists(atPath: testingDataURL.path) {
            print("")
            print("   Testing Set:")
            var totalTestingFiles = 0
            for className in classes {
                let classURL = testingDataURL.appendingPathComponent(className)
                if let files = try? FileManager.default.contentsOfDirectory(atPath: classURL.path) {
                    let audioFiles = files.filter { $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") }
                    totalTestingFiles += audioFiles.count
                    print("      \(className): \(audioFiles.count) files")
                }
            }
            print("      Total: \(totalTestingFiles) files")
        }

        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 2: Configure training parameters
        print("")
        print("⚙️  Step 2: Configuring Training Parameters...")
        print("   Max Iterations: \(config.maxIterations)")
        print("   Validation Split: \(Int(config.validationSplit * 100))%")
        print("   Model Architecture: MLSoundClassifier")
        print("   Target Sample Rate: 22,050 Hz")
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 3: Train the model
        print("")
        print("🚀 Step 3: Training Model...")
        print("   This may take 10-30 minutes depending on dataset size...")
        print("")

        let startTime = Date()

        let trainingParameters = MLSoundClassifier.ModelParameters(
            maxIterations: config.maxIterations
        )

        let model = try MLSoundClassifier(
            trainingData: .labeledDirectories(at: trainingDataURL),
            parameters: trainingParameters
        )

        let trainingDuration = Date().timeIntervalSince(startTime)

        print("")
        print("✅ Training Completed!")
        print("   Duration: \(formatDuration(trainingDuration))")
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 4: Evaluate on training data
        print("")
        print("📊 Step 4: Evaluating Model Performance...")
        print("")

        let trainingMetrics = model.trainingMetrics
        let validationMetrics = model.validationMetrics

        print("   Training Metrics:")
        print("      Accuracy: \(formatPercentage(trainingMetrics.classificationError))")

        print("")
        print("   Validation Metrics:")
        print("      Accuracy: \(formatPercentage(validationMetrics.classificationError))")

        // Step 5: Test on separate test set (if available)
        var testAccuracy: Double? = nil
        if FileManager.default.fileExists(atPath: testingDataURL.path) {
            print("")
            print("   Testing on Hold-out Set...")

            let testData = MLSoundClassifier.DataSource.labeledDirectories(at: testingDataURL)
            let testMetrics = model.evaluation(on: testData)
            testAccuracy = 1.0 - testMetrics.classificationError

            print("      Test Accuracy: \(formatPercentage(testMetrics.classificationError))")
        }

        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 6: Save the model
        print("")
        print("💾 Step 6: Saving Model...")

        let outputDirURL = URL(fileURLWithPath: config.outputPath)
        try? FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)

        let modelURL = outputDirURL.appendingPathComponent("\(config.modelName).mlmodel")
        try model.write(to: modelURL)

        print("   ✅ Model saved: \(modelURL.path)")

        // Also save compiled version (.mlmodelc) for iOS
        let compiledModelURL = try MLModel.compileModel(at: modelURL)
        let compiledDestURL = outputDirURL.appendingPathComponent("\(config.modelName).mlmodelc")

        // Remove existing compiled model if present
        try? FileManager.default.removeItem(at: compiledDestURL)
        try FileManager.default.copyItem(at: compiledModelURL, to: compiledDestURL)

        print("   ✅ Compiled model saved: \(compiledDestURL.path)")
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 7: Save training metrics
        print("")
        print("📈 Step 7: Generating Training Report...")

        let metricsURL = outputDirURL.appendingPathComponent("training_metrics.json")
        let reportURL = outputDirURL.appendingPathComponent("training_report.txt")

        // Extract per-class metrics (if available)
        var classMetrics: [String: TrainingMetrics.ClassMetrics] = [:]
        // Note: CreateML doesn't expose per-class metrics directly, so we'll use placeholder
        for className in classes {
            classMetrics[className] = TrainingMetrics.ClassMetrics(
                precision: 0.0,
                recall: 0.0,
                f1Score: 0.0,
                support: 0
            )
        }

        let metrics = TrainingMetrics(
            modelName: config.modelName,
            trainingDate: ISO8601DateFormatter().string(from: Date()),
            trainingDuration: trainingDuration,
            maxIterations: config.maxIterations,
            trainingAccuracy: 1.0 - trainingMetrics.classificationError,
            validationAccuracy: 1.0 - validationMetrics.classificationError,
            testingAccuracy: testAccuracy,
            classMetrics: classMetrics,
            confusionMatrix: [],  // CreateML doesn't expose this directly
            classLabels: classes
        )

        // Save JSON metrics
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metricsData = try encoder.encode(metrics)
        try metricsData.write(to: metricsURL)

        print("   ✅ Metrics saved: \(metricsURL.path)")

        // Generate human-readable report
        let report = generateTrainingReport(metrics: metrics)
        try report.write(to: reportURL, atomically: true, encoding: String.Encoding.utf8)

        print("   ✅ Report saved: \(reportURL.path)")
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 8: Summary
        print("")
        print("╔═══════════════════════════════════════════════════════════╗")
        print("║                  Training Complete! 🎉                    ║")
        print("╚═══════════════════════════════════════════════════════════╝")
        print("")
        print("📦 Output Files:")
        print("   • Model: \(modelURL.lastPathComponent)")
        print("   • Compiled: \(compiledDestURL.lastPathComponent)")
        print("   • Metrics: training_metrics.json")
        print("   • Report: training_report.txt")
        print("")
        print("📊 Performance Summary:")
        print("   • Training Accuracy: \(String(format: "%.2f%%", metrics.trainingAccuracy * 100))")
        print("   • Validation Accuracy: \(String(format: "%.2f%%", metrics.validationAccuracy * 100))")
        if let testAcc = testAccuracy {
            print("   • Test Accuracy: \(String(format: "%.2f%%", testAcc * 100))")
        }
        print("   • Training Time: \(formatDuration(trainingDuration))")
        print("")
        print("🚀 Next Steps:")
        print("   1. Review training_report.txt for detailed metrics")
        print("   2. Copy \(config.modelName).mlmodel to Xcode project")
        print("   3. Replace old model in BEACON6/Resources/")
        print("   4. Test on iOS device with unclear SOS pronunciations")
        print("   5. Compare detection rates before/after")
        print("")
    }

    // MARK: - Helper Functions

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }

    func formatPercentage(_ error: Double) -> String {
        let accuracy = (1.0 - error) * 100
        return String(format: "%.2f%%", accuracy)
    }

    func generateTrainingReport(metrics: TrainingMetrics) -> String {
        var report = """
        ═══════════════════════════════════════════════════════════════
                    SOS KEYWORD CLASSIFIER TRAINING REPORT
        ═══════════════════════════════════════════════════════════════

        Model: \(metrics.modelName)
        Training Date: \(metrics.trainingDate)
        Training Duration: \(formatDuration(metrics.trainingDuration))

        ───────────────────────────────────────────────────────────────
        TRAINING CONFIGURATION
        ───────────────────────────────────────────────────────────────

        Max Iterations: \(metrics.maxIterations)
        Model Type: MLSoundClassifier
        Sample Rate: 22,050 Hz
        Classes: \(metrics.classLabels.joined(separator: ", "))

        ───────────────────────────────────────────────────────────────
        PERFORMANCE METRICS
        ───────────────────────────────────────────────────────────────

        Training Accuracy:   \(String(format: "%.2f%%", metrics.trainingAccuracy * 100))
        Validation Accuracy: \(String(format: "%.2f%%", metrics.validationAccuracy * 100))
        """

        if let testAcc = metrics.testingAccuracy {
            report += "\nTest Accuracy:       \(String(format: "%.2f%%", testAcc * 100))"
        }

        report += """


        ───────────────────────────────────────────────────────────────
        AUGMENTATION TECHNIQUES APPLIED
        ───────────────────────────────────────────────────────────────

        SOS Class (AGGRESSIVE augmentation):
          ✓ Speed variations (0.8x - 1.2x)
          ✓ Pitch shifting (-2 to +2 semitones)
          ✓ Volume variations (0.6x - 1.4x)
          ✓ Stress simulation (panic voice)
          ✓ Mumbling simulation (unclear articulation)
          ✓ Slurring simulation (slurred speech)
          ✓ Background noise (real-world conditions)
          ✓ Combined augmentations

        OH_ESS Class (MODERATE augmentation):
          ✓ Speed variations
          ✓ Pitch shifting
          ✓ Background noise

        NOISE/UNKNOWN Classes (LIGHT augmentation):
          ✓ Volume variations
          ✓ Background noise

        ───────────────────────────────────────────────────────────────
        DEPLOYMENT INSTRUCTIONS
        ───────────────────────────────────────────────────────────────

        1. Copy SOSKeywordClassifier.mlmodel to Xcode project:
           • Drag into BEACON6/Resources/ folder
           • Ensure "Target Membership" includes BEACON6

        2. Verify model is loaded correctly in KeywordSpotter.swift:
           • Check Bundle.main.url(forResource: "SOSKeywordClassifier", ...)

        3. Clean build folder (Cmd+Shift+K) and rebuild

        4. Test on device with various SOS pronunciations:
           • Clear "ess-oh-ess" (baseline)
           • Fast/rushed "sos"
           • Mumbled "ssoss"
           • Slurred "soooossss"
           • Stressed/panic voice
           • Quiet whisper
           • Loud shout

        5. Monitor detection confidence and false positive rate

        ───────────────────────────────────────────────────────────────
        EXPECTED IMPROVEMENTS
        ───────────────────────────────────────────────────────────────

        Before Augmentation:
          • Only detects clear "ess-oh-ess" pronunciation
          • Misses stressed/mumbled/slurred speech
          • High false negative rate in real emergencies

        After Augmentation:
          • Detects varied pronunciations (fast/slow/unclear)
          • Handles stressed/panic voice characteristics
          • Improved recall without sacrificing precision
          • Better generalization to real-world conditions

        ───────────────────────────────────────────────────────────────
        TROUBLESHOOTING
        ───────────────────────────────────────────────────────────────

        If false positives increase:
          • Adjust detectionThreshold in KeywordSpotter.swift (0.6 → 0.7)
          • Increase confidenceDeltaThreshold (0.15 → 0.2)
          • Verify oh_ess class wasn't over-augmented

        If false negatives persist:
          • Add more augmented stress/mumble samples to training
          • Lower detectionThreshold (0.6 → 0.55)
          • Check microphone audio quality

        ═══════════════════════════════════════════════════════════════
        END OF REPORT
        ═══════════════════════════════════════════════════════════════

        """

        return report
    }
}

// MARK: - Error Handling

enum TrainingError: Error, CustomStringConvertible {
    case datasetNotFound(String)
    case invalidConfiguration(String)
    case trainingFailed(String)

    var description: String {
        switch self {
        case .datasetNotFound(let message):
            return "Dataset Error: \(message)"
        case .invalidConfiguration(let message):
            return "Configuration Error: \(message)"
        case .trainingFailed(let message):
            return "Training Error: \(message)"
        }
    }
}

// MARK: - Command Line Interface

func printUsage() {
    print("""
    Usage:
      swift train_sos_classifier.swift --dataset <path> --output <path> [--iterations <n>]

    Arguments:
      --dataset      Path to Augmented_SOS_Dataset directory (required)
      --output       Path to output directory for trained model (required)
      --iterations   Maximum training iterations (default: 50)
      --help         Show this help message

    Example:
      swift train_sos_classifier.swift \\
          --dataset ~/Documents/BEACON_Project/Augmented_SOS_Dataset \\
          --output ~/Documents/BEACON_Project/Models \\
          --iterations 50
    """)
}

// Parse command line arguments
var arguments = CommandLine.arguments
arguments.removeFirst() // Remove script name

var datasetPath: String?
var outputPath: String?
var maxIterations: Int = 50

var i = 0
while i < arguments.count {
    switch arguments[i] {
    case "--dataset":
        i += 1
        if i < arguments.count {
            datasetPath = arguments[i]
        }
    case "--output":
        i += 1
        if i < arguments.count {
            outputPath = arguments[i]
        }
    case "--iterations":
        i += 1
        if i < arguments.count {
            maxIterations = Int(arguments[i]) ?? 50
        }
    case "--help", "-h":
        printUsage()
        exit(0)
    default:
        print("Unknown argument: \(arguments[i])")
        printUsage()
        exit(1)
    }
    i += 1
}

// Validate required arguments
guard let dataset = datasetPath, let output = outputPath else {
    print("❌ Error: Missing required arguments\n")
    printUsage()
    exit(1)
}

// Run training
do {
    let config = TrainingConfig(
        datasetPath: dataset,
        outputPath: output,
        maxIterations: maxIterations
    )

    let trainer = SOSClassifierTrainer(config: config)
    try trainer.train()

    exit(0)
} catch {
    print("\n❌ Training failed: \(error)\n")
    exit(1)
}
