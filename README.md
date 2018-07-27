# Basic Configuration Management System

Lets you:

1. Install **files**, set **permissions**, and remove files
3. Install and remove **operating system packages**
3. Restart **services** after the configuration and/or files have been changed
 
Operations are **idempotent**: you can repeat them without trigerring any further changes, other than the caching of the latest operating system package index.

## Instructions

1. Clone to the local system from which you will access the AWS Web Console.

   ```
   git clone 'https://github.com/sqlxpert/basic-config.git'
   ```

2. Log in to the [AWS Console](https://console.aws.amazon.com/). If you log in as an IAM user (recommended), the IAM user must have sufficient privileges to create, describe, modify, and delete EC2, S3, IAM and CloudFormation resources, or you must switch to an IAM role with sufficient privileges.

3. Check that you are in the desired AWS region.

4. Navigate to [CloudFormation](https://console.aws.amazon.com/cloudformation/home).

5. Create a stack from the [`cloudformation/central.yaml`](/cloudformation/central.yaml) template. Choose whatever stack name you like. You must select a Virtual Private Cloud. Wait for stack creation to complete (green status). Check ConfigBucketName in the Outputs section and note the full name of the S3 bucket.

6. Create one stack from the [`cloudformation/instance-central.yaml`](/cloudformation/instance-central.yaml) template. Choose whatever stack name you like. Check the default parameter values. You must select a Subnet ID and type the name of an existing SSH keypair.

7. Create one stack from the [`cloudformation/instance-managed.yaml`](/cloudformation/instance-managed.yaml) template. Choose whatever stack name you like. Check the default parameter values. You must select a Subnet ID and type the name of an existing SSH keypair.

8. Navigate to the [EC2 instance list](https://console.aws.amazon.com/ec2/v2/home#Instances:search=config-;sort=tag:Name). Note the public IP addresses of the new instances.

9. Log in to each instance and run the preliminary manual commands.

   From your local system, run `ssh -i PRIVATE_KEY_FILE ubuntu@PUBLIC_IP_ADDR`
   
   ```bash
   sudo apt-get update
   sudo apt-get --assume-yes install git
   cd ~
   rm --recursive --force basic-config
   git clone 'https://github.com/sqlxpert/basic-config.git'
   chmod a+x basic-config/script/*
   basic-config/script/bootstrap.bash
   ```

10. If you wish to use password authentication (not recommended) rather than public key authentication, run the following commands on each instance. Type the new password for user `ubuntu` twice, and switch PasswordAuthentication to `yes` in the SSHD configuration.

    ```bash
    sudo passwd ubuntu
    sudo vi /etc/ssh/sshd_config
    sudo systemctl reload sshd
    ```

    From now on, you may log in by running `ssh ubuntu@PUBLIC_IP_ADDR` from your local system, and typing the appropriate password.

11. Either create an Amazon Machine Image from the first managed instance and supply the AMI ID when you repeat Step 7, or repeat all of Steps 7 through 10 for each additional managed instance that you create.

12. Upload the sample configuration data from the central instance to S3. Specify the region in which you created the CloudFormation stacks, and specify the bucket name from Step 5.

    ```bash
    AWS_DEFAULT_REGION=REGION; export AWS_DEFAULT_REGION
    aws s3 cp basic-config/example/cfg 's3://BUCKET_NAME' --recursive
    ```

12. Set the `Profiles` tag of each managed instance to `php-nginx` to configure a basic Nginx Web server with PHP support.

13. On each managed instance, apply the configuration. This script downloads the selected profile from S3, installing operating system packages, populating files, creating symbolic links, and restarting services as instructed by the profile. Check the output for errors.

    ```bash
    basic-config/script/cfg-apply.bash BUCKET_NAME
    ```

14. In your Web browser, navigate to `http://PUBLIC_IP_ADDR` for each managed instance in turn. You should see a greeting.

15. To minimize AWS charges, delete all stacks as soon as possible. The first stack can only be deleted after there are no more references to its policies, instance roles/profiles, or security groups, and its S3 bucket is empty (warning: deleting objects in the S3 Console does not automatically delete old object versions).

## Configuration Data Format

Configurations are a hierarchy of files. Path components shown below in capital letters are variable; lowercase components are fixed.

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

* Configuration files are stored centrally, in S3. S3 allows white space and other dangerous characters in object keys, but the use of any characters other than letters, numbers, hyphens, underscores and periods can cause errors in `cfg-apply.bash`.

* Every profile has a human-readable logical identifier (profile name). To apply more than one profile to the same managed EC2 instance, separate multiple profile names with spaces, in the instance's `Profiles` tag.

* Every item has a human-readable logical identifier (item name).

* Because no formal dependency system is provided, profiles are applied in the order in which they appear in the `Profiles` tag; item types are processed in a fixed, practial order (install packages ⟶ populate files ⟶ create symbolic links ⟶ restart services); and items of the same type are processed in alphabetical order by item name. Prepend numbers to item names to control processing order within an item type.

* Each item has a metadata file, which must contain a JSON object. All values are quoted strings of at least one of: the letters `a` through `z` and `A` through `Z` , the numbers `0` through `9` , and certain other characters, `-` `_` `.` `,` `+` `=`  `/`

  Keys required for all item types:
  
  |Type|`action` values|`id` value|
  |--|--|--|
  |`pkg`|`install` `remove`|Exact name of operating system package (e.g., `gcc4.8` instead of `gcc`) to be installed or removed|
  |`file`|`overwrite` `delete`|Full pathname of file to be created/overwritten or deleted|
  |`link`|`overwrite` `delete`|Full pathname of link to be created/overwritten or deleted|
  |`svc`|`reload` `restart`|Exact name of service to be reloaded or restarted|

  Additional keys required for specific item type + action combinations:
  
  |Type|Action|Additional required key(s)|Notes|
  |--|--|--|--|
  |`file`|`overwrite`|`user` `group` `mode`|User and group must already exist. Use symbolic modes, which are always easy to interpret.|
  |`link`|`overwrite`|`target`|Target is the full pathname of the file to which the symbolic link points (the real file, in other words).|

* Each file item also requires a `source` file, which contains the contents of the file.

## Triggering Updates

1. Upload new configuration files to S3. See Step 12 in the [Instructions](#instructions), above.

2. Run `cfg-apply.bash` on each managed instance. See Step 13.

3. Changes that you have made to any item -- package metadata, files (metatdata or contents), symbolic link metadata, or service metadata -- will be carried out and services will be restarted.

## Architectural Decisions

* Dependence on AWS S3 (and other AWS facilities) was a deliberate choice. For a basic configuration management system, a central object store solves many practical and security-related problems.

  |AWS Service|Feature|Benefits|
  |--|--|--|
  |S3|Object storage|Centralized storage of configuration data|
  |S3|Versioning|Retention of old configuration data|
  |EC2|Instance tags|Selection of configuration profile(s) for particular EC2 instances; standard identification of each instance's purpose|
  |IAM|EC2 instance roles and IAM policies|Access to centralized configuration data without locally-stored credentials; restrictions on which instances can read which configuration profile(s)|
  |IAM|IAM users and IAM policies|Control of write access to configuration data|
  |S3|Encryption at rest|Encryption of some or all centrally-stored configuration data, for additional control (not demonstrated); N.B.: the S3 API encrypts all data in transit|

* I avoided using extensive parsing -- least of all the parsing of a giant, hierarchical configuration cookbook. I did not want to devise a new programming language or specification language!

* I chose the shell over a full programming language, because system calls comprise most of the activity.

* You will notice the influence of SaltStack, which is my favorite configuration management system.

## Commentary

I developed this demonstration quickly, for a particular organization. It should not be used for production. 

The project turned out to be of limited relevance to operations work because, at a fundamental level, it involved writing an interpreter. In the following transformations, the choice of any particular LHS (left-hand side) syntax is completely irrelevant to the resulting shell command:

 * _install packages_ `php5 nginx` ⟶ `apt-get --assume-yes install php5 nginx`
 
 * _remove packages_ `perl-dev` ⟶ `apt-get --assume-yes remove libperl-dev`
 
 * _set owner of file_ `my-file` _to_ `my-user` ⟶ `chown my-file my-user`

 * _populate file_ `my-file` _with_ `my-file-contents` ⟶
 
   ```bash
   cat << 'EOF' > my-file
   my-file-contents
   EOF
   ```
   
   (Note the obvious command injection risk, which would have to be mitigated.)

Instead of implementing a small subset of the features of SaltStack, Ansible, Puppet, or Chef without the rich _semantics_ that make those products useful (for example, the ability to specify popular packages without worrying which Linux distribution is present on a given managed system, the ability to apply configuration changes in order, based on formal dependencies, and the possibility that dependency logic will catch configuration specification errors such as deletion of a Linux user who still owns files tracked by the configuration management system), it might be instructive to demonstrate how one or more existing products can be used to solve a configuration problem.

I will add that this project included Trojan horse requirements. I dismiss one, service restart after operating system package updates, in a comment in [`script/cfg-apply.bash`](/script/cfg-apply.bash).

I will describe another case here. The requirement to be able to set a file's owner looks harmless, but what if the intended owner does not yet exist and is not created by an operating system package? The requirement to be able to add a user is implied. The idempotence requirement then compels support for user modification. Altough Linux distributions include idempotent package management commands (for example, if the latest version of a package is already present, `apt-get install` will not re-install that package), the leading distributions lack idempotent user management commands. This adds a requirement to query the list of users and generate either a `useradd` or `usermod` command. As those of us with relational database experience realize from comparing endless shoddy attempts to implement "upsert" functionality against reliable solutions such as PostgreSQL's (non-standard SQL) `insert ... on conflict ... do update` or Oracle's (standard SQL) `merge`, differentiating between creation and modification adds a locking requirement. In this way, a seemingly simple requirement prompts lots of engineering or, more typically, leads to an incorrect implementation that will fail intermittently.

In fairness, Trojan horse requirements are common in real-world projects, especially when people responsible for strategy, product management, design, marketing and sales write specifications without involving implementers. The classic example is the tree swing cartoon:

![Tree swing cartoon](https://fisher.osu.edu/blogs/gradlife/files/Lack-Of-Working-Link.jpg)

In case the linked image is unavailable, a Web search will turn up [many other examples](https://duckduckgo.com/?ia=images&q=tree+swing+cartoon).

---

Paul Marcelin | <marcelin@alumni.cmu.edu> | July, 2018
