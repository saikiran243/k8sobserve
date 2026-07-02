terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Minimal VPC for cost savings
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "enterprise-demo-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true # Saves ~$30/month vs multi-AZ NAT
  one_nat_gateway_per_az = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# 2. EKS Cluster with compute nodes optimized for the AI model


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "enterprise-gitops-demo"
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    
    # Node Group 1: The AI Worker (Strictly 1 node)
    ai_nodes = {
      min_size     = 1
      max_size     = 1
      desired_size = 1
      instance_types = ["t3.large"] # 2 vCPU, 8GB RAM (Costs ~$0.025/hr on SPOT)
      capacity_type  = "SPOT"
      
      # We label this node so we can force Ollama to run here
      labels = {
        workload = "ai-inference"
      }
    }

    # Node Group 2: The General Worker (For ArgoCD, Datadog, and Apps)
    general_nodes = {
      min_size     = 1
      max_size     = 2
      desired_size = 1
      instance_types = ["t3.small"] # 2 vCPU, 2GB RAM (Costs ~$0.006/hr on SPOT)
      capacity_type  = "SPOT"
      
      labels = {
        workload = "general-apps"
      }
    }
  }
}