#!/bin/bash

# Script to Apply a Configuration
# Paul Marcelin | marcelin@alumni.cmu.edu | July, 2018

# Warnings:
#  - Do not use for production
#  - Simple error handling: any error causes script
#    to exit. Examine output up to that point, and
#    cached configuration data in $CFGDIR and $CFGDIR_OLD
#  - No configuration management system can prevent a
#    user from explicitly removing a crucial package,
#    file, etc. -- whether intentionally or by accident

# Requirements:
#  - S3 bucket containing valid configuration data
#  - EC2 instance (Adaptation required for non-EC2 systems.)
#  - Valid Profiles tag on EC2 instance
#  - IAM EC2 instance role with IAM policy allowing s3:ListBucket for the
#    bucket and s3:GetObject for all objects within the applicable profiles.
#    (It is always incorrect to store, and never necessary to store,
#    AWS_SECRET_ACCESS_KEY, etc. in the file system of an EC2 instance.)
#  - awscli (Frequently updated. Use a recent major version of the operating
#    system, so that the AWS CLI operating system package will be recent.
#    Failing that, install the Python package.)
#  - jq
#  - User with passwordless sudo privileges (typically, ubuntu)

# Invocation:
#    cfg-apply.bash BUCKET_NAME
#      where BUCKET_NAME is the name of the S3 bucket for storing configuration data


set -o errexit  # Exit script on any error
set -o noglob  # Mitigate an injection risk when Profiles tag contains *


if [ $# -ne 1 ]
then
  echo 'Usage: cfg-apply BUCKET_NAME'
  exit 1
fi

# All jq calls involve:
# 1. --raw-output , which strips quotes from an output string.
# 2. --exit-status , which produces a non-zero exit status when the filter
#    returns null, as happens when a given key is not present in an object.
JQ_OPTS='--raw-output --exit-status'
# 3. A trailing filter intended to prevent command injection by producing
#    null when a value is not a string, is an empty string, or contains
#    unexpected characters. Expand character set if necessary.
#    Shortcoming: jq fails silently.
JQ_CHECK=' | if type == "string" and test("^[-_a-zA-Z0-9.,+=/]+$") then . else null end'


# You'd want to cache the configuration in a more durable place, in practice
CFGDIR='/tmp/cfg'
CFGDIR_OLD="${CFGDIR}-old"
if [ -d "${CFGDIR}" ]
then
  mv "${CFGDIR}" "${CFGDIR_OLD}"
fi
mkdir --parents "${CFGDIR}"
chmod 'g-rwx,o-rwx' "${CFGDIR}"  # Very basic access control


# Use a tag, which is a property of the EC2 instance, to select configuration profiles.
# IAM policies (condition keys: aws:RequestTag and ec2:ResourceTag) should be used to
# restrict creation and modification of this tag. Profiles would have to be selected
# some other way if this script were used outside EC2.
AWS_DEFAULT_REGION=$(
  /usr/bin/curl \
    --silent --max-time 5 \
    'http://169.254.169.254/latest/dynamic/instance-identity/document' \
  | jq $JQ_OPTS '.["region"]'"${JQ_CHECK}"
)
export AWS_DEFAULT_REGION
EC2_INST_ID=$(
  /usr/bin/curl \
    --silent --max-time 5 \
    'http://169.254.169.254/latest/meta-data/instance-id'
)
PROFILES=$(
  aws ec2 describe-tags \
    --filters "Name=resource-id,Values=${EC2_INST_ID}" "Name=key,Values=Profiles" \
    --query 'Tags[0].Value' --output text
)
# Security note: Quoting ensures that the expression containing EC2_INST_ID,
# which is obtained using curl, is treated as single word, mitigating a far-fetched
# (one would have to spoof the EC2 metadata service) command injection risk.


sudo apt-get update

# Multiple configuration profiles can be applied to one EC2 instance.
# Multiple profile names in the Profiles tag must be separated by spaces;
# failure to do this simply produces no match on any profile name.
for PROFILE in $PROFILES
do

  echo
  echo
  echo "Profile: ${PROFILE}"
  echo

  PROFILEDIR="${CFGDIR}/profile/${PROFILE}"
  mkdir --parents "${PROFILEDIR}"
  aws s3 cp "s3://${1}/profile/${PROFILE}" "${PROFILEDIR}" --recursive
  # Why repeat this for each profile instead of doing it once, for the whole configuration
  # hierarchy? To download only the applicable profiles. IAM policies attached to the EC2
  # instance role should be used to prevent access to other, potentially sensitive, profiles.

  # Security note: Quoting ensures that any expression containing components of an S3
  # object key (PROFILEDIR is such a component, as is ITEM_NAME, below) or a user-supplied
  # parameter ($1, the bucket name) is treated as a single word, mitigating the command
  # injection risk. Other variables in those expressions are set to literal values inside
  # this script (ITEM_TYPE, below, is an example), or are obtained from jq, which is always
  # called with safeguards against command injection.

  PROFILEDIR_OLD="${CFGDIR_OLD}/profile/${PROFILE}"
  PROFILE_CHANGED=1
  if [ -d "${PROFILEDIR_OLD}" ]
  then
    # Detect explicit configuration changes, which will trigger service restarts. I
    # have deliberately decided NOT to handle operating system package updates, as that
    # would require the user to list all relevant packages (including dependencies, to
    # an arbitrary level of depth) and request a specific version of each package (cf.
    # `pip freeze` in the context of Python or `npm shrinkwrap` in the context of JaveScript).
    # Also needed would be a mechanism to track update status across all managed systems.

    # Temporarily allow script to continue in case diff
    # returns a non-zero status, indicating a profile update.
    set +o errexit
    diff --recursive --brief "${PROFILEDIR_OLD}" "${PROFILEDIR}"
    PROFILE_CHANGED=$?
    set -o errexit
  fi

  # In the absence of a dependency system, process configuration
  # item types in a fixed, practical order (install packages -->
  # populate files --> create symbolic links --> restart services).
  for ITEM_TYPE in 'pkg' 'file' 'link' 'svc'
  do

    echo
    echo
    echo "  Item type: ${ITEM_TYPE}"

    # Every configuration item has a human-readable logical identifier (name). The
    # system ls (avoid any aliases!) sorts alphabetically by default. In the absence
    # of a dependency system, use names to control processing order within an item type.
    for ITEM_NAME in $( /bin/ls "${PROFILEDIR}/${ITEM_TYPE}" )
    do

      echo
      echo "    Item name: ${ITEM_NAME}"
      echo

      # Every item must have a JSON metadata file specifying an
      # action and a physical identifier, whose interpretation varies:
      #
      # Item Type   Physical Identifier
      # ---------   -------------------
      #   pkg       Exact name of operating system package to be installed
      #             (e.g., gcc4.8 instead of gcc)
      #   file      Full pathname of file to be created
      #   link      Full pathname of link to be created
      #   svc       Exact name of service to be restarted
      # Additional files and/or metadata properties are required for some item types.
      ITEM_META="${PROFILEDIR}/${ITEM_TYPE}/${ITEM_NAME}/metadata.json"
      ITEM_ACTION=$( jq $JQ_OPTS '.["action"]'"${JQ_CHECK}" "${ITEM_META}" )
      ITEM_ID=$( jq $JQ_OPTS '.["id"]'"${JQ_CHECK}" "${ITEM_META}" )
      case $ITEM_TYPE in

        # All of the actions that follow are potentially dangerous.
        # Basic safeguards against command injection are implemented.

        'pkg')
          case $ITEM_ACTION in
            'install'|'remove')
              sudo apt-get --assume-yes --no-upgrade "${ITEM_ACTION}" "${ITEM_ID}"
              ;;
            *)
              echo "Unknown action ${ITEM_ACTION}"
              ;;
          esac
          ;;

        'file')
          case $ITEM_ACTION in
            'overwrite')
              FILE_USER=$( jq $JQ_OPTS '.["user"]'"${JQ_CHECK}" "${ITEM_META}" )
              FILE_GROUP=$( jq $JQ_OPTS '.["group"]'"${JQ_CHECK}" "${ITEM_META}" )
              FILE_MODE=$( jq $JQ_OPTS '.["mode"]'"${JQ_CHECK}" "${ITEM_META}" )
              
              # For security, never populate a file until permissions have been set.

              # If file exists, update access time only (do not update modification timestamp):
              sudo touch -a "${ITEM_ID}"
              # These two update modification timestamp only if user/group
              # or mode actually changes; print changes, for information:
              sudo chown --changes "${FILE_USER}:${FILE_GROUP}" "${ITEM_ID}"
              sudo chmod --changes "${FILE_MODE}" "${ITEM_ID}"
              # Unlike cp, this copies only when contents change, preserving the
              # modification timestamp otherwise; print changes (crypitcally, alas):
              sudo rsync --checksum --inplace --itemize-changes \
                "${PROFILEDIR}/${ITEM_TYPE}/${ITEM_NAME}/source" "${ITEM_ID}"
              ;;
            'delete')
              sudo rm --force "${ITEM_ID}"
              ;;
            *)
              echo "Unknown action ${ITEM_ACTION}"
              ;;
          esac
          ;;

        'link')
          case $ITEM_ACTION in
            'overwrite')
              LINK_TARGET=$( jq $JQ_OPTS '.["target"]'"${JQ_CHECK}" "${ITEM_META}" )
              sudo ln --symbolic --force "${LINK_TARGET}" "${ITEM_ID}"
              ;;
            'delete')
              sudo rm --force "${ITEM_ID}"
              ;;
            *)
              echo "Unknown action ${ITEM_ACTION}"
              ;;
          esac
          ;;

        'svc')
          case $ITEM_ACTION in
            'reload'|'restart')
              if [ $PROFILE_CHANGED -ne 0 ]
              then
                sudo systemctl "${ITEM_ACTION}" "${ITEM_ID}"
              fi
              ;;
            *)
              echo "Unknown action ${ITEM_ACTION}"
              ;;
          esac
          ;;

        *)
          echo "Unknown item type"  # Error preventable before run-time!
          ;;
      esac
    done
  done

done

rm --recursive --force "${CFGDIR_OLD}"
