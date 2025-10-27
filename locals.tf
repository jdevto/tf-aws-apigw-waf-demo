locals {
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "API-Gateway-WAF-Demo"
  }
}
