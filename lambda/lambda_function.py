import json
import boto3
import os
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    try:
        # Parse incoming request body
        body = json.loads(event['body'])
        
        # Generate unique submission ID
        submission_id = str(uuid.uuid4())
        
        # Prepare item for DynamoDB
        item = {
            'submissionId': submission_id,
            'name': body.get('name'),
            'email': body.get('email'),
            'message': body.get('message'),
            'timestamp': datetime.utcnow().isoformat(),
            'status': 'new'
        }
        
        # Write to DynamoDB
        table.put_item(Item=item)
        
        # Return success
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Submission received',
                'submissionId': submission_id
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Internal server error'
            })
        }