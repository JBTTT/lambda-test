import json
import boto3
import os

sns = boto3.client("sns")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
TEMP_THRESHOLD = 30

def handler(event, context):
    print("Received event:", json.dumps(event))

    detail = event.get("detail", {})
    device = detail.get("device_id", "unknown")
    temp = detail.get("temperature", 0)
    humidity = detail.get("humidity", 0)

    if temp > TEMP_THRESHOLD:
        message = f"""
        IoT Temperature Alert!
        Device: {device}
        Temperature: {temp}
        Humidity: {humidity}
        """

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"IoT Alert - {device}",
            Message=message
        )

    return {"statusCode": 200, "body": "ok"}
