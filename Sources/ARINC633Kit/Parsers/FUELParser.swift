// FUELParser.swift
// ARINC633Kit
//
// Parser for the FUEL message family (16 roots in REFUELING.xsd / CGTARGETING.xsd:
// FCAIND, FDAACK, FDACOM, FDASUB, FENIND, FERIND, FORACK, FORSUB, FPRREP, FRCACK,
// FRCSUB, FSTREP, FSTREQ, FTBIND, FTEIND, FTIIND).
//
// Implemented as a tree-walk over the captured document: the envelope is extracted via
// CapturedElement helpers, `messageSubtype` is set to the root element name, and the
// shared `FUELMessage` payload is populated from whichever schema elements are present
// (each subtype carries an overlapping subset). Any top-level payload child not mapped
// to a typed field is swept into `extensions` so nothing is dropped.
//
// NOTE ON MEASUREMENTS: unlike the `<Value unit="...">N</Value>` encoding used by some
// 633 families, FUEL measurement elements use `xs:simpleContent` — the numeric value is
// the element's own text and the unit is a `unit` attribute directly on the element
// (e.g. `<TakeoffWeight unit="kg">500300</TakeoffWeight>`). The private `weight/volume/
// density` helpers below read text + `@unit` accordingly; the shared `valueAndUnit()`
// helper is NOT applicable here.

import Foundation

/// Parses any FUEL-family document into a `FUELMessage`.
public final class FUELParser: Sendable {

    public init() {}

    /// Parse FUEL XML into a typed `FUELMessage`.
    /// - Throws: `ARINC633ParseError` on malformed/empty XML.
    public func parse(data: Data) throws -> FUELMessage {
        let root = try GenericElementParser().parse(data: data)

        var message = FUELMessage(
            header: root.makeARINC633Header(),
            supplementaryHeader: root.makeSupplementaryHeader(),
            messageSubtype: root.name
        )

        // Track which payload child names we map, so the rest go to `extensions`.
        var mappedNames: Set<String> = []

        // --- Refueling order (FORSUB / FORACK) ---
        // Order-specific elements live directly under the root alongside the envelope.
        if root.name == "FORSUB" || root.name == "FORACK" {
            message.order = Self.refuelingOrder(from: root)
            mappedNames.formUnion([
                "ServiceAirport", "IntoPlaneServiceCode", "ServiceFlight",
                "OperationalLimit", "BlockFuel", "TaxiFuel", "TripFuel",
                "ArrivalFuel", "FuelTruckOnStandby"
            ])
        }

        // --- Fuel receipt (FRCSUB / FRCACK) ---
        if root.name == "FRCSUB" || root.name == "FRCACK" {
            message.receipt = Self.receipt(from: root)
            mappedNames.formUnion([
                "IntoPlaneServiceCode", "FuelSupplierCode", "FuelTruckId",
                "RefuelingDefuelingIndicator", "DefuelingIndicator",
                "FuelReceiptNumber", "FuelVolume", "FuelMass", "FuelDensity", "FuelType"
            ])
        }

        // --- Fuel process report (FPRREP) ---
        if root.name == "FPRREP" {
            message.intoPlaneServiceCode = root.first(named: "IntoPlaneServiceCode")?.text.trimmedOrNil
            message.refuelingDefuelingIndicator = Self.bool(root.first(named: "RefuelingDefuelingIndicator")?.text)
            if let st = root.first(named: "FuelProgressReportStatus") {
                message.progressReportStatus = FUELProgressReportStatus(
                    status: st.text.trimmedOrNil,
                    dateTime: st.attribute("dateTime")
                )
            }
            mappedNames.formUnion([
                "IntoPlaneServiceCode", "FuelTruckId", "FuelSupplierCode",
                "RefuelingDefuelingIndicator", "FuelProgressReportStatus"
            ])
        }

        // --- CG advisory (FCAIND) ---
        if root.name == "FCAIND" {
            message.cgAdvisory = Self.cgAdvisory(from: root)
            mappedNames.formUnion([
                "FwdTakeoffCenterOfGravityLimit", "AftTakeoffCenterOfGravityLimit",
                "CalculatedTakeoffCenterOfGravity", "TakeoffWeight", "TaxiFuel"
            ])
        }

        // --- Fuel status (FSTREP / FENIND / FTEIND / FTIIND) ---
        if let statusEl = root.first(named: "status") {
            message.status = Self.status(from: statusEl)
            mappedNames.insert("status")
        }

        // --- Fuel data (FDASUB / FDAACK / FDACOM) ---
        if let dataEl = root.first(named: "DATA") {
            message.data = Self.fuelData(from: dataEl)
            mappedNames.insert("DATA")
        }
        if let confirmEl = root.first(named: "CONFIRM") {
            message.confirm = Self.bool(confirmEl.text)
            mappedNames.insert("CONFIRM")
        }

        // --- Fuel error (FERIND) ---
        if let errorEl = root.first(named: "Error") {
            message.error = Self.error(from: errorEl)
            mappedNames.insert("Error")
        }

        // Preserve any unmapped top-level payload children (vendor extensions, or
        // subtype content not yet typed). FSTREQ / FTBIND carry no payload at all.
        message.extensions = root.payloadChildren.filter { !mappedNames.contains($0.name) }
        return message
    }

    // MARK: - Subtype mappers

    private static func refuelingOrder(from root: CapturedElement) -> FUELRefuelingOrder {
        var o = FUELRefuelingOrder()
        o.refuelingRequired = bool(root.attribute("refuelingRequiredIndicator"))
        o.acknowledgementRequired = bool(root.attribute("acknowledgementRequired"))
        o.finalFuelIndicator = bool(root.attribute("finalFuelIndicator"))
        o.aircraftMassUnitDisplay = root.attribute("aircraftMassUnitDisplay")

        o.serviceAirport = root.first(named: "ServiceAirport")?.text.trimmedOrNil
        o.intoPlaneServiceCode = root.first(named: "IntoPlaneServiceCode")?.text.trimmedOrNil
        o.serviceFlight = root.first(named: "ServiceFlight")

        if let limit = root.first(named: "OperationalLimit") {
            o.operationalLimit = weight(from: limit)
            o.operationalLimitReason = limit.attribute("reason")
        }
        o.blockFuel = weight(from: root.first(named: "BlockFuel"))
        o.taxiFuel = weight(from: root.first(named: "TaxiFuel"))
        o.tripFuel = weight(from: root.first(named: "TripFuel"))
        if let arrival = root.first(named: "ArrivalFuel") {
            o.arrivalFuel = weight(from: arrival)
            o.arrivalFuelActual = bool(arrival.attribute("actual"))
        }
        o.fuelTruckOnStandby = bool(root.first(named: "FuelTruckOnStandby")?.text)
        return o
    }

    private static func receipt(from root: CapturedElement) -> FUELReceipt {
        var r = FUELReceipt()
        r.intoPlaneServiceCode = root.first(named: "IntoPlaneServiceCode")?.text.trimmedOrNil
        r.fuelSupplierCode = root.first(named: "FuelSupplierCode")?.text.trimmedOrNil
        r.fuelTruckIds = root.all(named: "FuelTruckId").compactMap { $0.text.trimmedOrNil }
        // FRCSUB uses <RefuelingDefuelingIndicator>; FRCACK uses <DefuelingIndicator>.
        r.defuelingIndicator = bool(root.first(named: "RefuelingDefuelingIndicator")?.text
                                    ?? root.first(named: "DefuelingIndicator")?.text)
        r.fuelReceiptNumber = root.first(named: "FuelReceiptNumber")?.text.trimmedOrNil
        r.fuelVolume = volume(from: root.first(named: "FuelVolume"))
        r.fuelMass = weight(from: root.first(named: "FuelMass"))
        r.fuelDensity = density(from: root.first(named: "FuelDensity"))
        r.fuelType = root.first(named: "FuelType")?.text.trimmedOrNil
        return r
    }

    private static func cgAdvisory(from root: CapturedElement) -> FUELCGAdvisory {
        var c = FUELCGAdvisory()
        c.fwdTakeoffCGLimit = root.first(named: "FwdTakeoffCenterOfGravityLimit")?.doubleValue
        c.aftTakeoffCGLimit = root.first(named: "AftTakeoffCenterOfGravityLimit")?.doubleValue
        c.calculatedTakeoffCG = root.first(named: "CalculatedTakeoffCenterOfGravity")?.doubleValue
        c.takeoffWeight = weight(from: root.first(named: "TakeoffWeight"))
        c.taxiFuel = weight(from: root.first(named: "TaxiFuel"))
        return c
    }

    private static func status(from el: CapturedElement) -> FUELStatus {
        var s = FUELStatus()
        s.currentZFW = el.first(named: "CurrentZFW")?.intValue
        s.currentZFWSource = el.first(named: "CurrentZFWSource")?.text.trimmedOrNil
        s.zfwEntryDate = el.first(named: "ZFWEntryDate")?.text.trimmedOrNil
        s.currentZFCG = el.first(named: "CurrentZFCG")?.intValue
        s.currentZFCGSource = el.first(named: "CurrentZFCGSource")?.text.trimmedOrNil
        s.zfcgEntryDate = el.first(named: "ZFCGEntryDate")?.text.trimmedOrNil
        s.currentPFQ = el.first(named: "CurrentPFQ")?.intValue
        s.currentPFQSource = el.first(named: "CurrentPFQSource")?.text.trimmedOrNil
        s.pfqEntryDate = el.first(named: "PFQEntryDate")?.text.trimmedOrNil
        s.gwcg = el.first(named: "GWCG")?.intValue
        s.gwcgAccuracyState = el.first(named: "GWCGAccuracyState")?.text.trimmedOrNil
        s.fob = el.first(named: "FOB")?.intValue
        s.fobAccuracyState = el.first(named: "FOBAccuracyState")?.text.trimmedOrNil
        s.ttk = el.first(named: "TTK")?.intValue
        s.ttkAccuracyState = el.first(named: "TTKAccuracyState")?.text.trimmedOrNil
        s.aircraftMassUnitDisplayed = el.first(named: "AircraftMassUnitDisplayed")?.text.trimmedOrNil
        return s
    }

    private static func fuelData(from el: CapturedElement) -> FUELData {
        FUELData(
            currentZFW: el.first(named: "CurrentZFW")?.intValue,
            currentZFCG: el.first(named: "CurrentZFCG")?.intValue,
            currentPFQ: el.first(named: "CurrentPFQ")?.intValue,
            finalRefuelOperation: bool(el.first(named: "FinalRefuelOperation")?.text)
        )
    }

    private static func error(from el: CapturedElement) -> FUELError {
        FUELError(
            erroneousService: el.attribute("erroneousService"),
            erroneousElement: el.attribute("erroneousElement"),
            erroneousVersion: el.attribute("erroneousVersion").flatMap { Int($0) },
            errorClass: el.attribute("errorClass").flatMap { Int($0) },
            errorType: el.attribute("errorType").flatMap { Int($0) },
            errorData: el.attribute("errorData")
        )
    }

    // MARK: - simpleContent measurement helpers
    //
    // FUEL measurement elements carry their numeric magnitude as element text and the
    // unit as a `unit` attribute on the same element. Defaults mirror the measurement
    // structs (kg / l / kg/l) but the actual `@unit` is preserved whenever present.

    private static func weight(from el: CapturedElement?) -> ARINCWeight? {
        guard let el, let v = el.doubleValue else { return nil }
        return ARINCWeight(value: v, unit: el.attribute("unit") ?? "kg")
    }

    private static func volume(from el: CapturedElement?) -> ARINCVolume? {
        guard let el, let v = el.doubleValue else { return nil }
        return ARINCVolume(value: v, unit: el.attribute("unit") ?? "l")
    }

    private static func density(from el: CapturedElement?) -> ARINCDensity? {
        guard let el, let v = el.doubleValue else { return nil }
        return ARINCDensity(value: v, unit: el.attribute("unit") ?? "kg/l")
    }

    /// Parse an XML boolean ("true"/"1" => true, "false"/"0" => false), trimming
    /// whitespace. Returns `nil` for absent/unrecognized values.
    private static func bool(_ raw: String?) -> Bool? {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        switch t.lowercased() {
        case "true", "1": return true
        case "false", "0": return false
        default: return nil
        }
    }
}
