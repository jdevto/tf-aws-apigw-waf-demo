# API Gateway with AWS WAF Protection Demo

This Terraform project demonstrates how to protect an Amazon API Gateway Regional API endpoint using AWS WAF with rate-based rules to prevent HTTP flood attacks.

## Architecture

The solution includes:

- **DynamoDB Table**: Stores product inventory data with product_id as the partition key
- **Lambda Function**: Python 3.13 function that retrieves product stock from DynamoDB
- **API Gateway**: Regional REST API endpoint for `/product-stock`
- **AWS WAF**: Web ACL with rate-based rule limiting requests to 2,000 per 5 minutes per IP
- **CloudWatch Logs**: Logging enabled for Lambda function monitoring

## Features

- Rate-based protection: Blocks requests exceeding 2,000 requests per 5-minute window per IP
- CloudWatch monitoring for WAF metrics and Lambda logs
- Minimal operational overhead with Terraform-managed infrastructure
- Regional API Gateway endpoint for low latency

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Python 3.13 (for running the seed script)
- AWS region: ap-southeast-2 (configurable in `versions.tf`)

## Usage

### 1. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the infrastructure
terraform apply
```

After successful deployment, note the `api_gateway_url` output value.

### 2. Seed DynamoDB with Sample Data

Populate the DynamoDB table with initial product inventory:

```bash
# Export AWS credentials if not already set
export AWS_PROFILE=your-profile  # Optional: if using named profiles

# Run the seed script
python scripts/seed_dynamodb.py --table-name $(terraform output -raw dynamodb_table_name) --region ap-southeast-2
```

**Note**: If you get "command not found" for python, try `python3` instead:

```bash
python3 scripts/seed_dynamodb.py --table-name $(terraform output -raw dynamodb_table_name) --region ap-southeast-2
```

This script adds 5 sample products with different stock quantities and prices.

### 3. Test the API

#### Normal API Call

```bash
# Method 1: Get the API URL and append the query parameter
API_URL=$(terraform output -raw api_gateway_url)
curl "${API_URL}?product_id=PROD001"

# Method 2: Direct one-liner
curl "https://$(terraform output -raw api_gateway_id).execute-api.ap-southeast-2.amazonaws.com/dev/product-stock?product_id=PROD001"

# Method 3: Get all sample products
for product in PROD001 PROD002 PROD003 PROD004 PROD005; do
  echo "Testing $product:"
  curl -s "${API_URL}?product_id=${product}" | jq .
  echo ""
done

# Expected response:
# {"product_id": "PROD001", "product_name": "Laptop Pro 15", "stock_quantity": 45, "price": 1299.99}
```

#### Test Rate Limiting

The WAF rate-based rule limits requests to 2,000 per 5 minutes per IP. To demonstrate rate limiting by exceeding this threshold:

```bash
# Set API URL
API_URL=$(terraform output -raw api_gateway_url)

# Make 2100 requests all at once in parallel to exceed the 2000 request limit
echo "Making 2100 aggressive parallel requests to exceed rate limit..."
for i in {1..2100}; do
  curl -s -o /dev/null -w "%{http_code}\n" "${API_URL}?product_id=PROD001" 2>/dev/null &
done

# Wait for all requests to complete
wait

echo "Completed 2100 requests. Count unique status codes:"
curl -s -o /dev/null -w "%{http_code}\n" "${API_URL}?product_id=PROD001" | sort | uniq -c
```

**Expected behavior:**

- First 2,000 requests: Return 200 OK with product data
- Requests 2,001+: Return 403 Forbidden (blocked by WAF)
- After 5 minutes: Rate limit resets and requests are allowed again

### 4. Monitor CloudWatch

View logs and metrics:

```bash
# View Lambda logs
aws logs tail /aws/lambda/$(terraform output -raw lambda_function_name) --follow

# View WAF metrics (rate limit rule)
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name RateLimitRule \
  --dimensions Name=WebACL,Value=$(terraform output -raw waf_web_acl_id) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## Configuration Variables

Modify `variables.tf` to customize:

- `rate_limit`: Requests per 5-minute window (default: 2000)
- `stage_name`: API Gateway stage name (default: "dev")
- `environment`: Tag for resource organization (default: "demo")

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## How It Works

1. **Client Request**: Client sends GET request to API Gateway with `product_id` parameter
2. **WAF Protection**: AWS WAF rate-based rule checks if IP has exceeded rate limit
3. **Allowed Requests**: If within limit, request proceeds to API Gateway
4. **API Gateway**: Routes request to Lambda function with proxy integration
5. **Lambda Function**: Queries DynamoDB for product stock information
6. **Response**: Returns product details including stock quantity and price
7. **Blocked Requests**: Requests exceeding rate limit are blocked with 403 status

## Security Features

- **Rate-Based Rule**: Automatically blocks HTTP flood attacks from single IPs
- **IP-Based Tracking**: Each IP address tracked separately for rate limiting
- **No Operational Overhead**: Fully managed by AWS with automatic enforcement

## Sample Product IDs

The seed script creates these products:

- `PROD001`: Laptop Pro 15
- `PROD002`: Wireless Headphones
- `PROD003`: USB-C Hub
- `PROD004`: Mechanical Keyboard
- `PROD005`: Monitor 4K

Use any of these product IDs to test the API endpoint.

## License

MIT
