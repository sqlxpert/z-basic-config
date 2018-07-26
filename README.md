# Basic Configuration Management System

Lets you:

1. Install **files**, set **permissions**, and remove files
3. Install and remove **operating system packages**
3. Restart **services** after the configuration and/or files have been changed
 
Operations are **idempotent**: you can repeat them without trigerring any further changes, other than the caching of the latest operating system package index.

## Instructions

1. Clone this repository on the local system from which you will access the AWS Web Console.

   ```
   git clone 'https://github.com/sqlxpert/basic-config.git'
   ```

2. Log in to the [AWS Console](https://console.aws.amazon.com/). If you log in as an IAM user (recommended), the IAM user must have sufficient privileges to create EC2, S3, IAM and CloudFormation resources, or you must switch to an IAM role with sufficient privileges.

3. Check that you are working in the desired AWS region.

4. Navigate to the [CloudFormation Console](https://console.aws.amazon.com/cloudformation/home).

5. Create a stack from the [`cloudformation/central.yaml`](/cloudformation/central.yaml) template. Choose whatever stack name you like. You must select a Virtual Private Cloud. Wait for stack creation to complete (green status). Check ConfigBucketName in the Outputs section and note the full name of the S3 bucket.

6. Create one stack from the [`cloudformation/instance-central.yaml`](/cloudformation/instance-central.yaml) template. Choose whatever stack name you like. Check the default parameter values. You must select a Subnet ID and type the name of an existing SSH keypair.

7. Create one stack from the [`cloudformation/instance-managed.yaml`](/cloudformation/instance-managed.yaml) template. Choose whatever stack name you like. Check the default parameter values. You must select a Subnet ID and type the name of an existing SSH keypair.

8. Navigate to the instance list in the [EC2 Console](https://console.aws.amazon.com/ec2/v2/home#Instances:search=config-;sort=tag:Name). Note the public IP addresses of the central instance and the first managed instance.

9. Log in to each instance and run the preliminary manual commands.

   On your local system, run `ssh -i PRIVATE_KEY_PATH ubuntu@PUBLIC_IP_ADDR`
   
   ```
   sudo apt-get update
   sudo apt-get --assume-yes install git
   cd ~
   rm --recursive --force basic-config
   git clone 'https://github.com/sqlxpert/basic-config.git'
   chmod a+x basic-config/script/*
   basic-config/script/bootstraph.bash
   ```

10. If you wish to use password authentication rather than public key authentication (not recommended), run the following commands on each instance. You will type the new password for user `ubuntu` twice, and then change PasswordAuthentication `yes` in the SSHD configuration file.

    ```
    sudo passwd ubuntu
    sudo vi /etc/ssh/sshd_config
    sudo systemctl reload sshd
    ```
    
    From now on, you may log in by running `ssh ubuntu@PUBLIC_IP_ADDR` on your local system, and typing the appropriate password.

11. Either create an Amazon Machine Image from the first managed instance and supply the AMI ID when you repeat Step 7, or repeat all of Steps 7 through 10 for each additional managed instance that you create.

12. Upload the sample configuration data from the central instance to S3. Specify the region in which you created the CloudFormation stacks, and specify the bucket name from Step 5.

    ```
    AWS_DEFAULT_REGION=REGION; export AWS_DEFAULT_REGION
    aws s3 cp basic-config/example/cfg 's3://BUCKET_NAME' --recursive
    ```

12. Set the `Profiles` tag of each managed instance to `php-nginx` to use that sample profile.

13. On each managed instance, apply the configuration. This command downloads the selected configuration profile from S3, installing operating system packages, populating files, creating symbolic links, and restarting services as instructed by the profile. Check the output for errors.

    ```
    basic-config/script/cfg-apply.bash BUCKET_NAME
    ```

14. In your Web browser, navigate to `http://PUBLIC_IP_ADDR` for each managed instance in turn. You should see a greeting.

15. To minimize AWS charges, delete the EC2 instance stacks as soon as possible. (You may also wish to delete the initial stack, but note that the IAM policies, instance roles/profiles, and security groups that it contained must be deleted manually.)

## Configuration Data Format

Configurations are stored as a hierarchy of files. Path components shown here in capital letters are variable; path components shown here in lowercase letters are fixed.

```
profile/
  PROFILE_NAME/
    pkg/
      ITEM_NAME/
        metadata.json
    file/
      ITEM_NAME/
        metadata.json
        source
    link/
      ITEM_NAME/
        metadata.json
    svc/
      ITEM_NAME/
        metadata.json
```

* Configuration files are stored centrally, in S3. S3 allows white space and other dangerous characters in object keys, but the use of any characters other than letters, numbers, hyphens and underscores can cause errors in `cfg-apply.bash`.

* Every profile has a human-readable logical identifier (profile name). To apply more than one profile to the same managed EC2 instance, separate multiple profile names with spaces, in the instance's `Profiles` tag.

* Every configuration item has a human-readable logical identifier (item name).

* Because no formal dependency system is supported, profiles are applied in the order in which they are listed in the `Profiles` tag; item types are processed in a fixed, practial order (install packages ⟶ populate file  ⟶ create symbolic links ⟶ restart services); and items of a given type are processed in alphabetical order by item name. To control processing order within a given item type, prepend numbers to the item names.

* Each item has a JSON metadata file, which must contain an object. All values are quoted strings of one or more of: the letters `a` through `z` and `A` through `Z` , the numbers `0` through `9` , and certain other characters, `-` `_` `.` `,` `+` `=`  `/`

  Keys required for all item types:
  
  |Type|`action` values|`id` value|
  |--|--|--|
  |`pkg`|`install` `remove`|Exact name of operating system package (e.g., `gcc4.8` instead of `gcc`) to be installed or removed|
  |`file`|`overwrite` `delete`|Full pathname of file to be created/overwritten or deleted|
  |`link`|`overwrite` `delete`|Full pathname of link to be created/overwritten or deleted|
  |`svc`|`reload` `restart`|Exact name of service to be reloaded or restarted|

  Additional keys required for specific combinations of item type and action:
  
  |Type|Action|Additional required key(s)|
  |--|--|--|
  |`file`|`overwrite`|`user` `group` `mode`|
  |`svc`|`overwrite`|`target`|

* Each file item also requires a `source` file, which contains the contents of the file.

## Triggering Updates

1. Upload new configuration data to S3.

2. Run `basic-config/script/cfg-apply.bash BUCKET_NAME` on each managed instance. Changes to any component of a profile -- package specifications, files (specification or contents), symbolic link specifications, or service specifications -- will be carried out and services will be reloaded or restarted.

## Architectural Decisions

Dependence on AWS S3 (and other AWS facilities) was a deliberate architectural choice. For a basic configuration management tool, a centralized object store solves a number of practical and security-related problems.

|AWS Service|Feature|Benefits|
|--|--|--|
|S3|Object storage|Centralized storage of configuration data|
|S3|Versioning|Retention of old configuration data|
|EC2|Instance tags|Selection of configuration profile(s) for particular EC2 instances; standard identification of each instance's purpose|
|IAM|EC2 instance roles and IAM policies|Access to centralized configuration data without locally-stored credentials; restrictions on which instances can read which configuration profile(s)|
|IAM|IAM users and IAM policies|Control of write access to configuration data|
|S3|Encryption at rest|Encryption of some or all centrally-stored configuration data, for additional control (not demonstrated); N.B.: the S3 API encrypts all data in transit|

## Commentary

This is a demonstration, developed quickly for a particular organization. It should never be used for production. 

This assignment was of limited relevance to operations because, at a fundamental level, it involved writing an interpreter. In the following transformations, the choice of any particular LHS (left-hand side) syntax is completely irrelevant to the resulting shell command:

 * _install packages_ `php5 nginx` ⟶ `apt-get --assume-yes install php5 nginx`
 
 * _remove packages_ `perl-dev` ⟶ `apt-get --assume-yes remove libperl-dev`
 
 * _set owner of file_ `my-file` _to_ `my-user` ⟶ `chown my-file my-user`

 * _populate file_ `my-file` _with_ `my-file-contents` ⟶
 
   ```
   cat << 'EOF' > my-file
   my-file-contents
   EOF
   ```
   
   (Note the obvious command injection risk, which would have to be mitigated.)

Instead of implementing a small subset of the features of Salt, Ansible, Puppet, or Chef without the _semantics_ that make those products useful (for example, the ability to specify popular packages without worrying which Linux distribution is present on a given managed system, the ability to apply configuration changes in order, based on formal dependencies, and the possibility that dependency logic will catch configuration profile errors such as deletion of a Linux user who still owns files tracked by the configuration management system), it might be preferable to demonstrate how one or more existing products could be used to solve a specific configuration problem.

I will add that this assignment included Trojan horse requirements. I dismiss one case, service restart after operating system package updates, in a comment inside [`script/cfg-apply.bash`](/script/cfg-apply.bash).

I will describe another case here. The requirement to be able to set a file's owner looks harmless, but what if the intended owner does not yet exist and has not been created by an operating system package? The requirement to be able to add a user is implied. The idempotence requirement then compels support for user modification. Altough Linux distributions include idempotent package management commands (for example, if the latest version of a package is already present, `apt-get install` will not re-install that package), the leading distributions lack idempotent user management commands. This adds a requirement to query the list of users and generate either a `useradd` or `usermod` command. As those of us with relational database experience realize from comparing endless shoddy attempts to implement "upsert" functionality against reliable solutions such as PostgreSQL's (non-standard SQL) `insert ... on conflict ... do update` or Oracle's (standard SQL) `merge`, differentiating between creation and modification adds a locking requirement. In this way, a seemingly simple requirement prompts lots of engineering or, more typically, leads to an incorrect implementation that will fail intermittently.

In fairness, Trojan horse requirements are common in real-world projects, especially when people responsible for strategy, product management, design, marketing and sales forget to talk with implementers. The classic example is the tree swing cartoon:

![Tree swing cartoon](https://fisher.osu.edu/blogs/gradlife/files/Lack-Of-Working-Link.jpg)

In case the linked image is unavailable, a Web search will turn up [many other examples](https://duckduckgo.com/?ia=images&q=tree+swing+cartoon).

---

Paul Marcelin | <marcelin@alumni.cmu.edu> | July, 2018
