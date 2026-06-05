#!/usr/bin/env python3
"""ROS2 Bridge Node
Bridges MQTT telemetry data to ROS2 topics for robotics system integration
"""

import json
import paho.mqtt.client as mqtt
import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from sensor_msgs.msg import NavSatFix
from geometry_msgs.msg import TwistStamped

class TelemetryBridge(Node):
    def __init__(self):
        super().__init__("telemetry_bridge")
        self.raw_pub = self.create_publisher(String, "/drone/telemetry/raw", 10)
        self.gps_pub = self.create_publisher(NavSatFix, "/drone/gps", 10)
        self.vel_pub = self.create_publisher(TwistStamped, "/drone/velocity", 10)

        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="ros2_bridge")
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.connect("localhost", 1883, 60)
        self.client.loop_start()

    def on_connect(self, client, userdata, flags, reason_code, properties):
        client.subscribe("drone/telemetry", qos=1)

    def on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload.decode("utf-8"))
        except Exception:
            return

        raw = String()
        raw.data = json.dumps(data)
        self.raw_pub.publish(raw)

        gps = data.get("gps", {})
        alt = data.get("altitude_m", {})
        if gps.get("lat") is not None and gps.get("lon") is not None:
            nav = NavSatFix()
            nav.latitude = float(gps["lat"])
            nav.longitude = float(gps["lon"])
            nav.altitude = float(alt.get("absolute", 0.0))
            self.gps_pub.publish(nav)

        vel = data.get("velocity_ned", {})
        tw = TwistStamped()
        tw.twist.linear.x = float(vel.get("north_m_s", 0.0))
        tw.twist.linear.y = float(vel.get("east_m_s", 0.0))
        tw.twist.linear.z = float(vel.get("down_m_s", 0.0))
        self.vel_pub.publish(tw)

def main():
    rclpy.init()
    node = TelemetryBridge()
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == "__main__":
    main()
