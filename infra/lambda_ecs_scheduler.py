import boto3
import os
import json

def handler(event, context):
    """
    Lambda function to scale ECS service up/down on schedule
    Event format:
    {
        "action": "scale",
        "desired_count": 2
    }
    """
    
    cluster_name = os.environ['CLUSTER_NAME']
    service_name = os.environ['SERVICE_NAME']
    region = os.environ.get('REGION', os.environ.get('AWS_REGION', 'us-east-1'))
    
    ecs_client = boto3.client('ecs', region_name=region)
    
    try:
        action = event.get('action')
        desired_count = event.get('desired_count', 2)
        
        if action == 'scale':
            print(f"Scaling ECS service '{service_name}' in cluster '{cluster_name}'")
            print(f"Target desired count: {desired_count}")
            
            response = ecs_client.update_service(
                cluster=cluster_name,
                service=service_name,
                desiredCount=desired_count
            )
            
            print(f"Service updated successfully")
            print(f"New desired count: {response['service']['desiredCount']}")
            print(f"Running count: {response['service']['runningCount']}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Successfully scaled service to {desired_count} tasks',
                    'service': service_name,
                    'cluster': cluster_name,
                    'desired_count': response['service']['desiredCount'],
                    'running_count': response['service']['runningCount']
                })
            }
        else:
            raise ValueError(f"Unknown action: {action}")
            
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'cluster': cluster_name,
                'service': service_name
            })
        }
