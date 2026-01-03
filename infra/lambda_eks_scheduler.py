# import boto3
# import os
# import json

# def handler(event, context):
#     """
#     Lambda function to scale EKS node group up/down on schedule
#     Event format:
#     {
#         "action": "scale",
#         "desired_size": 1,
#         "min_size": 1,
#         "max_size": 2
#     }
#     """
    
#     cluster_name = os.environ['CLUSTER_NAME']
#     node_group_name = os.environ['NODE_GROUP_NAME']
#     region = os.environ.get('AWS_REGION', 'us-east-1')
    
#     eks_client = boto3.client('eks', region_name=region)
    
#     try:
#         action = event.get('action')
#         desired_size = event.get('desired_size', 1)
#         min_size = event.get('min_size', 1)
#         max_size = event.get('max_size', 2)
        
#         if action == 'scale':
#             print(f"Scaling node group '{node_group_name}' in cluster '{cluster_name}'")
#             print(f"Target: desired={desired_size}, min={min_size}, max={max_size}")
            
#             response = eks_client.update_nodegroup_config(
#                 clusterName=cluster_name,
#                 nodegroupName=node_group_name,
#                 scalingConfig={
#                     'minSize': min_size,
#                     'maxSize': max_size,
#                     'desiredSize': desired_size
#                 }
#             )
            
#             print(f"Update initiated: {response['update']['id']}")
#             print(f"Status: {response['update']['status']}")
            
#             return {
#                 'statusCode': 200,
#                 'body': json.dumps({
#                     'message': f'Successfully scaled node group to {desired_size} nodes',
#                     'update_id': response['update']['id'],
#                     'status': response['update']['status']
#                 })
#             }
#         else:
#             raise ValueError(f"Unknown action: {action}")
            
#     except Exception as e:
#         print(f"Error: {str(e)}")
#         return {
#             'statusCode': 500,
#             'body': json.dumps({
#                 'error': str(e)
#             })
#         }
