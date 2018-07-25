# Sample configuration profiles

## Instructions

These instructions refer to the `php-nginx` sample profile; you may change this to a different sample profile (if available). You must change _BUCKET_NAME_ to the name of the S3 bucket where you store configuration data.

1. Temporarily attach an S3 upload IAM policy to EC2 instance role for the instance from which you will upload the sample files. Uploading from a non-EC2 system requires attaching the policy to the IAM user whose AWS API key you will use. Sample policy:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "s3:PutObject",
         "Resource": "arn:aws:s3:::BUCKET_NAME/profile/*"
       }
     ]
   }
   ```

2. Upload the contents of the sample profile folder to `s3://BUCKET_NAME/profile/php-nginx`

   The [AWS Command-Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/installing.html), which can be installed on EC2 instances and non-EC2 systems alike, provides a convenient upload mechanism. Sample command:

   ```bash
   # aws configure  # For a non-EC2 system only!
   cd example/cfg
   aws s3 cp php-nginx 's3://BUCKET_NAME/profile/php-nginx' --recursive
   ```

3. Detach the S3 upload IAM policy from the EC2 instance role or IAM user.

4. Check that an S3 list and download IAM policy is attached to the EC2 instance role for each managed instance. Sample policy:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "s3:ListBucket",
         "Resource": "arn:aws:s3:::BUCKET_NAME"
       },
       {
         "Effect": "Allow",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::BUCKET_NAME/profile/*"
       }
     ]
   }
   ```

5. Add `php-nginx` to the `Profile` tag of each managed EC2 instance. Separate multiple profile names with spaces.

6. Apply the profile(s) by running [`script/cfg-apply.bash`](/script/cfg-apply.bash) on each managed instance.
