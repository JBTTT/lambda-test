import json
import os
import boto3

sns = boto3.client("sns")
ALERT_THRESHOLD_TEMP = 30.0  # adjust as needed

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")

def handler(event, context):
    print("Received event:", json.dumps(event))

    # EventBridge "detail" will contain telemetry
    # Example: { "device_id": "sensor-01", "temperature": 32.5, "humidity": 78 }
    detail = event.get("detail", {})
    device_id = detail.get("device_id", "unknown-device")
    temperature = float(detail.get("temperature", 0))
    humidity = float(detail.get("humidity", 0))

    if temperature > ALERT_THRESHOLD_TEMP:
        message = (
            f"ALERT: High temperature from {device_id}\n"
            f"Temperature: {temperature}°C\n"
            f"Humidity: {humidity}%"
        )
        print("Sending SNS alert:", message)

        if SNS_TOPIC_ARN:
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"IoT Alert: {device_id} temperature {temperature}°C",
                Message=message,
            )

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Processed IoT telemetry"})
    }
