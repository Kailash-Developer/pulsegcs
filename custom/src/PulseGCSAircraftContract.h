#pragma once

#include <QtCore/QLoggingCategory>
#include <QtQmlIntegration/QtQmlIntegration>

Q_DECLARE_LOGGING_CATEGORY(PulseGCSAircraftLog)

namespace PulseGCS
{
QML_NAMED_ELEMENT(PulseGCSAircraft)
Q_NAMESPACE

/// Serial number / UID marker uniquely identifying a SKYX aircraft.
inline constexpr char kSkyxSerialMarker[] = "19112524119191911114";

/// Aircraft discovery and link lifecycle state.
/// Searching         – awaiting MAVLink heartbeat
/// Connecting        – heartbeat received, initial handshake in progress
/// ParameterSync     – parameters downloading
/// Connected         – parameters ready, vehicle fully identified
/// CommunicationLost – link active but heartbeats timed out
/// Disconnected      – link closed or all links removed
/// IdentityConflict  – duplicate SKYX UID / serialNumber detected
/// InitialFailed     – initial connect state-machine timed out / failed
enum class ConnectionState {
    Searching,
    Connecting,
    ParameterSync,
    Connected,
    CommunicationLost,
    Disconnected,
    IdentityConflict,
    InitialFailed
};
Q_ENUM_NS(ConnectionState)

/// Telemetry identity completeness.
/// Unknown   – one or more identity fields are not yet populated
/// Available – all required identity fields (firmware, model, serial, version) are known
enum class TelemetryClassification {
    Unknown,
    Available
};
Q_ENUM_NS(TelemetryClassification)

} // namespace PulseGCS
