output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.product_stock_api.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${var.stage_name}/product-stock"
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.product_stock_api.id
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.api_gateway_waf.id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.api_gateway_waf.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.product_stock_handler.function_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.product_inventory.name
}

output "example_curl_commands" {
  description = "Example curl commands to test the API"
  value       = <<-EOT
# Set API_URL variable for easier usage:
export API_URL="https://${aws_api_gateway_rest_api.product_stock_api.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${var.stage_name}/product-stock"

# Test with sample product IDs:
curl "https://${aws_api_gateway_rest_api.product_stock_api.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${var.stage_name}/product-stock?product_id=PROD001"
curl "https://${aws_api_gateway_rest_api.product_stock_api.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${var.stage_name}/product-stock?product_id=PROD002"
curl "https://${aws_api_gateway_rest_api.product_stock_api.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${var.stage_name}/product-stock?product_id=PROD003"
  EOT
}
