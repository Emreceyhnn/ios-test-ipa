import Foundation
import UIKit
import Vision

// MARK: - Extracted OKOK Body Composition Data Model
struct OKOKScanResult: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    
    // Core Metrics Extracted from OKOK Share Screenshot
    var weightKg: Double = 0.0               // Örn: 91.95
    var bmi: Double? = nil                   // Örn: 26.3
    var bodyFatPercent: Double? = nil        // Örn: 24.4 %
    var bodyFatWeightKg: Double? = nil       // Örn: 22.4 kg
    var skeletalMusclePercent: Double? = nil // Örn: 40.8 %
    var skeletalMuscleWeightKg: Double? = nil// Örn: 37.5 kg
    var musclePercent: Double? = nil         // Örn: 72.4 %
    var muscleWeightKg: Double? = nil        // Örn: 66.5 kg
    var waterPercent: Double? = nil          // Örn: 52.9 %
    var waterWeightKg: Double? = nil         // Örn: 48.7 kg
    var visceralFat: Double? = nil           // Örn: 12.0
    var bmrKcal: Double? = nil               // Örn: 2026.0 kcal
    var heightCm: Double? = nil              // Örn: 187 cm
    var age: Int? = nil                      // Örn: 23
}

// MARK: - Native Apple Vision OCR Scanner Engine
@MainActor
final class ScaleOCRScanner: ObservableObject {
    static let shared = ScaleOCRScanner()
    
    @Published var isScanning: Bool = false
    @Published var lastResult: OKOKScanResult? = nil
    @Published var scanError: String? = nil
    
    private init() {}
    
    // Process image picked from Photos or Camera
    func processScaleImage(_ image: UIImage) async -> OKOKScanResult? {
        isScanning = true
        defer { isScanning = false }
        
        guard let cgImage = image.cgImage else {
            scanError = "Görsel formatı okunamadı."
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] req, err in
                guard let observations = req.results as? [VNRecognizedTextObservation], err == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
                let parsed = self?.parseOKOKTextLines(recognizedStrings)
                
                Task { @MainActor in
                    self?.lastResult = parsed
                    if parsed != nil {
                        Haptic.success()
                    }
                    continuation.resume(returning: parsed)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    // Advanced NLP parsing for OKOK share screenshot
    private func parseOKOKTextLines(_ lines: [String]) -> OKOKScanResult {
        var result = OKOKScanResult()
        
        // Joined text for flexible regex matching
        let fullText = lines.joined(separator: "\n")
        
        // 1. Primary Weight (Prominent 91.95 or 91.95Kg)
        for line in lines {
            let clean = line.replacingOccurrences(of: " ", with: "").lowercased()
            if clean.contains("kg") {
                if let val = extractFirstDecimal(from: clean) {
                    if val >= 30.0 && val <= 250.0 {
                        result.weightKg = val
                        break
                    }
                }
            }
        }
        
        // Fallback primary weight if not found with 'kg'
        if result.weightKg == 0 {
            for line in lines {
                if let val = extractFirstDecimal(from: line), val >= 40.0 && val <= 220.0 {
                    result.weightKg = val
                    break
                }
            }
        }
        
        // 2. Body Metrics List Parser
        for (idx, line) in lines.enumerated() {
            let lower = line.lowercased()
            
            // BMI
            if lower.contains("bmi") {
                result.bmi = findNextNumber(in: lines, fromIndex: idx)
            }
            // Fat(%)
            else if lower.contains("fat(%)") || (lower.contains("fat") && lower.contains("%")) {
                result.bodyFatPercent = findNextNumber(in: lines, fromIndex: idx)
            }
            // Body fat weight
            else if lower.contains("body fat weight") || lower.contains("fat weight") {
                result.bodyFatWeightKg = findNextNumber(in: lines, fromIndex: idx)
            }
            // Skeletal muscle mass percentage
            else if lower.contains("skeletal muscle mass") || lower.contains("skeletal muscle") {
                result.skeletalMusclePercent = findNextNumber(in: lines, fromIndex: idx)
            }
            // Muscle Percent
            else if lower.contains("muscle percent") {
                result.musclePercent = findNextNumber(in: lines, fromIndex: idx)
            }
            // Muscle weight
            else if lower.contains("muscle weight") {
                result.muscleWeightKg = findNextNumber(in: lines, fromIndex: idx)
            }
            // Water(%)
            else if lower.contains("water(%)") || lower.contains("water") {
                result.waterPercent = findNextNumber(in: lines, fromIndex: idx)
            }
            // Weight of water
            else if lower.contains("weight of water") {
                result.waterWeightKg = findNextNumber(in: lines, fromIndex: idx)
            }
            // V-fat (Visceral fat)
            else if lower.contains("v-fat") || lower.contains("visceral") {
                result.visceralFat = findNextNumber(in: lines, fromIndex: idx)
            }
            // Metabolism
            else if lower.contains("metabolism") || lower.contains("kcal") {
                result.bmrKcal = findNextNumber(in: lines, fromIndex: idx)
            }
            // Height
            else if lower.contains("height") {
                result.heightCm = findNextNumber(in: lines, fromIndex: idx)
            }
            // Actual age
            else if lower.contains("age") || lower.contains("actual age") {
                if let ageNum = findNextNumber(in: lines, fromIndex: idx) {
                    result.age = Int(ageNum)
                }
            }
        }
        
        return result
    }
    
    private func extractFirstDecimal(from string: String) -> Double? {
        let pattern = #"([0-9]{2,3}(?:[.,][0-9]{1,2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = string as NSString
            if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let matchedStr = nsString.substring(with: match.range).replacingOccurrences(of: ",", with: ".")
                return Double(matchedStr)
            }
        }
        return nil
    }
    
    private func findNextNumber(in lines: [String], fromIndex: Int) -> Double? {
        // Look within same line or next 2 lines
        for offset in 0...2 {
            let checkIdx = fromIndex + offset
            guard checkIdx < lines.count else { break }
            let text = lines[checkIdx]
            let numbers = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted)
                .filter { !$0.isEmpty }
            
            for numStr in numbers {
                let clean = numStr.replacingOccurrences(of: ",", with: ".")
                if let val = Double(clean), val > 0 {
                    return val
                }
            }
        }
        return nil
    }
}
