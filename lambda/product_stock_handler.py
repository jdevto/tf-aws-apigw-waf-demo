import json
import boto3
import os
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda function to retrieve product stock from DynamoDB.
    Expects 'product_id' query parameter.
    """
    try:
        # Get product_id from query parameters
        query_params = event.get('queryStringParameters') or {}
        product_id = query_params.get('product_id')

        if not product_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing required parameter: product_id'
                })
            }

        # Query DynamoDB for the product
        response = table.get_item(
            Key={'product_id': product_id}
        )

        # Check if item exists
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': f'Product {product_id} not found'
                })
            }

        item = response['Item']

        # Convert Decimal to float for JSON serialization
        result = {
            'product_id': item['product_id'],
            'product_name': item['product_name'],
            'stock_quantity': item['stock_quantity'] if isinstance(item['stock_quantity'], (int, float)) else int(item['stock_quantity']),
            'price': float(item['price'])
        }

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(result)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
