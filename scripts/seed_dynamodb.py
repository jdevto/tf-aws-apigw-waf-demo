#!/usr/bin/env python3
"""
Script to populate DynamoDB table with initial product stock data.
Usage: python scripts/seed_dynamodb.py --table-name <table-name>
"""
import boto3
import argparse
from decimal import Decimal

def seed_table(table_name, region='ap-southeast-2'):
    """Seed DynamoDB table with initial product data."""

    # Initialize DynamoDB client
    dynamodb = boto3.resource('dynamodb', region_name=region)
    table = dynamodb.Table(table_name)

    # Sample product data
    products = [
        {
            'product_id': 'PROD001',
            'product_name': 'Laptop Pro 15',
            'stock_quantity': 45,
            'price': Decimal('1299.99')
        },
        {
            'product_id': 'PROD002',
            'product_name': 'Wireless Headphones',
            'stock_quantity': 120,
            'price': Decimal('89.99')
        },
        {
            'product_id': 'PROD003',
            'product_name': 'USB-C Hub',
            'stock_quantity': 67,
            'price': Decimal('49.99')
        },
        {
            'product_id': 'PROD004',
            'product_name': 'Mechanical Keyboard',
            'stock_quantity': 85,
            'price': Decimal('149.99')
        },
        {
            'product_id': 'PROD005',
            'product_name': 'Monitor 4K',
            'stock_quantity': 32,
            'price': Decimal('599.99')
        }
    ]

    print(f"Seeding table '{table_name}' with {len(products)} products...")

    # Put items into table
    for product in products:
        try:
            table.put_item(Item=product)
            print(f"✓ Added {product['product_id']}: {product['product_name']}")
        except Exception as e:
            print(f"✗ Failed to add {product['product_id']}: {e}")

    print(f"\n✓ Successfully seeded {len(products)} products to '{table_name}'")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Seed DynamoDB table with product data')
    parser.add_argument('--table-name', required=True, help='DynamoDB table name')
    parser.add_argument('--region', default='ap-southeast-2', help='AWS region')

    args = parser.parse_args()

    try:
        seed_table(args.table_name, args.region)
    except Exception as e:
        print(f"Error: {e}")
        exit(1)
