import boto3
import logging
import os

from botocore.exceptions import ClientError


logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

config_client = boto3.client("config")
s3_client = boto3.client("s3")
sns_client = boto3.client("sns")
config_rule_name = os.environ["RULE_NAME"]
topic_arn = os.environ['TOPIC_ARN']


def lambda_handler(event, context):
    """
     Main entrypoint for the lambda function. It does the following:
     - Check config for non compliant s3 bucket
     - Disable public access for s3 bucket
     - Send sns topic to team bout which s3 buckets that was remediate.
    """
    logger.info(f"Received event {event}, starting s3 public access "
                f"remediation")

    non_compliant_s3_buckets = get_non_compliant_s3_from_config()
    if non_compliant_s3_buckets:
        logger.info(f"Some buckets are not compliant, starting "
                    f"remediation now")
        for bucket in non_compliant_s3_buckets:
            put_public_access_block(bucket)

        sns_notifier(non_compliant_s3_buckets)

        logger.info(f"Public access block for s3 bucket is completed")
    else:
        logger.info(f"All Bucket are compliant no need to remediate")


def sns_notifier(bucket_names):
    try:
        subject = "Remediated S3 Buckets"
        message = f"The following bucket are no longer accessible " \
                  f"from public: {bucket_names}"
        __ = sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        logger.info(f"Successfully send sns topic message")
    except ClientError as e:
        logger.error(f"Failed to send sns topic because : {e}")


def get_non_compliant_s3_from_config():
    """
    This calls aws config to get non-compliant resources
    :return: list of s3 buckets that are not compliant or empty list
    """
    logger.info(f"Starting to get compliance details for config rule "
                f"{config_rule_name}")
    try:
        response = config_client.get_compliance_details_by_config_rule(
            ConfigRuleName=config_rule_name, ComplianceTypes=["NON_COMPLIANT"])
        return [resp["EvaluationResultIdentifier"]["EvaluationResultQualifier"]
                ["ResourceId"] for resp in response["EvaluationResults"]]
    except KeyError:
        logger.debug("All buckets are compliant")
        return []
    except ClientError as e:
        logger.error(f"Failed to send non compliant bucket because : {e}")
        raise


def put_public_access_block(s3_bucket_name):
    """
    This enable public access on s3 buckets
    :param s3_bucket_name: the name of the s3 bucket we want remediate
    :return: Null
    """
    logger.info(f"Starting to remediate public access for {s3_bucket_name}")
    __ = s3_client.put_public_access_block(
        Bucket=s3_bucket_name,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True
        })
    logger.info(f"Successfully remediate public access for {s3_bucket_name}")
