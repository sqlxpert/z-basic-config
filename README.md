# Basic Configuration Management Tool

Lets you:

1. Install **files**, set **permissions**, and remove files
3. Install and remove **operating system packages**
3. Restart **services** after designated packages or files have been updated
 
Operations are **idempotent**: you can repeat them without doing any harm other than fetching the latest operating system package list and causing designated services to restart.

Dependence on AWS S3 (and other AWS facilities) was a deliberate architectural choice. For a basic configuration management tool, a centralized object store solves a number of practical and security-related problems.

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

## Configuration Data Format

1. Profile

   a. Operating System Package

   b. File

   c. Symbolic Link

   d. Service

## Triggering Updates

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
   
   (Noting the obvious command injection risk, which would have to be mitigated.)

Instead of implementing a small subset of the features of Salt, Ansible, Puppet, or Chef without the _semantics_ that make those products useful (for example, the ability to specify popular packages without worrying which Linux distribution is present on a given managed system, the ability to apply configuration changes in order, based on formal dependencies, and the possibility that dependency logic will catch configuration profile errors such as deletion of a Linux user who still owns files tracked by the configuration management system), it might be preferable to demonstrate how one or more existing products could be used to solve a specific configuration problem.

I will add that this assignment included Trojan horse requirements. I dismiss one case, service restart after operating system package updates,  in a comment inside [`script/`](/script/cfg-apply.bash).

I will describe another case here. The requirement to be able to set a file's owner looks harmless, but what if the intended owner does not yet exist and has not been created by an operating system package? The requirement to be able to add a user is implied. The idempotence requirement then compels support for user modification. Altough Linux distributions include idempotent package management commands (for example, if the latest version of a package is already present, `apt-get install` will not re-install that package), the leading distributions lack idempotent user management commands. This adds a requirement to query the list of users and generate either a `useradd` or `usermod` command. As those of us with relational database experience realize from comparing endless shoddy attempts to implement "upsert" functionality against reliable solutions such as PostgreSQL's (non-standard SQL) `insert ... on conflict ... do update` or Oracle's (standard SQL) `merge`, differentiating between creation and modification adds a locking requirement. In this way, a seemingly simple requirement prompts lots of engineering or, more typically, leads to an incorrect implementation that will fail intermittently.

In fairness, Trojan horse requirements are common in real-world projects, especially when people responsible for strategy, product management, design, marketing and sales forget to talk with implementers. The classic example is the tree swing cartoon:

![Tree swing cartoon](https://fisher.osu.edu/blogs/gradlife/files/Lack-Of-Working-Link.jpg)

---

Paul Marcelin | <marcelin@alumni.cmu.edu> | July, 2018
