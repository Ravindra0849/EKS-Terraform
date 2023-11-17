# Here Iam creating the EKS cluster using Terraform

Let's break down the Terraform configuration code into simpler terms:

AWS IAM Role for EKS Cluster:

This section creates an IAM (Identity and Access Management) role for your EKS cluster.

The role allows the EKS service to assume it, which means EKS can perform certain actions using this role.

The role is attached to a policy named "AmazonEKSClusterPolicy."

Default VPC and Public Subnets:

Here, we retrieve information about the default VPC and its public subnets.

The default VPC is where your EKS cluster will be deployed.

We identify the public subnets within the VPC.

AWS EKS Cluster:

This part creates the EKS cluster itself.

It uses the IAM role created earlier and deploys the cluster in the default VPC's public subnets.

IAM Role for EKS Node Group:

Another IAM role is created, which is meant for the worker nodes in your EKS cluster.

This role allows EC2 instances (worker nodes) to communicate with the EKS cluster.

Attachment of Policies:

Various policies, such as "AmazonEKSWorkerNodePolicy," "AmazonEKS_CNI_Policy," and "AmazonEC2ContainerRegistryReadOnly," are attached to the worker node role.

These policies grant permissions to the worker nodes for necessary actions.

Managed Node Group:

The EKS node group represents the worker nodes in your cluster.

It specifies the desired number of nodes, instance types, and other configurations.

The group is associated with the EKS cluster, the role of worker nodes, and the public subnets.

In vs code use the below commands to provision

    - terraform init
    - terraform validate
    - terraform plan
    - terraform apply

==> First we need to create an Iam role for the EKS Cluster.
The code will be

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

==> We are using the Default VPC and Subnets which is provided by AWS 

data "aws_vpc" "default" {
    default = true  
}

data "aws_subnets" "public" {
    filter {
        name = "vpc-id"
        values = [ data.aws_vpc.default.id ]
    }  
}


==> After this we need to provide the EKS cluster  details as

resource "aws_eks_cluster" "example" {
    name     = "EKS_Terraform"
    role_arn = aws_iam_role.example.arn

    vpc_config {
        subnet_ids = data.aws_subnets.public.ids
    }
    
    depends_on = [
        aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy
    ]
}

# Here we need to create an Node Groups and Attach it to the EKS Cluster

==> Create an Iam Policy for the Node Group

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
    role       = aws_iam_role.Node_groupe.name
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

resource "aws_eks_node_group" "example" {
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

* https://mrcloudbook.hashnode.dev/provisioning-aws-eks-with-terraform-a-step-by-step-guide