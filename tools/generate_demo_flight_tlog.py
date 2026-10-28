#!/usr/bin/env python3
import struct
import math
import os

# MAVLink 2.0 packet generator
CRC_EXTRA = {
    0: 50,    # HEARTBEAT
    1: 124,   # SYS_STATUS
    24: 30,   # GPS_RAW_INT
    30: 39,   # ATTITUDE
    33: 104,  # GLOBAL_POSITION_INT
    74: 20,   # VFR_HUD
    253: 83,  # STATUSTEXT
}

def x25_crc(buf):
    crc = 0xFFFF
    for b in buf:
        tmp = b ^ (crc & 0xFF)
        tmp = (tmp ^ (tmp << 4)) & 0xFF
        crc = (crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)
        crc &= 0xFFFF
    return crc

seq = 0
def pack_msg(sysid, compid, msgid, payload):
    global seq
    magic = 0xFD
    length = len(payload)
    # 7 items: magic (B), len (B), incompat (B), compat (B), seq (B), sysid (B), compid (B)
    header = struct.pack("<BBBBBBB", magic, length, 0, 0, seq % 256, sysid, compid) + struct.pack("<I", msgid)[:3]
    seq += 1
    crc = x25_crc(header[1:] + payload + bytes([CRC_EXTRA[msgid]]))
    return header + payload + struct.pack("<H", crc)

def write_tlog_entry(f, timestamp_usec, packet):
    # QGC tlog format: 64-bit big-endian microsecond timestamp followed by MAVLink packet
    f.write(struct.pack(">Q", timestamp_usec))
    f.write(packet)

# MAVLink Message Packers (packed in wire layout order)
def pack_heartbeat(sysid=1, compid=1, custom_mode=4, base_mode=209, system_status=4):
    payload = struct.pack("<IBBBBB", custom_mode, 2, 3, base_mode, system_status, 3)
    return pack_msg(sysid, compid, 0, payload)

def pack_sys_status(sysid=1, compid=1, voltage=16200, current=1850, battery_rem=88):
    sensors = 0x0001FC07
    payload = struct.pack("<IIIHHhHHHHHHbIII", 
                          sensors, sensors, sensors, 150, voltage, current, 0, 0, 0, 0, 0, 0, battery_rem, 0, 0, 0)
    return pack_msg(sysid, compid, 1, payload)

def pack_gps_raw(sysid=1, compid=1, time_usec=0, lat=377749000, lon=-1224194000, alt=30000, sats=18):
    payload = struct.pack("<QiiiHHHHBBiIIIIH",
                          time_usec, lat, lon, alt, 100, 100, 1200, 4500, 4, sats, 0, 100, 100, 50, 50, 0)
    return pack_msg(sysid, compid, 24, payload)

def pack_global_pos(sysid=1, compid=1, time_boot_ms=0, lat=377749000, lon=-1224194000, alt=30000, relative_alt=25000, vx=400, vy=300, vz=-50, hdg=4500):
    payload = struct.pack("<IiiiihhhH",
                          time_boot_ms, lat, lon, alt, relative_alt, vx, vy, vz, hdg)
    return pack_msg(sysid, compid, 33, payload)

def pack_attitude(sysid=1, compid=1, time_boot_ms=0, roll=0.05, pitch=-0.08, yaw=0.785):
    payload = struct.pack("<Iffffff",
                          time_boot_ms, roll, pitch, yaw, 0.01, 0.01, 0.02)
    return pack_msg(sysid, compid, 30, payload)

def pack_vfr_hud(sysid=1, compid=1, airspeed=8.5, groundspeed=8.2, heading=45, throttle=58, alt=25.0, climb=0.2):
    payload = struct.pack("<ffffhh",
                          airspeed, groundspeed, alt, climb, heading, throttle)
    return pack_msg(sysid, compid, 74, payload)

def pack_statustext(sysid=1, compid=1, severity=6, text=""):
    buf = text.encode('utf-8')[:50].ljust(50, b'\x00')
    payload = struct.pack("<B50sHB", severity, buf, 0, 0)
    return pack_msg(sysid, compid, 253, payload)

def generate_flight_log(filename):
    start_time_usec = int(1730000000 * 1000000) # Epoch base
    base_lat = 37.774929
    base_lon = -122.419416
    
    with open(filename, "wb") as f:
        # Pre-arm checks sequence (0-3 seconds)
        statustexts = [
            (0, 6, "ArduCopter V4.5.1 (PulseGCS Demo)"),
            (500000, 6, "EKF3 IMU0 initialised"),
            (1000000, 6, "GPS 1: detected as u-blox at 115200 baud"),
            (1500000, 6, "GPS 1: 3D RTK Fix (18 satellites)"),
            (2000000, 6, "Pre-Arm: Good"),
            (2500000, 5, "Arming motors"),
            (3000000, 6, "Flight mode: AUTO"),
        ]
        
        for dt_usec, sev, txt in statustexts:
            t = start_time_usec + dt_usec
            write_tlog_entry(f, t, pack_statustext(text=txt, severity=sev))
            write_tlog_entry(f, t, pack_heartbeat(custom_mode=4, base_mode=209 if dt_usec >= 2500000 else 81))
        
        # 120 seconds flight (2 minutes) at 5 Hz (600 steps)
        radius_m = 150.0
        flight_duration_sec = 120
        steps = flight_duration_sec * 5
        
        for i in range(steps):
            t_sec = i * 0.2
            t_usec = start_time_usec + int((3.0 + t_sec) * 1000000)
            time_boot_ms = int((3.0 + t_sec) * 1000)
            
            # Progress angle around circle (2 laps in 120s)
            angle = (t_sec / (flight_duration_sec / 2.0)) * 2.0 * math.pi
            lat_offset = (radius_m * math.sin(angle)) / 111111.0
            lon_offset = (radius_m * math.cos(angle)) / (111111.0 * math.cos(math.radians(base_lat)))
            
            lat = int((base_lat + lat_offset) * 1e7)
            lon = int((base_lon + lon_offset) * 1e7)
            
            # Altitude profile: climbs from 0 to 35m in 8s, cruises, then smooth descent in last 12s
            if t_sec < 8.0:
                rel_alt = (t_sec / 8.0) * 35.0
                climb = 4.375
            elif t_sec > 108.0:
                rel_alt = max(0.5, 35.0 - ((t_sec - 108.0) / 12.0) * 34.5)
                climb = -2.875
            else:
                rel_alt = 35.0 + math.sin(t_sec * 0.3) * 1.5
                climb = math.cos(t_sec * 0.3) * 0.45
            
            heading_deg = (int(math.degrees(angle) + 90.0) % 360)
            groundspeed = 8.5
            yaw_rad = math.radians(heading_deg)
            roll_rad = 0.12 * math.cos(angle)
            pitch_rad = -0.08
            
            voltage_mv = int(16200 - (t_sec / flight_duration_sec) * 1400)
            current_ca = 1850 + int(math.sin(t_sec) * 150)
            batt_pct = int(98 - (t_sec / flight_duration_sec) * 22)
            
            # 5 Hz Telemetry Packets
            write_tlog_entry(f, t_usec, pack_global_pos(time_boot_ms=time_boot_ms, lat=lat, lon=lon,
                                                        alt=int(rel_alt * 1000 + 15000), relative_alt=int(rel_alt * 1000),
                                                        vx=int(groundspeed * math.cos(yaw_rad) * 100),
                                                        vy=int(groundspeed * math.sin(yaw_rad) * 100),
                                                        vz=int(-climb * 100), hdg=int(heading_deg * 100)))
            write_tlog_entry(f, t_usec, pack_attitude(time_boot_ms=time_boot_ms, roll=roll_rad, pitch=pitch_rad, yaw=yaw_rad))
            write_tlog_entry(f, t_usec, pack_vfr_hud(airspeed=groundspeed, groundspeed=groundspeed, heading=heading_deg,
                                                    throttle=55, alt=rel_alt, climb=climb))
            
            # 1 Hz status updates
            if i % 5 == 0:
                write_tlog_entry(f, t_usec, pack_heartbeat(custom_mode=4, base_mode=209, system_status=4))
                write_tlog_entry(f, t_usec, pack_sys_status(voltage=voltage_mv, current=current_ca, battery_rem=batt_pct))
                write_tlog_entry(f, t_usec, pack_gps_raw(time_usec=t_usec, lat=lat, lon=lon, alt=int(rel_alt * 1000 + 15000), sats=18))
        
        # End flight disarm notification
        write_tlog_entry(f, start_time_usec + int((3.0 + flight_duration_sec) * 1000000), 
                         pack_statustext(text="Disarming motors", severity=5))

    print(f"Generated {filename} ({os.path.getsize(filename)} bytes)")

if __name__ == "__main__":
    out_path = "custom/resources/telemetry/demo_flight.tlog"
    generate_flight_log(out_path)
