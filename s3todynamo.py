import json
import boto3
import csv
from io import StringIO

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    print("Received event: ", json.dumps(event))

    try:
        # Extract bucket and object details from the event
        bucket_name = event['detail']['bucket']['name']
        object_key = event['detail']['object']['key']
        
        # Fetch the object from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        csv_content = response['Body'].read().decode('utf-8-sig')  # Use 'utf-8-sig' to handle BOM
        
        # Read the CSV content
        csv_reader = csv.DictReader(StringIO(csv_content))
        
        # Write to DynamoDB
        table = dynamodb.Table('colors')
        for row in csv_reader:
            # Clean up column names by removing BOM if it exists
            cleaned_row = {key.lstrip('\ufeff'): value for key, value in row.items()}
            
            # Debugging: Log the cleaned row
            print(f"Processing row: {cleaned_row}")

            # Ensure 'Name' and 'HEX' are present
            if 'Name' not in cleaned_row or 'HEX' not in cleaned_row or 'RGB' not in cleaned_row:
                print(f"Missing required keys in CSV row: {cleaned_row}")
                continue
            
            item = {
                'Name': cleaned_row['Name'],  # Hash key
                'HEX': cleaned_row['HEX'],    # Range key
                'RGB': cleaned_row['RGB']
            }
            print(f"Inserting item into DynamoDB: {item}")
            
            try:
                table.put_item(Item=item)
            except Exception as e:
                print(f"Error inserting item into DynamoDB: {str(e)}")
                raise e
        
        print(f"Processed file: {object_key} from bucket: {bucket_name}")

    except KeyError as e:
        print(f"KeyError: {str(e)}")
        raise e
    except Exception as e:
        print(f"Error processing file {object_key} from bucket {bucket_name}: {str(e)}")
        raise e

    return {
        'statusCode': 200,
        'body': json.dumps('CSV processed successfully')
    }
