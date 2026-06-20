// OrganizedTracksTests.swift
// ARINC633KitTests
//
// Synthetic Organized Track System fixtures — fictional tracks, waypoints, and
// coordinates. No real operational/NAT data is reproduced.

import Testing
import Foundation
@testable import ARINC633Kit

@Suite("OrganizedTracks")
struct OrganizedTracksTests {

    // Sample-shaped encoding: <OrganizedTrack> at root, <Waypoints>/<Waypoint>,
    // <Connections>/<Connection> with @entryExit.
    private static let sampleXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <OrganizedTracks trackMessageIdentifier="999" area="NorthAtlantic" xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-03-20T05:34:07Z"/>
      <OrganizedTrack routeIdentifier="A" startValidTime="2030-03-20T11:30:00Z" endValidTime="2030-03-20T19:00:00Z" area="NAT">
        <LateralRoute>
          <Waypoints>
            <Waypoint sequenceId="1" waypointId="ZZENT">
              <Function>OceanicEntryPoint</Function>
            </Waypoint>
            <Waypoint sequenceId="2" waypointId="5520N" waypointName="55N020W"/>
            <Waypoint sequenceId="3" waypointId="ZZEXT">
              <Function>OceanicExitPoint</Function>
            </Waypoint>
          </Waypoints>
        </LateralRoute>
        <VerticalRoute>
          <Altitudes direction="westbound">
            <Altitude><Value unit="ft/100">310</Value></Altitude>
            <Altitude><Value unit="ft/100">320</Value></Altitude>
            <Altitude><Value unit="ft/100">330</Value></Altitude>
          </Altitudes>
        </VerticalRoute>
        <Connections>
          <Connection routeIdentifier="N202B" area="NAR" entryExit="exit"/>
          <Connection routeIdentifier="N206C" area="NAT" entryExit="exit"/>
        </Connections>
      </OrganizedTrack>
      <Remarks>
        <Remark><Paragraph><Text>SYNTHETIC REMARK ONE</Text></Paragraph></Remark>
        <Remark><Paragraph><Text>SYNTHETIC REMARK TWO</Text></Paragraph></Remark>
      </Remarks>
      <ZZVendorBlock custom="1"/>
    </OrganizedTracks>
    """.utf8)

    // Schema-shaped encoding: <OrganizedTracksSet>, <RouteWaypoints>/<RouteWaypoint>,
    // <Coordinates latitude="..." longitude="...">, <EntryConnections>.
    private static let schemaXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <OrganizedTracks trackMessageIdentifier="123" area="NAT" xmlns="http://aeec.aviation-ia.net/633">
      <M633Header versionNumber="4" timestamp="2030-03-20T05:34:07Z"/>
      <OrganizedTracksSet>
        <OrganizedTrack routeIdentifier="W">
          <LateralRoute>
            <RouteWaypoints>
              <RouteWaypoint sequenceId="1" waypointId="ZZWPT" waypointName="55N020W">
                <Coordinates latitude="198000.0" longitude="-72000.0"/>
                <Functions>
                  <Function>OceanicEntryPoint</Function>
                </Functions>
              </RouteWaypoint>
            </RouteWaypoints>
          </LateralRoute>
          <EntryConnections>
            <Connection routeIdentifier="C100"/>
          </EntryConnections>
        </OrganizedTrack>
      </OrganizedTracksSet>
    </OrganizedTracks>
    """.utf8)

    @Test("Parses sample-shaped tracks, waypoints, altitudes, connections, remarks")
    func parsesSampleShape() throws {
        guard case let .organizedTracks(msg) = try ARINC633Parser().parse(data: Self.sampleXML) else {
            Issue.record("Expected .organizedTracks"); return
        }
        #expect(msg.trackMessageIdentifier == "999")
        #expect(msg.area == "NorthAtlantic")
        #expect(msg.header.versionNumber == "4")
        #expect(msg.tracks.count == 1)

        let track = try #require(msg.tracks.first)
        #expect(track.routeIdentifier == "A")
        #expect(track.area == "NAT")
        #expect(track.startValidTime == "2030-03-20T11:30:00Z")
        #expect(track.endValidTime == "2030-03-20T19:00:00Z")

        #expect(track.waypoints.map(\.waypointId) == ["ZZENT", "5520N", "ZZEXT"])
        #expect(track.waypoints.first?.sequenceId == 1)
        #expect(track.waypoints.first?.functions == ["OceanicEntryPoint"])
        #expect(track.waypoints.last?.functions == ["OceanicExitPoint"])
        #expect(track.waypoints[1].waypointName == "55N020W")

        #expect(track.altitudeGroups.count == 1)
        let alts = try #require(track.altitudeGroups.first)
        #expect(alts.direction == "westbound")
        #expect(alts.altitudes.map(\.value) == [310, 320, 330])
        #expect(alts.altitudes.first?.unit == "ft/100")

        #expect(track.connections.map(\.routeIdentifier) == ["N202B", "N206C"])
        #expect(track.connections.first?.entryExit == "exit")

        #expect(msg.remarks == ["SYNTHETIC REMARK ONE", "SYNTHETIC REMARK TWO"])
        #expect(msg.extensions.map(\.name) == ["ZZVendorBlock"])
    }

    @Test("Parses schema-shaped tracks, coordinates, entry connections")
    func parsesSchemaShape() throws {
        let msg = try OrganizedTracksParser().parse(data: Self.schemaXML)
        #expect(msg.trackMessageIdentifier == "123")
        #expect(msg.tracks.count == 1)

        let track = try #require(msg.tracks.first)
        #expect(track.routeIdentifier == "W")
        #expect(track.waypoints.count == 1)

        let wpt = try #require(track.waypoints.first)
        #expect(wpt.waypointId == "ZZWPT")
        #expect(wpt.functions == ["OceanicEntryPoint"])
        // 198000 arc-seconds / 3600 = 55.0 N ; -72000 / 3600 = -20.0 W
        #expect(wpt.coordinate?.latitude == 55.0)
        #expect(wpt.coordinate?.longitude == -20.0)

        #expect(track.connections.count == 1)
        #expect(track.connections.first?.routeIdentifier == "C100")
        #expect(track.connections.first?.entryExit == "entry")
    }
}
