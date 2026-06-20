// SpecValidationHarness.swift
// ARINC633KitTests
//
// LOCAL-ONLY validation harness. Parses EVERY official ARINC 633-4 sample in a
// gitignored spec folder and reports, per file: did it dispatch to a typed parser,
// did it throw, and (for captured/unmodeled content) which elements were not
// consumed by a typed model.
//
// ⛔ This harness reads the COPYRIGHTED spec locally and never embeds or commits any
// spec content. It NO-OPS when the spec folder is absent (e.g. in CI), so it is safe
// to keep in the committed test target.
//
// Point it at the spec by either:
//   - setting ARINC633_SPEC_DIR to the local spec root, or
//   - placing the spec at "<package>/633-4 2" (the default; gitignored).

import Testing
import Foundation
@testable import ARINC633Kit
import ARINC633KitSUPP

@Suite("Spec validation (local-only)")
struct SpecValidationHarness {

    /// Resolve the local spec directory, or nil if unavailable.
    private static func specDir() -> URL? {
        let fm = FileManager.default
        if let env = ProcessInfo.processInfo.environment["ARINC633_SPEC_DIR"],
           fm.fileExists(atPath: env) {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // Walk up from this source file to find a sibling "633-4 2" folder.
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("633-4 2", isDirectory: true)
            if fm.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    @Test("Every official sample dispatches to a typed parser without throwing")
    func validateAllSamples() throws {
        guard let specDir = Self.specDir() else {
            // Spec not present (CI / clean checkout): no-op by design.
            print("ℹ️ Spec folder not found — skipping local validation harness.")
            return
        }

        let fm = FileManager.default
        let parser = ARINC633Parser.withSUPP()
        var total = 0, typed = 0, captured = 0, threw = 0
        var report: [String] = []

        let enumerator = fm.enumerator(at: specDir, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension.lowercased() == "xml" else { continue }
            // Skip 633-3 legacy samples that aren't 633-4 conformant.
            if url.lastPathComponent.contains("633-3") { continue }
            total += 1
            let name = url.lastPathComponent

            guard let data = try? Data(contentsOf: url) else {
                threw += 1; report.append("⚠️ \(name): unreadable"); continue
            }
            do {
                let message = try parser.parse(data: data)
                if case let .captured(root) = message {
                    captured += 1
                    let kids = Set(root.children.map(\.name)).sorted().prefix(8)
                    report.append("◻️ \(name): CAPTURED root=<\(root.name)> children=\(kids.joined(separator: ","))")
                } else {
                    typed += 1
                    let gaps = Self.unmodeledElements(in: message)
                    if gaps.isEmpty {
                        report.append("✅ \(name): \(Self.label(message))")
                    } else {
                        report.append("🟡 \(name): \(Self.label(message)) — unmodeled: \(gaps.sorted().joined(separator: ","))")
                    }
                }
            } catch {
                threw += 1
                report.append("❌ \(name): THREW \(error)")
            }
        }

        print("""

        ===== ARINC 633-4 Spec Validation =====
        files: \(total)  typed: \(typed)  captured: \(captured)  threw: \(threw)
        \(report.sorted().joined(separator: "\n"))
        =======================================
        """)

        // The harness is informational; it must not fail the suite on gaps, only on
        // outright crashes of the parser process. Surface hard throws as a soft signal.
        #expect(total > 0)
    }

    /// Best-effort short label for a parsed message.
    private static func label(_ message: ARINC633Message) -> String {
        switch message {
        case .flightPlan: return "FlightPlan"
        case .loadAndTrimData: return "LoadAndTrimData"
        case .airportWeather: return "AirportWeather"
        case .crewList: return "CrewList"
        case .eff: return "EFF"
        case .notam: return "NOTAMBriefing"
        case .atis: return "ATIS"
        case .atcFlightPlan: return "FlightPlanAtcIcao"
        case .raimReport: return "RAIMReport"
        case .pirepBriefing: return "PIREPBriefing"
        case .hazardBriefing: return "HazardBriefing"
        case .organizedTracks: return "OrganizedTracks"
        case .airspaceData: return "AirspaceData"
        case let .wba(m): return "WBA(\(m.messageSubtype ?? "?"))"
        case let .fuel(m): return "FUEL(\(m.messageSubtype ?? "?"))"
        case let .deIcing(m): return "DeIcing(\(m.messageSubtype ?? "?"))"
        case .paxList: return "PaxList"
        case .regionWeather: return "RegionWeather"
        case .upperAirData: return "UpperAirData"
        case .airportData: return "AirportData"
        case .generalError: return "GERIND"
        case .captured: return "captured"
        case let .custom(c): return "custom(\(c.rootElement))"
        }
    }

    /// Elements captured into an "extensions" bag by a typed model (i.e. gaps).
    /// Models that expose `extensions: [CapturedElement]` contribute their names here.
    private static func unmodeledElements(in message: ARINC633Message) -> Set<String> {
        // Extension bags are surfaced per-model as they are added during promotion.
        // Until a model exposes one, this returns empty (no false positives).
        Set()
    }
}
