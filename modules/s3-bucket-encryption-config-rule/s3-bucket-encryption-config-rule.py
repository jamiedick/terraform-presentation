import boto3
import botocore
import json
import logging
import sys

# Setup logger
log = logging.getLogger()
log.setLevel(logging.INFO)


class ComplianceEvaluation(object):

    def __init__(self, resourceType, resourceId, timestamp, ruleParameters, resultToken):
        
        # Set class variables
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.timestamp = timestamp
        self.resultToken = resultToken
        
        # Set class variables dependent on what config rule parameters are
        if ruleParameters['EncryptionType'] == 'SSE-S3':
            self.encryptionType = 'AES256'
            self.kmsKey = ''
        elif ruleParameters['EncryptionType'] == 'SSE-KMS':
            self.encryptionType = 'aws:kms'
            self.kmsKey = ruleParameters['KmsKey']
    

    def get_compliance(self):
        # Establish connection
        s3 = boto3.client('s3')

        # Query encryption details about s3 bucket 
        try:
            response = s3.get_bucket_encryption(
                Bucket=self.resourceId
            )   

        # Handle exceptions
        except Exception as e:
            # Handle exception if no encryption confirguation exists
            if str(e) == 'An error occurred (ServerSideEncryptionConfigurationNotFoundError) when calling the GetBucketEncryption operation: The server side encryption configuration was not found':
                log.info('Bucket {} does not have any encryption configuration on it, resource is not compliant'.format(self.resourceId))
                return {"compliance_type" : "NON_COMPLIANT", "annotation" : "There is no encryption configuration"}

            # Handle all other exceptions
            else:
                log.error('Ran into error trying to pull encryption data about S3 bucket {}'.format(self.resourceId))
                log.error('Error %s' % e)
                sys.exit(1)
      
        # Pull out encryption type from bucket response
        encryptionConfiguration = response['ServerSideEncryptionConfiguration']['Rules'][0]['ApplyServerSideEncryptionByDefault']
        
        # Evaluate compliance (check to make sure encryption on bucket matches standards from config rule)
        results = self.evaluate_compliance(encryptionConfiguration)
        
        return results


    def evaluate_compliance(self, encryptionConfiguration):
        # Both configurations are set to AES 256 and no KMS key is being used
        if encryptionConfiguration['SSEAlgorithm'] == self.encryptionType and self.kmsKey == '':
            log.info('Config rule configuration and bucket encryption configuration are aligned, resource is compliant')
            return {"compliance_type" : "COMPLIANT", "annotation" : "Bucket is configured with the correct encryption configuration"}
            
        # Both configurations are set to aws:kms and the same KMS key is being used
        elif encryptionConfiguration['SSEAlgorithm'] == self.encryptionType and encryptionConfiguration['KMSMasterKeyID'] == self.kmsKey:
            log.info('Config rule configuration and bucket encryption configuration are aligned, resource is compliant')
            return {"compliance_type" : "COMPLIANT", "annotation" : "Bucket is configured with the correct encryption configuration"}
        
        # Config rule parameter does not match the encryption type on the bucket
        elif encryptionConfiguration['SSEAlgorithm'] != self.encryptionType:
            log.info('Config rule configuration does not match encryption configuration, resource is not compliant')
            return {"compliance_type" : "NON_COMPLIANT", "annotation" : "Bucket encryption configuration is set to {}".format(encryptionConfiguration['SSEAlgorithm'])}
        
        # Config rule paramter for encryption type matches bucket encryption type but the bucket is using a different KMS Key
        elif encryptionConfiguration['SSEAlgorithm'] == self.encryptionType and encryptionConfiguration['KMSMasterKeyID'] != self.kmsKey:
            log.info('Config rule encryption type matches bucket encryption type but bucket is using a different KMS key to encrypt, resource is not compliant')
            return {"compliance_type" : "NON_COMPLIANT", "annotation" : "Bucket is using wrong KMS key: {}".format(encryptionConfiguration['KMSMasterKeyID'])}


    def put_evaluation(self, evaluation):
        # Establish connection
        config = boto3.client('config')
        
        # Put evaluation into config
        try:
            response = config.put_evaluations(
                Evaluations=[
                    {
                    'ComplianceResourceType': self.resourceType,
                    'ComplianceResourceId': self.resourceId,
                    'ComplianceType': evaluation['compliance_type'],
                    'Annotation': evaluation['annotation'],
                    'OrderingTimestamp': self.timestamp
                    },
                ],  
                ResultToken=self.resultToken
            )
            log.info('Successfully loaded compliance evaluation for bucket {}'.format(self.resourceId))
        
        # Handle exceptions
        except Exception as e:
            log.error('Ran into error trying to put config evaluation for bucket {}'.format(self.resourceId))
            log.error('Error %s' % e)
            sys.exit(1)
            

def lambda_handler(event, context):
    # Pull out relevant data from event
    invokingEvent = json.loads(event['invokingEvent'])
    resourceType = invokingEvent['configurationItem']['resourceType']
    resourceId = invokingEvent['configurationItem']['resourceId']
    timestamp = invokingEvent['configurationItem']['configurationItemCaptureTime']
    
    ruleParameters = json.loads(event['ruleParameters'])
    resultToken = event['resultToken']

    
    # Establish Class
    complianceEvaluator = ComplianceEvaluation(resourceType, resourceId, timestamp, ruleParameters, resultToken)

    # Evaluate compliance 
    evaluation = complianceEvaluator.get_compliance()
    
    # Put compliance evaluation into AWS Config
    complianceEvaluator.put_evaluation(evaluation)