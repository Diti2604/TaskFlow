# resource "aws_iam_role" "nodes" {
#   name = "eks-nodes-iam-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Sid    = ""
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       },
#     ]
#   })
# }

# #This policy allows Amazon EKS worker nodes to connect to Amazon EKS Clusters.
# resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.nodes.name
# }

# #This policy provides the Amazon VPC CNI Plugin the permissions it requires to modify the IP address configuration on your EKS worker node
# resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.nodes.name
# }
# #Enables us to pull docker images from ECR, Provides read-only access to Amazon EC2 Container Registry repositories
# resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.nodes.name
# }


# resource "aws_eks_node_group" "node_group_resource" {
#   cluster_name    = aws_eks_cluster.cluster1.name
#   node_group_name = var.node_group_name
#   node_role_arn   = aws_iam_role.nodes.arn
#   subnet_ids      = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count)

#   capacity_type  = "SPOT"
#   instance_types = ["t3.small"]

#   scaling_config {
#     desired_size = 1  
#     max_size     = 2  
#     min_size     = 1
#   }

#   update_config {
#     max_unavailable = 1
#   }

#   depends_on = [
#     aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
#     aws_iam_role_policy_attachment.amazon_eks_cni_policy,
#     aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
    
#   ]
# }