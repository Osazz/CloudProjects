#!/bin/bash

pip3 install requests
pip3 install boto3

# Copy python code to EC2
cat > /home/ec2-user/rate_getter.py << EOF
import requests
import logging
import os
import boto3
import json
import time

from botocore.exceptions import ClientError

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client("s3", region_name="us-east-1")
sns_client = boto3.client("sns", region_name="us-east-1")

FAILED_PROCESS = []


def sns_notifier(message, arn_topic):
    try:
        subject = "Exchange Rate Process Failure"
        __ = sns_client.publish(
            TopicArn=arn_topic,
            Subject=subject,
            Message=message
        )
        logger.info(f"Successfully send sns topic message")
    except ClientError as e:
        logger.error(f"Failed to send sns topic because : {e}")
        raise


def rate_getter(apikey):
    logger.info(f"Starting to get exchange rates")
    url = f"https://v6.exchangerate-api.com/v6/{apikey}/latest/USD"

    response = requests.get(url)
    data = response.json()
    if data["result"] == "success":
        return data["conversion_rates"]

    logger.error("Failed to get exchange rate")
    FAILED_PROCESS.append("RATE_GETTER")


def upload_rate_to_s3(json_object, remote_key, bucket_name):
    try:
        logger.info(f"Uploading rate to {remote_key}")
        s3_client.put_object(
            Body=json.dumps(json_object),
            Bucket=bucket_name,
            Key=remote_key
        )
        logger.info("Successfully uploaded rate")
    except ClientError as e:
        logger.error(e)
        FAILED_PROCESS.append("UPLOADER_PROCESS")


def create_remote_key(bucket_prefix):
    time_t = time.strftime('%Y_%m_%d_%H')
    logger.info(f"Create remote key path for {time_t}")
    try:
        return f"{bucket_prefix}/exchange_rate_{time_t}.json"
    except Exception as e:
        logger.error(e)
        FAILED_PROCESS.append("REMOTE_KEY_GENERATOR")


def generate_message(msg):
    logger.info(f"Starting to generate the right message for failure")
    if msg == "REMOTE_KEY_GENERATOR":
        return "Failure when generating remote name, please investigate"
    if msg == "UPLOADER_PROCESS":
        return "Problem uploading rate to S3, please investigate"
    if msg == "RATE_GETTER":
        return "Problem getting rate, please investigate"


if __name__ == '__main__':
    # currency we care about 'NGN', 'CAD', 'EUR'
    api_key = "55cd17ad2208ea25d6449e7e"
    bucket = "arn:aws:sns:us-east-1:847881920253:ExchangeRateTopic"
    topic_arn = "artifactory-prod-backup-work"
    prefix = "exchange_rate"
    rates = rate_getter(apikey=api_key)
    result_object = {"CAD": rates["CAD"], "NGN": rates["NGN"], "EUR": rates["EUR"]}
    upload_rate_to_s3(result_object, create_remote_key(prefix), bucket)

    # Check if failure and send message if any
    if FAILED_PROCESS:
        for process in FAILED_PROCESS:
            sns_notifier(generate_message(process), topic_arn)
EOF

chmod +x /home/ec2-user/rate_getter.py

##write out current crontab
#crontab -l > mycron
##echo new cron into cron file
#echo "#0 * * * * /usr/bin/python3 /home/ec2-user/rate_getter.py >> ~/cron.log 2>&1" >> mycron
##install new cron file
#crontab mycron
#rm mycron
