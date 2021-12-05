# Exchange Company Rate Getter
I am starting an Exchange Company, and I want to get the rate at which exchange rate fluctuates from USD to [Cad, Pounds, Naira]
I want to get and export of the exchange rate as a JSON output every hour into an S3 bucket.
I also want to be notified if this process fails.

# Suggested Solution
- EC2: Responsible for running a python script that will generate exchange rates and write the output into a JSON file and send that JSON file into s3(this must be done hourly)
- S3: JSON files of the exchange rate will be stored into s3 bucket.
- IAM: EC2 will need permission to write into the bucket where exchange rate JSON files will be stored.
- SNS: we will be sending a job failure or job success notification to the exchange team each time I successfully write into the bucket or each time the jobs fails.
- JOB failure will mean error encountered in the process any point in time.

# Solution Step

## How to set up AWS Resource
### Create SNS Topic and Subscribe
- From aws console
- search sns and click on Simple Notification Service
- Click Next Step / Create Topic
- Type: Standard
- Name : <Some name for topic> / ExchangeRateTopic
- Click Create topic
- After creating topic, we need to create subscription
    - Click Create Subscription
    - Topic ARN : By default the topic you just created but can change it if you want
    - Protocol : Email
    - Endpoint : an active email address
    - click Create subscription
- Go to you email and check for email from aws
- Click Confirm Subscription
### Create S3 Bucket
- From aws console
- search s3 and click on S3
- Click create bucket
  - Bucket Name : Some name for bucket
  - Region : Can remain in default
  - Block all public access : Yes
  - leave other settings as is
  - Click create bucket

### Creating EC2 
- From aws console
- search EC2 and click on EC2
- Click Launch Instance
  - Select Amazon Linux ( free tier eligible)
  - Instance Type : t2.micro (Free tier eligible)
  - Click configure Instance Details
    - IAM role : Click Create new IAM Role
      - In IAM Role Page 
        - Click Create role
        - Select EC2 instance 
        - Click Next: Permissions
          - Click Create New Policy
            - Policy for SNS
              - Service : SNS
              - Action : Expand Write :  Select Publish
              - Resources : Select SNS bucket arn that we created Earlier
            - Click Add Additional Permission
              - Policy for S3
                - Service : S3
                - Action : Expand Write :  Select PutObject
                - Resources : Select S3 bucket arn that we created Earlier
          - click Next: Tags
          - click Next: Review
          - Name : Give name to policy
          - Description: Policy to allow ec2 to publish message to SNS and upload object to s3
          - Click Create Policy
      - Search for new policies that you just created
      - Click next
      - Click Review 
      - Click create role
    - Select new Role that you just created
    - Upload user_data.sh in the User data section as File
  - Click Review and Launch
  - Click Launch
    - Click: Create a new key pair
    - Give it a name 
  - Click launch 
  - click view instance

## Deploying the code 

### Environment Variable needed
- API_KEY : Api key gotten from [exchangerate-api](https://www.exchangerate-api.com/) to make api calls to get rate
- BUCKET_NAME : Name of bucket that you want to save hourly rate
- TOPIC_ARN : Arn for topic that you want to send failure message to


### Cron Job to run script hourly
On the instance do the following 
- crontab -e
  - add this to the file 
    - 0 * * * * /usr/bin/python3 /home/ec2_user/python-job.py >> ~/cron.log 2>&1
  - esc :wq! and enter 
