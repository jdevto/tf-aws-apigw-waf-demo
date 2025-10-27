# Data source for current AWS region
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================
# DynamoDB Table
# ============================================
resource "aws_dynamodb_table" "product_inventory" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }

  tags = merge(
    local.tags,
    {
      Name = var.dynamodb_table_name
    }
  )
}

# ============================================
# IAM Role for Lambda
# ============================================
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${var.lambda_function_name}-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_function_name}",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_function_name}:*"
        ]
      },
      {
        Sid    = "AllowDynamoDBRead"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.product_inventory.arn
      }
    ]
  })
}

# ============================================
# Lambda Function
# ============================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/product_stock_handler.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "product_stock_handler" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "product_stock_handler.lambda_handler"
  runtime       = "python3.13"
  timeout       = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.product_inventory.name
    }
  }

  tags = merge(
    local.tags,
    {
      Name = var.lambda_function_name
    }
  )

}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 7

  tags = local.tags
}

# ============================================
# API Gateway REST API
# ============================================
resource "aws_api_gateway_rest_api" "product_stock_api" {
  name        = var.api_name
  description = "Product stock API protected by WAF rate limiting"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    local.tags,
    {
      Name = var.api_name
    }
  )
}

resource "aws_api_gateway_resource" "product_stock" {
  rest_api_id = aws_api_gateway_rest_api.product_stock_api.id
  parent_id   = aws_api_gateway_rest_api.product_stock_api.root_resource_id
  path_part   = "product-stock"
}

resource "aws_api_gateway_method" "product_stock_get" {
  rest_api_id   = aws_api_gateway_rest_api.product_stock_api.id
  resource_id   = aws_api_gateway_resource.product_stock.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.product_stock_api.id
  resource_id = aws_api_gateway_resource.product_stock.id
  http_method = aws_api_gateway_method.product_stock_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.product_stock_handler.invoke_arn
}

resource "aws_api_gateway_deployment" "dev" {
  rest_api_id = aws_api_gateway_rest_api.product_stock_api.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.dev.id
  rest_api_id   = aws_api_gateway_rest_api.product_stock_api.id
  stage_name    = var.stage_name

  tags = merge(
    local.tags,
    {
      Name = "${var.api_name}-${var.stage_name}"
    }
  )
}

# Lambda permission
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.product_stock_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.product_stock_api.execution_arn}/*/*"
}

# ============================================
# AWS WAF Web ACL
# ============================================
resource "aws_wafv2_web_acl" "api_gateway_waf" {
  name        = "${var.api_name}-waf"
  scope       = "REGIONAL"
  description = "WAF for API Gateway with rate-based rule"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.api_name}-WAF"
    sampled_requests_enabled   = true
  }

  tags = merge(
    local.tags,
    {
      Name = "${var.api_name}-waf"
    }
  )
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway_waf_association" {
  resource_arn = aws_api_gateway_stage.dev.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway_waf.arn
}
