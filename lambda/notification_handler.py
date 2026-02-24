import json
import boto3
import os

ses = boto3.client('ses', region_name='eu-central-1')

SENDER_EMAIL = os.environ['SENDER_EMAIL']
RECIPIENT_EMAIL = os.environ['RECIPIENT_EMAIL']

def lambda_handler(event, context):
    for record in event['Records']:

        if record['eventName'] != 'INSERT':
            print(f"Skipping event: {record['eventName']}")
            continue

        new_image = record['dynamodb']['NewImage']

        name          = new_image['name']['S']
        email         = new_image['email']['S']
        message       = new_image['message']['S']
        timestamp     = new_image['timestamp']['S']
        submission_id = new_image['submissionId']['S']

        email_body = f"""New contact form submission received.

Submission ID : {submission_id}
Timestamp     : {timestamp}
Name          : {name}
Email         : {email}

Message:
{message}

---
AdventureConnect Contact System
"""

        try:
            ses.send_email(
                Source=SENDER_EMAIL,
                Destination={'ToAddresses': [RECIPIENT_EMAIL]},
                Message={
                    'Subject': {
                        'Data': f'New Contact Submission from {name}',
                        'Charset': 'UTF-8'
                    },
                    'Body': {
                        'Text': {
                            'Data': email_body,
                            'Charset': 'UTF-8'
                        }
                    }
                }
            )
            print(f"Email sent for submission {submission_id}")

        except Exception as e:
            print(f"Failed to send email for {submission_id}: {str(e)}")
            # Re-raise so Lambda retries the record via Stream - without this, failed emails would be silently dropped
            raise      

    return {'statusCode': 200}