#!/bin/bash
#
# Description: This script generates a presigned URL for each document
#   available in a S3 bucket.
#
# Params:
#   Param 1: Bucket name
#   Param 2: Days for expiration
#
# Todo:
#   - Test a bucket with a sub-bucket
#
# Version: 1.0
# Author: ptellez@amazon.com
#
BUCKET_NAME="s3://$1"
EXPIRATION_DAYS=$2

if [ -z "$EXPIRATION_DAYS" ]
then
  EXPIRATION_DAYS=1
fi

echo "Checking S3 bucket exists..."
bucketstatus=$(aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>&1)
if echo ${bucketstatus} | grep 'Not Found';
then
  echo "bucket doesn't exist";
  exit 1
elif echo ${bucketstatus} | grep 'Forbidden';
then
  echo "Bucket exists but not owned"
  exit 1
elif echo ${bucketstatus} | grep 'Bad Request';
then
  echo "Bucket name specified is less than 3 or greater than 63 characters"
  exit 1
else
  echo "Bucket owned and exists";
fi

BUCKET_FILES_COMMAND="aws s3 ls \""$BUCKET_NAME"\"| awk '{\$1=\$2=\$3=\"\"; print \$0}' | sed 's/^[ \\t]*//'"
BUCKET_FILES=$(eval $BUCKET_FILES_COMMAND)
EXPIRATION_IN_SECONDS=$[$EXPIRATION_DAYS * 86400]
echo "Expiration for Signed Urls is $EXPIRATION_DAYS days ($EXPIRATION_IN_SECONDS seconds)"
echo "file,presignedUrl"
IFS=$'\n'       # make newlines the only separator
for bucketFile in $BUCKET_FILES
do
  S3_PRESIGNED_URL_COMMAND="aws s3 presign --expires-in "$EXPIRATION_IN_SECONDS" \""$BUCKET_NAME$bucketFile"\""
  S3_PRESIGNED_URL=$(eval $S3_PRESIGNED_URL_COMMAND)
  BITLY_LINK=$(eval $BITLY_CLEAN_URL_COMMAND)
  echo "$bucketFile,"$S3_PRESIGNED_URL
done
