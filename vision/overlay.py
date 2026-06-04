#!/usr/bin/env python3
"""OpenCV Live Overlay Viewer
Displays drone telemetry as overlay on video feed - cockpit-style camera view
"""

import json
import cv2
import paho.mqtt.client as mqtt

LATEST = {}

def on_message(client, userdata, msg):
    global LATEST
    try:
        LATEST = json.loads(msg.payload.decode("utf-8"))
    except Exception:
        pass

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="overlay")
client.on_message = on_message
client.connect("localhost", 1883, 60)
client.subscribe("drone/telemetry", qos=1)
client.loop_start()

cap = cv2.VideoCapture(0)

while True:
    ok, frame = cap.read()
    if not ok:
        break

    gps = LATEST.get("gps", {})
    alt = LATEST.get("altitude_m", {})
    bat = LATEST.get("battery", {})
    imu = LATEST.get("imu", {})
    vel = LATEST.get("velocity_ned", {})

    lines = [
        f"LAT: {gps.get('lat', '--')}  LON: {gps.get('lon', '--')}",
        f"ALT: {alt.get('relative', '--')} m",
        f"BAT: {bat.get('percent', '--')} %",
        f"TEMP: {imu.get('temperature_c', '--')} C",
        f"SPD: {vel.get('ground_speed_mps', '--')} m/s",
    ]

    y = 35
    for line in lines:
        cv2.putText(frame, line, (20, y), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        y += 32

    cv2.imshow("Drone Telemetry Overlay", frame)
    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()
