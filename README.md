[![](https://img.shields.io/badge/Available-serverless%20app%20repository-blue.svg)](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:665331858954:applications/lambda-layer-cfncli)



# AWS Lambda Layer for CloudFormation CLI with Python3

This repo builds the latest `cfn-cli` with python3 into AWS Lambda Layer and publishes to [AWS SAR](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:665331858954:applications/lambda-layer-cfncli).


## CDK Sample


```typescript
const samApp = new sam.CfnApplication(this, 'SamLayer', {
  location: {
    applicationId: 'arn:aws:serverlessrepo:us-east-1:665331858954:applications/lambda-layer-cfncli',
    semanticVersion: '0.1.2'
  },
  parameters: {
    LayerName: `${this.stackName}-cfncli-lambdaLayer`
  }
});

const layerVersionArn = samApp.getAtt('Outputs.LayerVersionArn').toString();

const handler = new lambda.Function(this, 'Func', {
  code: lambda.AssetCode.fromInline(`
import rpdk.core, json
def handler(event, context):
  return {
    'statusCode': 200,
    'body': json.dumps(rpdk.core.__version__)
  }`
  ),
  runtime: lambda.Runtime.PYTHON_3_7,
  handler: 'index.handler',
  layers: [
    lambda.LayerVersion.fromLayerVersionArn(this, 'Layer', layerVersionArn)
  ]
});

new apigateway.LambdaRestApi(this, 'Api', {
  handler
});

new cdk.CfnOutput(this, 'LayerVersionArn', {
  value: layerVersionArn
});
```

View full sample at [play-with-cdk](https://play-with-cdk.com?s=43320707911576c7a2007b5ced99f01c)
