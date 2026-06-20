// DeIcing.swift
// ARINC633Kit
//
// Typed model for the DeIcing message family. Source: DEICING.xsd, which defines six
// root elements that share a common envelope and overlapping payload vocabulary:
//
//   DORSUB  De-Icing Order Submit       DORACK  De-Icing Order Acknowledge
//   DORIND  De-Icing Order Indication   DPRREP  De-Icing Process Report
//   DRCSUB  De-Icing Receipt Submit     DRCACK  De-Icing Receipt Acknowledge
//
// Rather than six near-duplicate types, the shared payload is modeled ONCE on
// `DeIcingMessage`; the active subtype is recorded in `messageSubtype` (the root
// element's local name). Each field documents which subtype(s) populate it. Fields
// absent in a given subtype simply stay `nil`.

import Foundation

/// A parsed DeIcing message (order, indication, process report, or receipt).
///
/// One Swift type spans all six DeIcing root elements (`DORSUB`, `DORACK`, `DORIND`,
/// `DPRREP`, `DRCSUB`, `DRCACK`). Inspect ``messageSubtype`` to learn which root
/// produced the instance; the populated fields follow from that subtype's schema.
public struct DeIcingMessage: Sendable, Equatable {

    /// Root elements that map to a De-Icing message (per DEICING.xsd).
    public static let rootElements = ["DORACK", "DORIND", "DORSUB", "DPRREP", "DRCACK", "DRCSUB"]

    /// Standard ARINC 633 header (`<M633Header>`).
    public let header: ARINC633Header

    /// Supplementary header with flight/aircraft context (`<M633SupplementaryHeader>`).
    public let supplementaryHeader: SupplementaryHeader

    /// De-Icing message subtype: the root element's local name (e.g. `"DORACK"`,
    /// `"DPRREP"`). Drives which of the fields below are meaningful.
    public let messageSubtype: String?

    // MARK: - Order routing (DORSUB / DORACK / DRCSUB)

    /// Airport at which the de-/anti-icing service takes place
    /// (`ServiceAirport`, ICAO code; DORSUB / DORACK). Optional.
    public var serviceAirport: String?

    /// Three-character code identifying the de-icing provider
    /// (`DeIcingProviderID` / `DeIcingProviderId`; DORSUB / DORACK / DRCSUB). Optional.
    public var deIcingProviderID: String?

    /// Commercial flight number of the flight to be serviced
    /// (`ServiceFlight`; DORSUB / DORACK). Optional.
    public var serviceFlight: String?

    /// `true` if de-/anti-icing is required, `false` if no action is necessary
    /// (`@deicingRequiredIndicator`; DORSUB / DORACK). Optional.
    public var deicingRequired: Bool?

    /// `true` if the recipient must return an acknowledgement
    /// (`@acknowledgementRequired`; DORSUB / DORACK). Optional.
    public var acknowledgementRequired: Bool?

    // MARK: - Order indication (DORIND)

    /// Apron position identifier or pad name where servicing occurs
    /// (`DeIcingPlace` text; DORIND). Optional.
    public var deIcingPlace: String?

    /// Whether servicing happens at the stand or at a remote pad
    /// (`DeIcingPlace/@deIcingPlaceType`, e.g. "at Stand (Gate)" / "at Pad (remote)";
    /// DORIND). Optional.
    public var deIcingPlaceType: String?

    /// Estimated de-/anti-icing begin time as calculated by the provider
    /// (`EstimatedDe-IcingBeginTime`, `xs:dateTime`; DORIND). Optional.
    public var estimatedBeginTime: String?

    /// Estimated de-/anti-icing end time as calculated by the provider
    /// (`EstimatedDe-IcingEndTime`, `xs:dateTime`; DORIND). Optional.
    public var estimatedEndTime: String?

    /// Provider's de-icing sequence number (`DeIcingSequenceNumber`,
    /// `xs:positiveInteger`; DORIND). Optional.
    public var deIcingSequenceNumber: Int?

    /// Normal or special de-icing operations
    /// (`@deIcingOpsIndicator`, "normal" / "adverse"; DORIND, required by schema).
    public var deIcingOpsIndicator: String?

    // MARK: - Receipt routing (DRCSUB)

    /// Commercial de-icing receipt number (`DeIcingReceiptNumber`, 1–20 chars;
    /// DRCSUB). Optional.
    public var deIcingReceiptNumber: String?

    // MARK: - Treatment payload (DPRREP / DRCSUB / DRCACK)

    /// The de-icing treatment performed, if reported. Present in DPRREP and DRCSUB
    /// (inside the `DeIcingOnly` / `AntiIcing` choice) and in DRCACK (anti-icing code
    /// only). `nil` for order/indication subtypes.
    public var treatment: DeIcingTreatment?

    // MARK: - Free text

    /// Operator remark, paragraphs joined by newlines (`Remark/Paragraph/Text`;
    /// DORIND / DPRREP). Optional.
    public var remark: String?

    /// Unrecognized payload children preserved verbatim (airline/vendor extensions).
    public var extensions: [CapturedElement]

    public init(header: ARINC633Header = ARINC633Header(),
                supplementaryHeader: SupplementaryHeader = SupplementaryHeader(),
                messageSubtype: String? = nil,
                serviceAirport: String? = nil,
                deIcingProviderID: String? = nil,
                serviceFlight: String? = nil,
                deicingRequired: Bool? = nil,
                acknowledgementRequired: Bool? = nil,
                deIcingPlace: String? = nil,
                deIcingPlaceType: String? = nil,
                estimatedBeginTime: String? = nil,
                estimatedEndTime: String? = nil,
                deIcingSequenceNumber: Int? = nil,
                deIcingOpsIndicator: String? = nil,
                deIcingReceiptNumber: String? = nil,
                treatment: DeIcingTreatment? = nil,
                remark: String? = nil,
                extensions: [CapturedElement] = []) {
        self.header = header
        self.supplementaryHeader = supplementaryHeader
        self.messageSubtype = messageSubtype
        self.serviceAirport = serviceAirport
        self.deIcingProviderID = deIcingProviderID
        self.serviceFlight = serviceFlight
        self.deicingRequired = deicingRequired
        self.acknowledgementRequired = acknowledgementRequired
        self.deIcingPlace = deIcingPlace
        self.deIcingPlaceType = deIcingPlaceType
        self.estimatedBeginTime = estimatedBeginTime
        self.estimatedEndTime = estimatedEndTime
        self.deIcingSequenceNumber = deIcingSequenceNumber
        self.deIcingOpsIndicator = deIcingOpsIndicator
        self.deIcingReceiptNumber = deIcingReceiptNumber
        self.treatment = treatment
        self.remark = remark
        self.extensions = extensions
    }
}

/// A de-icing / anti-icing treatment as reported in a process report or receipt.
///
/// Mirrors the schema's `DeIcingOnly` / `AntiIcing` choice: every treatment carries
/// the `deIcingData.Grp` fields; anti-icing treatments additionally carry the
/// `antiIcingData.Grp` (anti-icing code plus end time / fluid volume). The
/// ``isAntiIcing`` flag records which branch of the choice was present.
public struct DeIcingTreatment: Sendable, Equatable {

    /// `true` when the source element was `<AntiIcing>` (de-icing followed by
    /// anti-icing); `false` when it was `<DeIcingOnly>`.
    public var isAntiIcing: Bool

    // MARK: - De-icing data (deIcingData.Grp)

    /// De-icing fluid type when the aircraft was de-iced with fluids
    /// (`DeIcingFluidType`, enumerated 1–4; optional).
    public var deIcingFluidType: Int?

    /// De-icing fluid percentage of the fluid-water mixture
    /// (`DeIcingFluidMix`, 0–100; optional).
    public var deIcingFluidMix: Int?

    /// Time the de-icing process started (`ActualDeIcingBeginTime`, `xs:dateTime`;
    /// optional).
    public var actualDeIcingBeginTime: String?

    /// Time the de-icing process finished (`ActualDeIcingEndTime`, `xs:dateTime`;
    /// optional).
    public var actualDeIcingEndTime: String?

    /// De-icing fluid volume with unit (`DeIcingFluidVolume`, `<Value unit=…>`;
    /// optional).
    public var deIcingFluidVolume: ARINCVolume?

    // MARK: - Anti-icing code (antiIcingCode.Grp)

    /// Fluid type used for anti-icing (`AntiIcingFluidType`, `xs:positiveInteger`).
    /// Required within the anti-icing code group.
    public var antiIcingFluidType: Int?

    /// Brand of the anti-icing fluid (`AntiIcingFluidBrand`, `xs:positiveInteger`;
    /// optional).
    public var antiIcingFluidBrand: Int?

    /// Anti-icing fluid percentage of the fluid-water mixture
    /// (`AntiIcingFluidMix`, `xs:positiveInteger`; optional).
    public var antiIcingFluidMix: Int?

    /// Time the anti-icing process started (`ActualAntiIcingBeginTime`, `xs:dateTime`).
    /// Required within the anti-icing code group.
    public var actualAntiIcingBeginTime: String?

    // MARK: - Anti-icing data (antiIcingData.Grp)

    /// Time the anti-icing process finished (`ActualAntiIcingEndTime`, `xs:dateTime`;
    /// optional).
    public var actualAntiIcingEndTime: String?

    /// Anti-icing fluid volume with unit (`AntiIcingFluidVolume`, `<Value unit=…>`;
    /// optional).
    public var antiIcingFluidVolume: ARINCVolume?

    public init(isAntiIcing: Bool = false,
                deIcingFluidType: Int? = nil,
                deIcingFluidMix: Int? = nil,
                actualDeIcingBeginTime: String? = nil,
                actualDeIcingEndTime: String? = nil,
                deIcingFluidVolume: ARINCVolume? = nil,
                antiIcingFluidType: Int? = nil,
                antiIcingFluidBrand: Int? = nil,
                antiIcingFluidMix: Int? = nil,
                actualAntiIcingBeginTime: String? = nil,
                actualAntiIcingEndTime: String? = nil,
                antiIcingFluidVolume: ARINCVolume? = nil) {
        self.isAntiIcing = isAntiIcing
        self.deIcingFluidType = deIcingFluidType
        self.deIcingFluidMix = deIcingFluidMix
        self.actualDeIcingBeginTime = actualDeIcingBeginTime
        self.actualDeIcingEndTime = actualDeIcingEndTime
        self.deIcingFluidVolume = deIcingFluidVolume
        self.antiIcingFluidType = antiIcingFluidType
        self.antiIcingFluidBrand = antiIcingFluidBrand
        self.antiIcingFluidMix = antiIcingFluidMix
        self.actualAntiIcingBeginTime = actualAntiIcingBeginTime
        self.actualAntiIcingEndTime = actualAntiIcingEndTime
        self.antiIcingFluidVolume = antiIcingFluidVolume
    }
}
