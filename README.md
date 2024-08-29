# ecr-cda-to-fhir-lambda
S3 Trigger to convert FHIR to CDA format


### Prerequisites:

1.  Java 17
2.  AWS SDK - STS or Eclipse
3.  AWS Account
4.  Maven 3.3.x
5.  GIT

## Clone the Repository

Clone the repository using the below command in command prompt

`git clone https://github.com/drajer-health/ecr-cda-to-fhir-lambda.git`

## Create Build:

Import Project as Maven Project Build:

Navigate to `ecr-cda-to-fhir-lambda` directory  `..../` and run Maven build to build lambda jar file.

```
$ mvn clean

$ mvn clean install
```

This will generate a war file under target/ecr-cda-to-fhir-lambda-1.0.0.jar.

## AWS Lambda

### Deploy eCR FHIR to CDA Lambda:

Login to your AWS Account

1.  Click on Services then select Lambda
    
2.  Click on Create Function
    
3.  Select "Author from Scratch" option
    
4.  Enter:
    

```
Function Name: ecrCDA-to-FHIR-lambda
Runtime: Java 17
Permissions: Create a new role with basic Lambda permissions or select your organization specific security
```
5. Click on "Create Function"


## At this point Lambda function would be created, navigate to the newly created function and configure the lambda function and environment variable.

1. Go to the newly created Role.

2. Under `Permissions` tab click on `Create inline Policy`

3. Click on `{ } JSON` tab and ad the following security policy. Replace the `SQS-NAME` with your SQS name.
	```
	{
    "Version": "2012-10-17",
    "Statement": [
            {
                "Sid": "Statement1",
                "Effect": "Allow",
                "Action": "sqs:ReceiveMessage",
                "Resource": "arn:aws:sqs:SQS-NAME"
            },
            {
                "Sid": "Statement2",
                "Effect": "Allow",
                "Action": "sqs:DeleteMessage",
                "Resource": "arn:aws:sqs:SQS-NAME"
            },
            {
                "Sid": "Statement3",
                "Effect": "Allow",
                "Action": "sqs:GetQueueAttributes",
                "Resource": "arn:aws:sqs:SQS-NAME"
            }
    ]
}
	``

4. Click on button `Next` 

5. Enter policy name `ecrCdaToFhirLamdaPolcy`

6. Click on `Create policy`

7. Come back to your AWS Lambda Function and navigate to `Configuration` tab.

8. Go to the `General Configuration` and click on `Edit` button. Increase the Timeout to minimum 1 minute. 

7.  Under the "Code" tab select "Upload from"

8. Select .zip or .jar file option.

9. Click upload and navigate to your local workspace target folder and select ecr-cda-to-fhir-lambda-1.0.1.jar and click "Save".

10. Click on "Edit" on "Runtime Settings".

11. Enter below value for Handler
    

```
com.drajer.ecr.cda2fhir.converter.CDA2FHIRConverterLambdaFunctionHandler::handleRequest

```
12.  Click "Save"
 
### Lambda Configuration
To process the file from the S3 bucket, lambda function needs to be configured to process from the specified folder. Add the ***Environment Variable*** to the lambda function specifying the S3 bucket folder name.

1.  Click on "Configuration" tab and then "Environment Variables" 

2.  Click on "Edit" to add new environment variable
    
3.  Click on "Add new environment variable"
    
4.  Enter
    

|Environment Variable| Value |
|--|--|
|BUCKET_NAME  | <- S3-FolderName ->  |


### Lambda Trigger
Lambda function needs to be triggered, for this we need to add and configure the trigger. Follow the following steps to add the trigger to your lambda function.
1. Go to you Lambda function

2. Click on `Add trigger`

3. From the `Trigger configuration` drop down select
    `SQS` option

4. From the `SQS queque` drop down select your SQS that this lambda function will listen.

6. Click Add.


### At this point the Lambda function is created and configured to listen to the S3 Bucket.

