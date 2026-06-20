// FUEL.swift
// ARINC633Kit
//
// Typed model for the FUEL message family: refueling orders/acknowledgements,
// fuel receipts, fuel process reports, fuel CG advisory, fuel status reports/requests,
// fuel data submission/command, and the auto-ground-transfer / refuel-end / error
// indications.
//
// Source: REFUELING.xsd (FCAIND, FRCSUB, FRCACK, FPRREP, FORSUB, FORACK),
// CGTARGETING.xsd (FSTREQ, FSTREP, FDASUB, FDAACK, FDACOM, FENIND, FTBIND, FTEIND,
// FTIIND, FERIND), and shared complex types in fuelcommon.xsd (fuelStatusType,
// fuelDataType, TypeOfError). Samples F*.xml.
//
// All 16 root elements share an overlapping schema vocabulary, so a single
// `FUELMessage` models the UNION of their payloads; the concrete subtype is carried
// in `messageSubtype` (the root element name). Each subtype populates only the subset
// of fields its schema defines; the rest stay `nil`/empty.
//
// SAFETY: fuel quantities, weights, and CG values are safety-critical. Units are noted
// precisely in every doc comment and never discarded — weight/volume/density/mass
// fields carry their `unit` attribute via the typed measurement structs, and the
// `fuelStatusType` integer quantities document their implied units (mass unit given by
// `aircraftMassUnitDisplayed`; CG values in permille of mean aerodynamic chord).

import Foundation

/// A parsed FUEL-family message (refueling, fuel receipt, fuel status, CG targeting,
/// fuel data, auto-transfer indication, or fuel error).
///
/// The concrete message type is distinguished by `messageSubtype`, which is the XML
/// root element name (one of `rootElements`). Fields are the union across all subtypes;
/// only those relevant to a given subtype are populated.
public struct FUELMessage: Sendable, Equatable {
    /// Root elements that map to a FUEL message (per REFUELING.xsd / CGTARGETING.xsd).
    public static let rootElements = [
        "FCAIND", "FDAACK", "FDACOM", "FDASUB", "FENIND", "FERIND",
        "FORACK", "FORSUB", "FPRREP", "FRCACK", "FRCSUB", "FSTREP",
        "FSTREQ", "FTBIND", "FTEIND", "FTIIND"
    ]

    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context (`<M633SupplementaryHeader>`).
    ///
    /// Note: several subtypes (FSTREQ, FSTREP, FDASUB/ACK/COM, FEN/FTB/FTE/FTI/FER
    /// indications) carry only `<M633Header>` and no supplementary header; in that case
    /// this is an empty `SupplementaryHeader`.
    public let supplementaryHeader: SupplementaryHeader

    /// FUEL message subtype — the root element name (e.g. "FORSUB", "FCAIND", "FSTREP").
    public let messageSubtype: String?

    // MARK: - Order / Refueling fields (FORSUB, FORACK)

    /// Refueling order parameters, present for FORSUB / FORACK. `nil` otherwise.
    public var order: FUELRefuelingOrder?

    // MARK: - Fuel receipt fields (FRCSUB, FRCACK)

    /// Into-plane fuel receipt parameters, present for FRCSUB / FRCACK. `nil` otherwise.
    public var receipt: FUELReceipt?

    // MARK: - Fuel process report (FPRREP)

    /// Into-plane service code (3-char IATA Fuel Quality Pool code). FPRREP also carries
    /// this; it is surfaced here for FPRREP and mirrored inside `receipt` for FRC*.
    /// (`<IntoPlaneServiceCode>`)
    public var intoPlaneServiceCode: String?

    /// Refueling/defueling indicator at message level: `false` = refueling,
    /// `true` = defueling. Present for FPRREP (`<RefuelingDefuelingIndicator>`).
    public var refuelingDefuelingIndicator: Bool?

    /// Fuel progress report status code + timestamp (FPRREP, `<FuelProgressReportStatus>`,
    /// status name per ARINC 633 table 6.3.3.2.2). `nil` for other subtypes.
    public var progressReportStatus: FUELProgressReportStatus?

    // MARK: - CG advisory (FCAIND)

    /// Takeoff CG advisory values, present for FCAIND. `nil` otherwise.
    public var cgAdvisory: FUELCGAdvisory?

    // MARK: - Fuel status block (FSTREP, FENIND, FTEIND, FTIIND)

    /// Aircraft fuel/weight/CG status snapshot (`<status>`, `fuelStatusType`). Present for
    /// FSTREP, FENIND, FTEIND, FTIIND. `nil` otherwise.
    public var status: FUELStatus?

    // MARK: - Fuel data block (FDASUB, FDAACK, FDACOM)

    /// Fuel data submission/acknowledge payload (`<DATA>`, `fuelDataType`). Present for
    /// FDASUB / FDAACK. `nil` otherwise.
    public var data: FUELData?

    /// Fuel data command confirmation flag (`<CONFIRM>`). Present for FDACOM. `nil`
    /// otherwise.
    public var confirm: Bool?

    // MARK: - Fuel error (FERIND)

    /// Fuel error descriptor (`<Error>`, `TypeOfError`). Present for FERIND. `nil`
    /// otherwise.
    public var error: FUELError?

    // MARK: - Extensions

    /// Unrecognized top-level payload children preserved verbatim (airline/vendor
    /// extensions, or subtype content not yet typed). Nothing in a well-formed document
    /// is dropped.
    public var extensions: [CapturedElement]

    /// Backward-compatible initializer. New typed fields default to empty/`nil` so that
    /// existing call sites continue to compile.
    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                messageSubtype: String? = nil,
                order: FUELRefuelingOrder? = nil,
                receipt: FUELReceipt? = nil,
                intoPlaneServiceCode: String? = nil,
                refuelingDefuelingIndicator: Bool? = nil,
                progressReportStatus: FUELProgressReportStatus? = nil,
                cgAdvisory: FUELCGAdvisory? = nil,
                status: FUELStatus? = nil,
                data: FUELData? = nil,
                confirm: Bool? = nil,
                error: FUELError? = nil,
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.messageSubtype = messageSubtype
        self.order = order
        self.receipt = receipt
        self.intoPlaneServiceCode = intoPlaneServiceCode
        self.refuelingDefuelingIndicator = refuelingDefuelingIndicator
        self.progressReportStatus = progressReportStatus
        self.cgAdvisory = cgAdvisory
        self.status = status
        self.data = data
        self.confirm = confirm
        self.error = error
        self.extensions = extensions
    }
}

// MARK: - Refueling order (FORSUB / FORACK)

/// Refueling order parameters (FORSUB / FORACK).
///
/// All `<*Fuel>` quantities are masses carried as `ARINCWeight` so their `unit`
/// attribute (`weightUnitType`: kg, t, lb, hlb) is never lost.
public struct FUELRefuelingOrder: Sendable, Equatable {
    // Root-level attributes.
    /// `@refuelingRequiredIndicator`: `true` if refueling/defueling is required,
    /// `false` if no action is necessary.
    public var refuelingRequired: Bool?
    /// `@acknowledgementRequired`: `true` if the recipient must reply with a FORACK.
    public var acknowledgementRequired: Bool?
    /// `@finalFuelIndicator`: `false` if a preliminary fuel amount is being ordered.
    public var finalFuelIndicator: Bool?
    /// `@aircraftMassUnitDisplay` (`weightUnitType`): mass unit used for pilot display.
    public var aircraftMassUnitDisplay: String?

    // Sequence elements (all optional in schema).
    /// Service airport ICAO code where refueling/defueling takes place
    /// (`<ServiceAirport>`, `AirportICAOCodeType`).
    public var serviceAirport: String?
    /// Into-plane service company code (`<IntoPlaneServiceCode>`, 3-char IATA FQP code).
    public var intoPlaneServiceCode: String?
    /// Commercial flight number of the flight to be refueled (`<ServiceFlight>`,
    /// `FlightNumberType`) — kept as a captured subtree (attributes + nested
    /// CommercialFlightNumber).
    public var serviceFlight: CapturedElement?
    /// Maximum allowable takeoff weight (`<OperationalLimit>`, weight with `@unit`).
    public var operationalLimit: ARINCWeight?
    /// Reason for the operational limit (`<OperationalLimit>/@reason`, e.g.
    /// "TakeOffPerformance").
    public var operationalLimitReason: String?
    /// Block fuel mass (`<BlockFuel>`, weight with `@unit`).
    public var blockFuel: ARINCWeight?
    /// Taxi fuel mass (`<TaxiFuel>`, weight with `@unit`).
    public var taxiFuel: ARINCWeight?
    /// Trip fuel mass (`<TripFuel>`, weight with `@unit`).
    public var tripFuel: ARINCWeight?
    /// Estimated/actual arrival fuel of the previous flight (`<ArrivalFuel>`, weight
    /// with `@unit`).
    public var arrivalFuel: ARINCWeight?
    /// `<ArrivalFuel>/@actual`: `true` if actual, `false` if estimated.
    public var arrivalFuelActual: Bool?
    /// Whether the fuel truck may leave the stand after refueling
    /// (`<FuelTruckOnStandby>`).
    public var fuelTruckOnStandby: Bool?

    public init(refuelingRequired: Bool? = nil,
                acknowledgementRequired: Bool? = nil,
                finalFuelIndicator: Bool? = nil,
                aircraftMassUnitDisplay: String? = nil,
                serviceAirport: String? = nil,
                intoPlaneServiceCode: String? = nil,
                serviceFlight: CapturedElement? = nil,
                operationalLimit: ARINCWeight? = nil,
                operationalLimitReason: String? = nil,
                blockFuel: ARINCWeight? = nil,
                taxiFuel: ARINCWeight? = nil,
                tripFuel: ARINCWeight? = nil,
                arrivalFuel: ARINCWeight? = nil,
                arrivalFuelActual: Bool? = nil,
                fuelTruckOnStandby: Bool? = nil) {
        self.refuelingRequired = refuelingRequired
        self.acknowledgementRequired = acknowledgementRequired
        self.finalFuelIndicator = finalFuelIndicator
        self.aircraftMassUnitDisplay = aircraftMassUnitDisplay
        self.serviceAirport = serviceAirport
        self.intoPlaneServiceCode = intoPlaneServiceCode
        self.serviceFlight = serviceFlight
        self.operationalLimit = operationalLimit
        self.operationalLimitReason = operationalLimitReason
        self.blockFuel = blockFuel
        self.taxiFuel = taxiFuel
        self.tripFuel = tripFuel
        self.arrivalFuel = arrivalFuel
        self.arrivalFuelActual = arrivalFuelActual
        self.fuelTruckOnStandby = fuelTruckOnStandby
    }
}

// MARK: - Fuel receipt (FRCSUB / FRCACK)

/// Into-plane fuel receipt parameters (FRCSUB / FRCACK).
///
/// The schema uses an `xs:choice` between `<FuelVolume>` and `<FuelMass>`; both are
/// modeled here (typically only one is populated). Volume carries its `volumeUnitType`
/// unit (l, ug, ig, …); mass carries its `weightUnitType` unit.
public struct FUELReceipt: Sendable, Equatable {
    /// Into-plane service company code (`<IntoPlaneServiceCode>`, 3-char IATA FQP code).
    public var intoPlaneServiceCode: String?
    /// Fuel supplier company code (`<FuelSupplierCode>`, 3-char IATA FQP code, optional).
    public var fuelSupplierCode: String?
    /// Fuel truck identification numbers (`<FuelTruckId>`, 0..* , 1–10 chars each).
    public var fuelTruckIds: [String]
    /// Refueling/defueling indicator: `false` = refueling, `true` = defueling. Carries
    /// FRCSUB `<RefuelingDefuelingIndicator>` or FRCACK `<DefuelingIndicator>`.
    public var defuelingIndicator: Bool?
    /// Fuel receipt number (`<FuelReceiptNumber>`, 1–20 chars).
    public var fuelReceiptNumber: String?
    /// Fuel volume measured by the into-plane service (`<FuelVolume>`, volume with
    /// `@unit`). One of `fuelVolume` / `fuelMass` per the schema choice.
    public var fuelVolume: ARINCVolume?
    /// Fuel mass measured by the into-plane service (`<FuelMass>`, weight with `@unit`).
    public var fuelMass: ARINCWeight?
    /// Fuel density (`<FuelDensity>`, density with `@unit`, optional).
    public var fuelDensity: ARINCDensity?
    /// Supplied fuel type (`<FuelType>`, 1–10 chars, optional).
    public var fuelType: String?

    public init(intoPlaneServiceCode: String? = nil,
                fuelSupplierCode: String? = nil,
                fuelTruckIds: [String] = [],
                defuelingIndicator: Bool? = nil,
                fuelReceiptNumber: String? = nil,
                fuelVolume: ARINCVolume? = nil,
                fuelMass: ARINCWeight? = nil,
                fuelDensity: ARINCDensity? = nil,
                fuelType: String? = nil) {
        self.intoPlaneServiceCode = intoPlaneServiceCode
        self.fuelSupplierCode = fuelSupplierCode
        self.fuelTruckIds = fuelTruckIds
        self.defuelingIndicator = defuelingIndicator
        self.fuelReceiptNumber = fuelReceiptNumber
        self.fuelVolume = fuelVolume
        self.fuelMass = fuelMass
        self.fuelDensity = fuelDensity
        self.fuelType = fuelType
    }
}

// MARK: - Fuel process report status (FPRREP)

/// Fuel progress report status (FPRREP, `<FuelProgressReportStatus>`).
public struct FUELProgressReportStatus: Sendable, Equatable {
    /// Status code/name for the refueling process (per ARINC 633 table 6.3.3.2.2),
    /// taken from the element text.
    public var status: String?
    /// `@dateTime`: ISO 8601 timestamp the status was reported.
    public var dateTime: String?

    public init(status: String? = nil, dateTime: String? = nil) {
        self.status = status
        self.dateTime = dateTime
    }
}

// MARK: - CG advisory (FCAIND)

/// Takeoff center-of-gravity advisory (FCAIND).
///
/// CG limits/value are percentages (0–100) of the mean aerodynamic chord (%MAC).
/// `takeoffWeight` and `taxiFuel` are masses carrying their `weightUnitType` unit.
public struct FUELCGAdvisory: Sendable, Equatable {
    /// Forward takeoff CG limit, %MAC (`<FwdTakeoffCenterOfGravityLimit>`).
    public var fwdTakeoffCGLimit: Double?
    /// Aft takeoff CG limit, %MAC (`<AftTakeoffCenterOfGravityLimit>`).
    public var aftTakeoffCGLimit: Double?
    /// Calculated takeoff CG, %MAC (`<CalculatedTakeoffCenterOfGravity>`).
    public var calculatedTakeoffCG: Double?
    /// Takeoff weight (`<TakeoffWeight>`, weight with `@unit`).
    public var takeoffWeight: ARINCWeight?
    /// Taxi fuel mass (`<TaxiFuel>`, weight with `@unit`).
    public var taxiFuel: ARINCWeight?

    public init(fwdTakeoffCGLimit: Double? = nil,
                aftTakeoffCGLimit: Double? = nil,
                calculatedTakeoffCG: Double? = nil,
                takeoffWeight: ARINCWeight? = nil,
                taxiFuel: ARINCWeight? = nil) {
        self.fwdTakeoffCGLimit = fwdTakeoffCGLimit
        self.aftTakeoffCGLimit = aftTakeoffCGLimit
        self.calculatedTakeoffCG = calculatedTakeoffCG
        self.takeoffWeight = takeoffWeight
        self.taxiFuel = taxiFuel
    }
}

// MARK: - Fuel status (FSTREP / FENIND / FTEIND / FTIIND)

/// Aircraft fuel/weight/CG status snapshot (`<status>`, `fuelStatusType`).
///
/// SAFETY/UNITS: the mass quantities (`currentZFW`, `currentPFQ`, `fob`, `ttk`) are
/// non-negative integers expressed in the unit named by `aircraftMassUnitDisplayed`
/// (e.g. "KG"); no per-element unit attribute is present in the schema, so the unit
/// MUST be read from `aircraftMassUnitDisplayed`. CG values (`currentZFCG`, `gwcg`) are
/// non-negative integers in permille of mean aerodynamic chord (‰MAC). `*Source` and
/// `*AccuracyState` carry single-character provenance/quality codes.
public struct FUELStatus: Sendable, Equatable {
    /// Current zero-fuel weight (`<CurrentZFW>`), in `aircraftMassUnitDisplayed` units.
    public var currentZFW: Int?
    /// ZFW source code (`<CurrentZFWSource>`).
    public var currentZFWSource: String?
    /// ZFW entry timestamp (`<ZFWEntryDate>`, ISO 8601).
    public var zfwEntryDate: String?
    /// Current zero-fuel CG (`<CurrentZFCG>`), in ‰MAC.
    public var currentZFCG: Int?
    /// ZFCG source code (`<CurrentZFCGSource>`).
    public var currentZFCGSource: String?
    /// ZFCG entry timestamp (`<ZFCGEntryDate>`, ISO 8601).
    public var zfcgEntryDate: String?
    /// Current preset fuel quantity (`<CurrentPFQ>`), in `aircraftMassUnitDisplayed` units.
    public var currentPFQ: Int?
    /// PFQ source code (`<CurrentPFQSource>`).
    public var currentPFQSource: String?
    /// PFQ entry timestamp (`<PFQEntryDate>`, ISO 8601).
    public var pfqEntryDate: String?
    /// Gross-weight CG (`<GWCG>`), in ‰MAC.
    public var gwcg: Int?
    /// GWCG accuracy state code (`<GWCGAccuracyState>`).
    public var gwcgAccuracyState: String?
    /// Fuel on board (`<FOB>`), in `aircraftMassUnitDisplayed` units.
    public var fob: Int?
    /// FOB accuracy state code (`<FOBAccuracyState>`).
    public var fobAccuracyState: String?
    /// Total tank capacity / transfer target quantity (`<TTK>`, optional), in
    /// `aircraftMassUnitDisplayed` units.
    public var ttk: Int?
    /// TTK accuracy state code (`<TTKAccuracyState>`, optional).
    public var ttkAccuracyState: String?
    /// Aircraft mass unit displayed (`<AircraftMassUnitDisplayed>`, e.g. "KG") — the unit
    /// for all mass quantities above.
    public var aircraftMassUnitDisplayed: String?

    public init(currentZFW: Int? = nil,
                currentZFWSource: String? = nil,
                zfwEntryDate: String? = nil,
                currentZFCG: Int? = nil,
                currentZFCGSource: String? = nil,
                zfcgEntryDate: String? = nil,
                currentPFQ: Int? = nil,
                currentPFQSource: String? = nil,
                pfqEntryDate: String? = nil,
                gwcg: Int? = nil,
                gwcgAccuracyState: String? = nil,
                fob: Int? = nil,
                fobAccuracyState: String? = nil,
                ttk: Int? = nil,
                ttkAccuracyState: String? = nil,
                aircraftMassUnitDisplayed: String? = nil) {
        self.currentZFW = currentZFW
        self.currentZFWSource = currentZFWSource
        self.zfwEntryDate = zfwEntryDate
        self.currentZFCG = currentZFCG
        self.currentZFCGSource = currentZFCGSource
        self.zfcgEntryDate = zfcgEntryDate
        self.currentPFQ = currentPFQ
        self.currentPFQSource = currentPFQSource
        self.pfqEntryDate = pfqEntryDate
        self.gwcg = gwcg
        self.gwcgAccuracyState = gwcgAccuracyState
        self.fob = fob
        self.fobAccuracyState = fobAccuracyState
        self.ttk = ttk
        self.ttkAccuracyState = ttkAccuracyState
        self.aircraftMassUnitDisplayed = aircraftMassUnitDisplayed
    }
}

// MARK: - Fuel data (FDASUB / FDAACK)

/// Fuel data submission/acknowledge payload (`<DATA>`, `fuelDataType`).
///
/// UNITS: `currentZFW`/`currentPFQ` are non-negative integers in the aircraft mass unit
/// (unit not carried per-element in `fuelDataType`); `currentZFCG` is ‰MAC.
public struct FUELData: Sendable, Equatable {
    /// Current zero-fuel weight (`<CurrentZFW>`, optional).
    public var currentZFW: Int?
    /// Current zero-fuel CG (`<CurrentZFCG>`, optional), in ‰MAC.
    public var currentZFCG: Int?
    /// Current preset fuel quantity (`<CurrentPFQ>`, optional).
    public var currentPFQ: Int?
    /// Final refuel operation flag (`<FinalRefuelOperation>`, required).
    public var finalRefuelOperation: Bool?

    public init(currentZFW: Int? = nil,
                currentZFCG: Int? = nil,
                currentPFQ: Int? = nil,
                finalRefuelOperation: Bool? = nil) {
        self.currentZFW = currentZFW
        self.currentZFCG = currentZFCG
        self.currentPFQ = currentPFQ
        self.finalRefuelOperation = finalRefuelOperation
    }
}

// MARK: - Fuel error (FERIND)

/// Fuel error descriptor (`<Error>`, `TypeOfError`).
///
/// Identifies the erroneous service/element/version plus an error classification. All
/// fields are attributes on `<Error>`; `errorData` is optional free-form context.
public struct FUELError: Sendable, Equatable {
    /// `@erroneousService` (3-char service code, e.g. "FDA").
    public var erroneousService: String?
    /// `@erroneousElement` (3-char element code, e.g. "SUB").
    public var erroneousElement: String?
    /// `@erroneousVersion` (non-negative integer).
    public var erroneousVersion: Int?
    /// `@errorClass` (non-negative integer).
    public var errorClass: Int?
    /// `@errorType` (non-negative integer).
    public var errorType: Int?
    /// `@errorData` (optional free-form context string).
    public var errorData: String?

    public init(erroneousService: String? = nil,
                erroneousElement: String? = nil,
                erroneousVersion: Int? = nil,
                errorClass: Int? = nil,
                errorType: Int? = nil,
                errorData: String? = nil) {
        self.erroneousService = erroneousService
        self.erroneousElement = erroneousElement
        self.erroneousVersion = erroneousVersion
        self.errorClass = errorClass
        self.errorType = errorType
        self.errorData = errorData
    }
}
