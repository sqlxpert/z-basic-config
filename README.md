# Basic Configuration Management Tool

Lets you:

1. Install **files**, set **permissions**, and remove files
3. Install and remove **operating system packages**
3. Restart **services** after designated packages or files have been updated
 
Operations are **idempotent**: you can repeat them without doing any harm -- other than causing services to restart.

Dependence on AWS services was a deliberate architectural choice. In a basic configuration management tool, AWS services solve a number of practical and security-related problems.

|AWS Service|Feature|Benefits|
|--|--|--|
|IAM|EC2 instance roles and IAM policies|Access to centralized configuration data without locally-stored credentials|
|IAM|IAM users and IAM policies|Control over access to configuration data|
|EC2|Instance tags|Selection of configuration profile(s); instance identification|
|S3|Object storage|Centralized storage of configuration data|
|S3|Versioning|Retention of old configuration data|

## Installation

### Central Components

### On-Instance Component

## Storing Configuration Data in S3

### Profile

#### Service

#### Package List

#### File Specification

#### Source File

## Triggering Updates

## Commentary

This is a demonstration, developed quickly for a particular organization. It should never be used for production. 

This assignment is futile because, at a fundamental level, it involves writing a shell script interpreter. In the following transformations, the choice of any particular LHS (left-hand side) syntax is completely irrelevant to the resulting shell command:

 * _install packages_ `php5 nginx` ⟶ `apt-get --assume-yes --quiet install php5 nginx`
 
 * _remove packages_ `perl-dev` ⟶ `apt-get --assume-yes --quiet remove perl-dev`
 
 * _set owner of file_ `my-file` _to_ `my-user` ⟶ `chown my-file my-user`

 * _populate file_ `my-file` _with_ `my-file-contents` ⟶
 
   ```
   cat << 'EOF' > my-file
   my-file-contents
   EOF
   ```

Instead of implementing a subset of the features of Salt, Ansible, Puppet, or Chef without the _semantics_ that make those products so useful (for example, the ability to specify popular packages without worrying which Linux distribution is present on a given server, the ability to make configuration changes in order, based on formal dependencies, and the potential to use dependency logic to prevent deletion of a Linux user who still owns files tracked by the configuration management system), it might be preferable to demonstrate how one or more existing products could be used to solve a specific configuration problem.

I will add that this assignment included Trojan horse specifications. I will describe just one. The initial requirement to be able to set a file's owner looks harmless, but what if the intended owner does not yet exist? The requirement to be able to add a user is implied. The idempotence requirement then compels support for user modification. Altough Linux distributions include idempotent package management commands (for example, if a target package is already present, `apt-get install` does not, by default, re-install), the leading distributions lack idempotent user management commands. This adds a requirement to query the list of users and generate either a `useradd` or `usermod` command. As those of us with relational database experience realize from comparing endless shoddy attempts to implement "upsert" functionality against reliable solutions such as PostgreSQL's (non-standard SQL) `insert ... on conflict ... do update` or Oracle's (standard SQL) `merge`, differentiating between creation and modification adds a locking requirement. In this way, one seemingly simple requirement leads to lots of engineering work or, more typically, to an incorrect implementation that will fail intermittently.

In fairness, Trojan horse requirements are common in real-world projects, especially when people responsible for strategy, product management, design, marketing and sales forget to talk with implementers.

---

Paul Marcelin | <marcelin@alumni.cmu.edu> | July, 2018
