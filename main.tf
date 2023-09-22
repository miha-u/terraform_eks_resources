terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


provider "aws" {
  region  = "eu-central-1"
  profile = "admin"

}


data "aws_availability_zones" "available" {}

variable "vpc_id" {
  default = "vpc-0d90afc5abbcc5374"
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_subnet" "in_secondary_cidr" {
  vpc_id            = data.aws_vpc.selected.id
  cidr_block        = "10.154.190.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_subnet" "in_secondary_cidr2" {
  vpc_id            = data.aws_vpc.selected.id
  cidr_block        = "10.154.191.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}
resource "aws_security_group" "eks_security_group" {
  name        = "eks_security_group"
  description = "Allow all inbound traffic for EKS cluster"
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "eks-iam-role" {
  name = "ekstf-iam-role"

  path = "/"

  assume_role_policy = <<POLICY
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "Principal": {
    "Service": "eks.amazonaws.com"
   },
   "Action": "sts:AssumeRole"
  }
 ]
}
POLICY
}



resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-iam-role.name
}


#resource "aws_eks_cluster" "ekstf-eks" {
#  name                      = "ekstf-cluster"
#  role_arn                  = aws_iam_role.eks-iam-role.arn
#  enabled_cluster_log_types = ["api", "audit"]
#
#
#
#  vpc_config {
#
#
#    subnet_ids = [
#      aws_subnet.in_secondary_cidr.id,
#      aws_subnet.in_secondary_cidr2.id
#    ]
#  }
#
#  depends_on = [
#
#    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy
#  ]


#}

resource "aws_iam_role" "workernodes" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workernodes.name
}

#resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
#  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
#  role       = aws_iam_role.workernodes.name
#}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workernodes.name
}


#
#resource "aws_eks_node_group" "worker-node-group" {
#  cluster_name    = aws_eks_cluster.ekstf-eks.name
#  node_group_name = "ekstf-workernodes"
#  node_role_arn   = aws_iam_role.workernodes.arn
#
#  subnet_ids      = [
#    aws_subnet.in_secondary_cidr.id,
#    aws_subnet.in_secondary_cidr2.id
#  ]
#
#  capacity_type = "ON_DEMAND"
#  instance_types = ["t3.small"]
#
#  scaling_config {
#    desired_size = 1
#    max_size     = 4
#    min_size     = 0
#  }
#  update_config {
#    max_unavailable = 1
#  }

#}



resource "aws_eks_cluster" "ekstf-eks" {
  name     = "ekstf-eks"
  role_arn = aws_iam_role.eks-iam-role.arn

  vpc_config {
    subnet_ids = [aws_subnet.in_secondary_cidr.id, aws_subnet.in_secondary_cidr2.id]
  }
}

resource "aws_eks_node_group" "worker_node_group" {
  cluster_name    = aws_eks_cluster.ekstf-eks.name
  node_group_name = "ekstf-workernodes"
  node_role_arn   = aws_iam_role.workernodes.arn
  subnet_ids      = [aws_subnet.in_secondary_cidr.id, aws_subnet.in_secondary_cidr2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }


  depends_on = [aws_eks_cluster.ekstf-eks]
}
