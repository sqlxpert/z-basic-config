# Sample configuration profiles

## Instructions

These instructions refer to the `php-nginx` sample profile; you may change this to a different sample profile (if available). You must change _BUCKET_NAME_ to the name of the S3 bucket where you store configuration data. The IAM policies are supplied in the [cloudformation/central.yaml](/cloudformation/central.yaml) template, but their full names will be determined by AWS CloudFormation and will vary.

1. Temporarily attach the Config**Manage**Policy IAM policy to the EC2 instance role for the instance from which you will upload the sample files. Uploading from a non-EC2 system requires attaching the policy to the IAM user whose AWS API key you will use.

2. Upload the contents of the sample profile folder to `s3://BUCKET_NAME/profile/php-nginx`

   The [AWS Command-Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/installing.html), which can be installed on EC2 instances and non-EC2 systems alike, provides a convenient upload mechanism. Sample command:

   ```bash
   # aws configure  # For a non-EC2 system only!
   cd example/cfg
   aws s3 cp profile/php-nginx 's3://BUCKET_NAME/profile/php-nginx' --recursive
   ```

3. Detach the Config**Manage**Policy IAM policy from the EC2 instance role or IAM user.

4. Check that the Config**Apply**Policy IAM policy is attached to the EC2 instance role for each managed instance. Sample policy:

5. Add `php-nginx` to the `Profiles` tag of each managed EC2 instance. Separate multiple profile names with spaces.

6. Apply the profile(s) by running [`script/cfg-apply.bash`](/script/cfg-apply.bash)` BUCKET_NAME` on each managed instance.
