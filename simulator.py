import boto3
import json
import random
import time

client = boto3.client("events", region_name="us-east-1")

while True:
    event = {
        "Source": "cet11.grp1.iot",
        "DetailType": "iot.telemetry",
        "Detail": json.dumps({
            "device_id": "sensor-01",
            "temperature": random.uniform(20.0, 40.0),
            "humidity": random.uniform(40, 90)
        })
    }

    client.put_events(Entries=[event])
    print("Sent IoT event:", event)
    time.sleep(5)
