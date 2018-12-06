import boto3
import logging
import sys
import json

# Setup logger
log = logging.getLogger()
log.setLevel(logging.INFO)


class BucketEncryption(object):    
    def __init__(self, event):
        # Set class variables
        try:
            self.resourceId = event['detail']['resourceId']
            self.compliance = event['detail']['newEvaluationResult']['complianceType']
            self.configRuleName = event['detail']['configRuleName']
            self.encryptionType = ''
            self.encryptionKey = ''

         # Handle exceptions
        except Exception as e:
            log.error("Failed to set values from event in constructor: %s" % e)
            sys.exit(1)


    def check_compliance_status(self):
        # Check for compliance type, if compliant, exit script
        if self.compliance == 'COMPLIANT':
            log.info('{} is already compliant with the config rule, exiting'.format(self.resourceId))
            sys.exit()


    def get_encryption_configuration(self):
        # Establish connection
        config = boto3.client('config')
        
        # Get encryption type and, if applicable, encryption key from config rule
        try:
            response = config.describe_config_rules(ConfigRuleNames=[self.configRuleName])
            
            # Load data into readable format
            inputParameters = json.loads(response['ConfigRules'][0]['InputParameters'])
            
            # Assign encryption type (& encryption key, if applicable) to class variables
            self.encryptionType = inputParameters['EncryptionType']
            if 'KmsKey' in inputParameters:
                self.encryptionKey = inputParameters['KmsKey']

        # Handle exceptions
        except Exception as e:
            log.error('Ran into error trying to get encryption configuration from config rule: {}'.format(self.configRuleName))
            log.error('Error %s: ' % e)
            sys.exit(1)


    def enable_encryption(self):
        # Establish connection
        s3 = boto3.client('s3')

        if self.encryptionType == 'SSE-S3':
            # Enable server side encryption with an S3 encryption key on the bucket
            try:
                response = s3.put_bucket_encryption(
                    Bucket=self.resourceId,
                    ServerSideEncryptionConfiguration={'Rules': [{'ApplyServerSideEncryptionByDefault': {'SSEAlgorithm': 'AES256'}}]}
                )
                log.info('Successfully enabled encryption on bucket {}'.format(self.resourceId))

            # Handle exceptions
            except Exception as e:
                log.error('Ran into issue enabling encryption on bucket {}'.format(self.resourceId))
                log.error('Error %s' % e)
                sys.exit(1)
        
        elif self.encryptionType == 'SSE-KMS':
            # Enable server side encryption with a specific KMS key on the bucket
            try:
                response = s3.put_bucket_encryption(
                    Bucket=self.resourceId,
                    ServerSideEncryptionConfiguration={'Rules': [{'ApplyServerSideEncryptionByDefault': {'SSEAlgorithm': 'aws:kms','KMSMasterKeyID': self.encryptionKey}}]}
                )
                log.info('Successfully enabled encryption on bucket {}'.format(self.resourceId))
                
            # Handle exceptions
            except Exception as e:
                log.error('Ran into issue enabling encryption on bucket {}'.format(self.resourceId))
                log.error('Error %s' % e)
                sys.exit(1)

            
def lambda_handler(event, context):
    # Establish class
    encrypter = BucketEncryption(event)

    # Check for compliance, if the resource is already compliant, exit script
    encrypter.check_compliance_status()
    
    # Check config rule for latest encryption configuration standards
    encrypter.get_encryption_configuration()

    # Enable encryption on the resource that was non compliant 
    encrypter.enable_encryption()

    

