// AdditionalRemarksParser.swift
// ARINC633Kit
//
// SAX parser for SUPP XML files with AdditionalRemarks root element.
// Extracts crew qualifications, CDU preflight, redispatch, permits, CAT approaches.

import Foundation

/// SAX parser for AdditionalRemarks root element (SUPP XML files).
///
/// SUPP XMLs contain `<AdditionalRemarkDetails>` with `<Remark>` elements
/// that use `RemarkType` and `Title` attributes to identify section content.
/// Text content is free-form plain text parsed into structured models.
final class AdditionalRemarksParser: SAXParserEngine, @unchecked Sendable {

    // MARK: - Parsed Result

    private var result = AdditionalRemarks()

    // MARK: - Builder State

    private var inAdditionalRemarkDetails = false
    private var inRemark = false
    private var currentRemarkType = ""
    private var currentTitle = ""
    private var remarkTextBuffer = ""

    // MARK: - Public API

    func parse(data: Data) throws -> AdditionalRemarks {
        result = AdditionalRemarks()
        try run(data: data)
        return result
    }

    // MARK: - SAXParserEngine Overrides

    override func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "AdditionalRemarkDetails":
            inAdditionalRemarkDetails = true

        case "Remark" where inAdditionalRemarkDetails:
            inRemark = true
            currentRemarkType = attributes["RemarkType"] ?? ""
            currentTitle = attributes["Title"] ?? ""
            remarkTextBuffer = ""

        default:
            break
        }
    }

    override func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case "Remark" where inRemark:
            let rawText = remarkTextBuffer.isEmpty ? characterBuffer : remarkTextBuffer
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Always store raw remark
            result.rawRemarks.append(AdditionalRemark(
                remarkType: currentRemarkType,
                title: currentTitle,
                text: trimmed
            ))

            // Dispatch to typed parsers based on Title
            switch currentTitle {
            case "RELEASE REMARKS":
                if !trimmed.isEmpty {
                    result.releaseRemarks = trimmed
                }

            case "CREW QUALIFICATIONS":
                result.crewQualifications = parseCrewQualifications(trimmed)

            case "Fuel notes":
                if !trimmed.isEmpty {
                    result.fuelNotes = trimmed
                }

            case "Redispatch Info" where currentRemarkType == "FW":
                if !trimmed.isEmpty {
                    result.fwRedispatchInfo = trimmed
                }

            case "Takeoff Alternate":
                if !trimmed.isEmpty {
                    result.takeoffAlternate = trimmed
                }

            case "CDU Preflight":
                result.cduPreflight = parseCDUPreflight(trimmed)

            case "REDISPATCH INFO" where currentRemarkType == "EXTRAINFO":
                result.redispatchInfo = parseRedispatchInfo(trimmed)

            case "ETOPS INFO":
                if !trimmed.isEmpty {
                    result.etopsInfo = trimmed
                    result.etopsInfoParsed = parseETOPSInfo(trimmed)
                }

            case "OVERFLIGHT/LANDING PERMITS":
                parsePermits(trimmed)

            case "CAT II/III APPROACHES":
                result.catApproaches = parseCATApproaches(trimmed)

            default:
                break
            }

            inRemark = false
            currentRemarkType = ""
            currentTitle = ""
            remarkTextBuffer = ""

        case "AdditionalRemarkDetails":
            inAdditionalRemarkDetails = false

        default:
            break
        }
    }

    // Override characters to accumulate across fragmented callbacks for Remark content
    public override func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inRemark {
            remarkTextBuffer += string
        }
        super.parser(parser, foundCharacters: string)
    }

    // MARK: - Crew Qualifications Parser

    private func parseCrewQualifications(_ text: String) -> [CrewQualification] {
        guard !text.isEmpty else { return [] }
        var qualifications: [CrewQualification] = []
        var current: CrewQualification?

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check if line starts with a rank (CA or FO)
            if trimmed.hasPrefix("CA ") || trimmed.hasPrefix("FO ") {
                // Save previous crew member
                if let prev = current {
                    qualifications.append(prev)
                }

                // Parse: "CA 601886     RAHN K" or "FO 454521   * BAKER J"
                let rank = String(trimmed.prefix(2))
                var rest = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)

                // Split into employeeId and name
                // Format: "601886     RAHN K" or "454521   * BAKER J"
                let parts = rest.split(maxSplits: 1, whereSeparator: { $0 == " " })
                if parts.count >= 1 {
                    let employeeId = String(parts[0]).replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
                    var name = ""
                    if parts.count >= 2 {
                        rest = String(parts[1]).trimmingCharacters(in: .whitespaces)
                        // Remove leading * if present
                        if rest.hasPrefix("*") {
                            rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
                        }
                        name = rest.trimmingCharacters(in: .whitespaces)
                    }
                    current = CrewQualification(rank: rank, employeeId: employeeId, name: name)
                }
            } else if let _ = current {
                // Parse currency lines: "LAST TO:   2026-02-10        LAST LNDG:   2026-02-11"
                if trimmed.contains("LAST TO:") {
                    if let toMatch = extractValue(from: trimmed, key: "LAST TO:") {
                        current?.lastTakeoff = toMatch
                    }
                    if let lndgMatch = extractValue(from: trimmed, key: "LAST LNDG:") {
                        current?.lastLanding = lndgMatch
                    }
                }
                if trimmed.contains("TO EXPIRY:") {
                    if let toExp = extractValue(from: trimmed, key: "TO EXPIRY:") {
                        current?.takeoffExpiry = toExp
                    }
                    if let lndgExp = extractValue(from: trimmed, key: "LNDG EXPIRY:") {
                        current?.landingExpiry = lndgExp
                    }
                }
            }
        }

        // Append last crew member
        if let last = current {
            qualifications.append(last)
        }

        return qualifications
    }

    /// Extract a value following a key in a line (e.g., "LAST TO:   2026-02-10").
    private func extractValue(from line: String, key: String) -> String? {
        guard let range = line.range(of: key) else { return nil }
        let after = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        // Take the first non-whitespace token
        let token = after.split(separator: " ").first.map(String.init)
        return token?.isEmpty == true ? nil : token
    }

    // MARK: - CDU Preflight Parser

    private func parseCDUPreflight(_ text: String) -> CDUPreflight? {
        guard !text.isEmpty else { return nil }
        var cdu = CDUPreflight()
        var routeLines: [String] = []
        var inRoute = false

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("MODEL:") {
                inRoute = false
                cdu.model = extractCDUValue(trimmed, key: "MODEL:")
            } else if trimmed.hasPrefix("ENGINES:") {
                inRoute = false
                cdu.engines = extractCDUValue(trimmed, key: "ENGINES:")
            } else if trimmed.hasPrefix("FF:") {
                inRoute = false
                cdu.fuelFactor = extractCDUValue(trimmed, key: "FF:")
            } else if trimmed.hasPrefix("CO ROUTE/UPLINK:") {
                inRoute = false
                cdu.coRouteUplink = extractCDUValue(trimmed, key: "CO ROUTE/UPLINK:")
            } else if trimmed.hasPrefix("FLT NO:") {
                inRoute = false
                cdu.flightNumber = extractCDUValue(trimmed, key: "FLT NO:")
                // Next lines without a key prefix are route continuation
                inRoute = true
            } else if trimmed.hasPrefix("GDIS:") {
                inRoute = false
                cdu.gdis = extractCDUValue(trimmed, key: "GDIS:")
            } else if trimmed.hasPrefix("FMC RESERVES:") {
                inRoute = false
                cdu.fmcReserves = extractCDUValue(trimmed, key: "FMC RESERVES:")
            } else if trimmed.hasPrefix("CRUISE ALTITUDE:") {
                inRoute = false
                cdu.cruiseAltitude = extractCDUValue(trimmed, key: "CRUISE ALTITUDE:")
            } else if trimmed.hasPrefix("COST INDEX") {
                inRoute = false
                // "COST INDEX 027" (no colon)
                let value = String(trimmed.dropFirst("COST INDEX".count)).trimmingCharacters(in: .whitespaces)
                cdu.costIndex = value.isEmpty ? nil : value
            } else if trimmed.hasPrefix("WIND:") {
                inRoute = false
                cdu.wind = extractCDUValue(trimmed, key: "WIND:")
            } else if trimmed.hasPrefix("ISA/OAT:") {
                inRoute = false
                cdu.isaOat = extractCDUValue(trimmed, key: "ISA/OAT:")
            } else if inRoute && !trimmed.hasPrefix("ACARS") {
                // Route continuation line (no key prefix)
                routeLines.append(trimmed)
            }
        }

        // Build route from flight number line + continuation lines
        if !routeLines.isEmpty {
            // Check if first route line was already captured in FLT NO processing
            cdu.route = routeLines.joined(separator: " ")
        }

        return cdu
    }

    private func extractCDUValue(_ line: String, key: String) -> String? {
        let value = String(line.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    // MARK: - Redispatch Info Parser

    private func parseRedispatchInfo(_ text: String) -> RedispatchInfo? {
        guard !text.isEmpty else { return nil }
        var info = RedispatchInfo()

        let lines = text.components(separatedBy: "\n")
        var currentAirportDetail: RedispatchAirportDetail?
        var currentAirportType: String = "" // "initial" or "alternate"
        var routeLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("REDISPATCH:") {
                // Parse header: "REDISPATCH: RJAA/NRT  ETA 0306Z   DP(POR: BEGSA/06.36)   PLAN LDGW RJAA 229709"
                let rest = String(trimmed.dropFirst("REDISPATCH:".count)).trimmingCharacters(in: .whitespaces)
                let parts = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

                if let icaoIata = parts.first {
                    let codes = icaoIata.split(separator: "/")
                    info.airportICAO = codes.first.map(String.init)
                    info.airport = codes.count > 1 ? String(codes[1]) : nil
                }

                if let etaIdx = parts.firstIndex(of: "ETA"), etaIdx + 1 < parts.count {
                    info.eta = parts[etaIdx + 1]
                }

                // Extract DP
                if let dpStart = rest.range(of: "DP(") {
                    let afterDP = rest[dpStart.upperBound...]
                    if let closeIdx = afterDP.firstIndex(of: ")") {
                        info.decisionPoint = String(afterDP[afterDP.startIndex..<closeIdx])
                    }
                }

                // Extract PLAN LDGW
                if let ldgwIdx = parts.firstIndex(of: "LDGW"), ldgwIdx + 2 < parts.count {
                    info.planLandingWeight = parts[ldgwIdx + 2]
                } else if let ldgwIdx = parts.firstIndex(of: "LDGW"), ldgwIdx + 1 < parts.count {
                    info.planLandingWeight = parts[ldgwIdx + 1]
                }

            } else if trimmed.hasPrefix("-Initial Airport") {
                // Finalize previous
                finalizeAirportDetail(&info, detail: currentAirportDetail, type: currentAirportType, routeLines: routeLines)
                routeLines = []

                currentAirportType = "initial"
                currentAirportDetail = parseAirportDetailLine(trimmed)

            } else if trimmed.hasPrefix("-Initial Alternate") {
                // Finalize previous
                finalizeAirportDetail(&info, detail: currentAirportDetail, type: currentAirportType, routeLines: routeLines)
                routeLines = []

                currentAirportType = "alternate"
                currentAirportDetail = parseAirportDetailLine(trimmed)

            } else if currentAirportDetail != nil {
                // Route line
                routeLines.append(trimmed)
            }
        }

        // Finalize last
        finalizeAirportDetail(&info, detail: currentAirportDetail, type: currentAirportType, routeLines: routeLines)

        return info
    }

    private func parseAirportDetailLine(_ line: String) -> RedispatchAirportDetail {
        // "-Initial Airport (RJAA)   FUEL 002127  TIME 00.39  DIST 0257  MORA 5700"
        var detail = RedispatchAirportDetail()

        // Extract ICAO from parentheses
        if let openParen = line.firstIndex(of: "("),
           let closeParen = line.firstIndex(of: ")") {
            let icao = String(line[line.index(after: openParen)..<closeParen])
            detail.airportICAO = icao
        }

        // Extract FUEL, TIME, DIST, MORA values
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if let fuelIdx = parts.firstIndex(of: "FUEL"), fuelIdx + 1 < parts.count {
            detail.fuel = Int(parts[fuelIdx + 1])
        }
        if let timeIdx = parts.firstIndex(of: "TIME"), timeIdx + 1 < parts.count {
            detail.time = parts[timeIdx + 1]
        }
        if let distIdx = parts.firstIndex(of: "DIST"), distIdx + 1 < parts.count {
            detail.distance = Int(parts[distIdx + 1])
        }
        if let moraIdx = parts.firstIndex(of: "MORA"), moraIdx + 1 < parts.count {
            detail.mora = Int(parts[moraIdx + 1])
        }

        return detail
    }

    private func finalizeAirportDetail(_ info: inout RedispatchInfo, detail: RedispatchAirportDetail?, type: String, routeLines: [String]) {
        guard var detail = detail else { return }
        if !routeLines.isEmpty {
            detail.route = routeLines.joined(separator: " ")
        }
        if type == "initial" {
            info.initialAirport = detail
        } else if type == "alternate" {
            info.initialAlternate = detail
        }
    }

    // MARK: - Permits Parser

    private func parsePermits(_ text: String) {
        guard !text.isEmpty else { return }

        var inOverflight = false
        var inLanding = false
        var lastOverflightPermit: OverflightPermit?

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.contains("--- OVERFLIGHT PERMIT") {
                // Finalize any pending permit
                if let p = lastOverflightPermit {
                    result.overflightPermits.append(p)
                    lastOverflightPermit = nil
                }
                inOverflight = true
                inLanding = false
                continue
            }

            if trimmed.contains("--- LANDING PERMIT") {
                // Finalize any pending overflight permit
                if let p = lastOverflightPermit {
                    result.overflightPermits.append(p)
                    lastOverflightPermit = nil
                }
                inOverflight = false
                inLanding = true
                continue
            }

            if trimmed.hasPrefix("VALID FOR:") {
                let validFor = String(trimmed.dropFirst("VALID FOR:".count)).trimmingCharacters(in: .whitespaces)
                lastOverflightPermit?.validFor = validFor
                continue
            }

            if inOverflight {
                // "EGYPT                 ZAS 4044"
                // Split into country and permit number at large whitespace gap
                let permit = parsePermitLine(trimmed)
                if let p = lastOverflightPermit {
                    result.overflightPermits.append(p)
                }
                lastOverflightPermit = OverflightPermit(country: permit.0, permitNumber: permit.1)
            } else if inLanding {
                let permit = parsePermitLine(trimmed)
                result.landingPermits.append(LandingPermit(country: permit.0, permitNumber: permit.1))
            }
        }

        // Finalize last overflight permit
        if let p = lastOverflightPermit {
            result.overflightPermits.append(p)
        }
    }

    private func parsePermitLine(_ line: String) -> (String, String) {
        // Split at 2+ spaces to separate country from permit number
        let parts = line.components(separatedBy: "  ").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if parts.count >= 2 {
            let country = parts[0].trimmingCharacters(in: .whitespaces)
            let permitNumber = parts[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return (country, permitNumber)
        }
        return (line, "")
    }

    // MARK: - ETOPS INFO Parser

    /// Parse the ETOPS INFO free-form text into structured data.
    ///
    /// Expected format:
    /// ```
    /// Critical Fuel Scenario                               ETOPS  60/180
    /// DEPRESS - B777F KG
    /// (GORJSS) ETP1  PACD-RJSS  N51 25.9  E163 16.0
    ///          MORA  TRK   DIST  TIME   REMF   PAD    MINF   WX WINDOW
    /// PACD     046   71    1228  04:19  40332  9120   31212  2143Z-0441Z
    /// RJSS     026   244   1234  04:19  40332  8385   31948  0124Z-0441Z
    /// RMK MINF INCL APU / 5.0 Percent Total WIND / E+A ICE 3.0 Percent Total
    ///
    /// Last Adequate:  PACD
    /// First Adequate: RJSS
    /// ```
    private func parseETOPSInfo(_ text: String) -> ETOPSInfoParsed? {
        guard !text.isEmpty else { return nil }
        var info = ETOPSInfoParsed()

        let lines = text.components(separatedBy: "\n")
        var headersParsed = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Line 1: "Critical Fuel Scenario                               ETOPS  60/180"
            if trimmed.contains("ETOPS") && trimmed.contains("Critical Fuel") {
                // Extract ETOPS type after "ETOPS"
                if let etopsRange = trimmed.range(of: "ETOPS") {
                    let afterETOPS = String(trimmed[etopsRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !afterETOPS.isEmpty {
                        info.etopsType = afterETOPS
                    }
                }
                continue
            }

            // Line 2: "DEPRESS - B777F KG"
            if !headersParsed && info.etopsType != nil && info.scenario == nil && trimmed.contains(" - ") {
                let parts = trimmed.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 {
                    info.scenario = parts[0]
                    // "B777F KG" -> split
                    let rest = parts[1].split(separator: " ")
                    if let ac = rest.first {
                        info.aircraftType = String(ac)
                    }
                    if rest.count > 1 {
                        info.unit = String(rest.last!)
                    }
                }
                continue
            }

            // Line 3: "(GORJSS) ETP1  PACD-RJSS  N51 25.9  E163 16.0"
            if trimmed.contains("ETP") && (trimmed.contains("(") || trimmed.hasPrefix("ETP")) {
                // Extract ETP name
                let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
                for (i, token) in tokens.enumerated() {
                    if token.hasPrefix("ETP") {
                        info.etpName = token
                        // Next token should be airports
                        if i + 1 < tokens.count && tokens[i + 1].contains("-") {
                            info.etpAirports = tokens[i + 1]
                        }
                        break
                    }
                }

                // Extract coordinates: look for N/S followed by number, then E/W followed by number
                let coordPattern = trimmed
                if let nRange = coordPattern.range(of: #"[NS]\d"#, options: .regularExpression) {
                    let rest = String(coordPattern[nRange.lowerBound...])
                    let coordTokens = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
                    // N51 25.9  E163 16.0
                    if coordTokens.count >= 4 {
                        info.latitude = "\(coordTokens[0]) \(coordTokens[1])"
                        info.longitude = "\(coordTokens[2]) \(coordTokens[3])"
                    }
                }
                headersParsed = true
                continue
            }

            // Skip column header line
            if trimmed.hasPrefix("MORA") || (trimmed.contains("MORA") && trimmed.contains("TRK") && trimmed.contains("DIST")) {
                continue
            }

            // Airport data rows: "PACD     046   71    1228  04:19  40332  9120   31212  2143Z-0441Z"
            if headersParsed && !trimmed.hasPrefix("RMK") &&
               !trimmed.hasPrefix("Last") && !trimmed.hasPrefix("First") {
                let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
                // First token is ICAO (4 letters), rest are values
                if tokens.count >= 2, tokens[0].count <= 5, tokens[0].allSatisfy({ $0.isLetter || $0.isNumber }) {
                    var row = ETOPSInfoAirportRow(icao: tokens[0])
                    if tokens.count > 1 { row.mora = Int(tokens[1]) }
                    if tokens.count > 2 { row.track = Int(tokens[2]) }
                    if tokens.count > 3 { row.distance = Int(tokens[3]) }
                    if tokens.count > 4 { row.time = tokens[4] }
                    if tokens.count > 5 { row.remainingFuel = Int(tokens[5]) }
                    if tokens.count > 6 { row.pad = Int(tokens[6]) }
                    if tokens.count > 7 { row.minimumFuel = Int(tokens[7]) }
                    if tokens.count > 8 { row.wxWindow = tokens[8] }
                    info.airportRows.append(row)
                }
                continue
            }

            // RMK line
            if trimmed.hasPrefix("RMK") {
                info.remarks = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }

            // Last/First Adequate
            if trimmed.hasPrefix("Last Adequate:") {
                info.lastAdequate = String(trimmed.dropFirst("Last Adequate:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if trimmed.hasPrefix("First Adequate:") {
                info.firstAdequate = String(trimmed.dropFirst("First Adequate:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }
        }

        return info.airportRows.isEmpty ? nil : info
    }

    // MARK: - CAT Approaches Parser

    private func parseCATApproaches(_ text: String) -> [CATApproach] {
        guard !text.isEmpty else { return [] }
        var approaches: [CATApproach] = []

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip header line
            if trimmed.contains("AUTHORIZED CAT") || trimmed.contains("OPSPEC") {
                continue
            }

            // Pattern: "RJAA CAT II/III  - RWY 16R" or "VGHS CAT II      - RWY 14"
            // Extract ICAO (first 4 chars), then CAT category, then runways after "RWY"
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 3 else { continue }

            let icao = parts[0]

            // Find "CAT" and build category string until "-"
            guard let catIdx = parts.firstIndex(of: "CAT"), catIdx + 1 < parts.count else { continue }

            var categoryParts: [String] = ["CAT"]
            var dashIdx = catIdx + 1
            while dashIdx < parts.count && parts[dashIdx] != "-" {
                categoryParts.append(parts[dashIdx])
                dashIdx += 1
            }
            let category = categoryParts.joined(separator: " ")

            // Find "RWY" and take everything after
            if let rwyIdx = parts.firstIndex(of: "RWY"), rwyIdx + 1 < parts.count {
                let runways = parts[(rwyIdx + 1)...].joined(separator: " ")
                approaches.append(CATApproach(airportICAO: icao, category: category, runways: runways))
            }
        }

        return approaches
    }
}
