import json
import boto3
import os

sns = boto3.client("sns")
topic_arn = os.environ["SNS_TOPIC_ARN"]

def lambda_handler(event, context):
    message = {
        "project": "cet11-grp1",
        "alert": "EC2 State Change Detected",
        "event_details": event
    }

    sns.publish(
        TopicArn=topic_arn,
        Message=json.dumps(message, indent=2),
        Subject="CET11-GRP1 AWS Alert: EC2 State Change"
    )

    return {"status": "Alert sent by cet11-grp1 Lambda"}
