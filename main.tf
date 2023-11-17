# Creating IAM role for the EKS cluster

data "aws_iam_policy_document" "assume_role" {
    statement {
        effect = "Allow"

        principals {
            type        = "Service"
            identifiers = ["eks.amazonaws.com"]
        }

        actions = ["sts:AssumeRole"]
    }
}

resource "aws_iam_role" "example" {
    name               = "eks-cluster-example"
    assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = aws_iam_role.example.name
}

# We are using the Default VPC and Subnets which is provided by AWS 

data "aws_vpc" "default" {
    default = true  
}

data "aws_subnets" "public" {
    filter {
        name = "vpc-id"
        values = [ data.aws_vpc.default.id ]
    }  
}


# Creating an EKS Cluster 

resource "aws_eks_cluster" "example" {
    name     = "EKS_Terraform"
    role_arn = aws_iam_role.example.arn

    vpc_config {
        subnet_ids = data.aws_subnets.public.ids
    }

    # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
    # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
    depends_on = [
        aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy
    ]
}

# Here we need to create an Node Groups and Attach it to the EKS Cluster

# Create an Iam Policy for the Node Group

resource "aws_iam_role" "Node_group" {
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

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role       = aws_iam_role.Node_group.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role       = aws_iam_role.Node_group.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role       = aws_iam_role.Node_group.name
}

# Creating an EKS Node Group  

resource "aws_eks_node_group" "example1" {
    cluster_name    = aws_eks_cluster.example.name
    node_group_name = "EKS_NG_Terraform"
    node_role_arn   = aws_iam_role.Node_group.arn
    
    subnet_ids      = data.aws_subnets.public.ids

    scaling_config {
        desired_size = 1
        max_size     = 2
        min_size     = 1
    }
    instance_types = [ "t2.micro" ]

    depends_on = [
        aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
        aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
        aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
    ]
}


