variable "rate_limit" {
  description = "Rate limit for the WAF rate-based rule (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "dev"
}

variable "api_name" {
  description = "Name for the API Gateway REST API"
  type        = string
  default     = "product-stock-api"
}

variable "lambda_function_name" {
  description = "Name for the Lambda function"
  type        = string
  default     = "product-stock-handler"
}

variable "dynamodb_table_name" {
  description = "Name for the DynamoDB table"
  type        = string
  default     = "product-inventory"
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "demo"
}
