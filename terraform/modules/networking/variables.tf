variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "knowledge-base"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (2 AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (2 AZs)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway (only needed if services require outbound internet)"
  type        = bool
  default     = false
}

variable "vpn_egress_cidrs" {
  description = "Prisma Access VPN egress public IP CIDRs (restrict ALB inbound to these)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Override with actual VPN egress IPs in production
}
