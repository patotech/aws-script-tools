#!/bin/bash
#
# Description: This script requires a BITLY access token, that can
#   be generated on Bitly site, and it requires a working aws client
#   on the local machine.
#
#   The Bitly token has to be provided in the final script.
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
BITLY_ACCESS_TOKEN='<--BITLY_TOKEN-->'

BUCKET_NAME="s3://$1"
EXPIRATION_DAYS=$2

if [ -z "$EXPIRATION_DAYS" ]
then
  EXPIRATION_DAYS=1
fi

echo "Checking S3 bucket exists..."
bucketstatus=$(aws s3api head-bucket --bucket ${BUCKET_NAME} 2>&1)
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

BUCKET_FILES=`aws s3 ls $BUCKET_NAME | awk '{print $4}'`
EXPIRATION_IN_SECONDS=$[$EXPIRATION_DAYS * 86400]
echo "Expiration for Signed Urls is $EXPIRATION_DAYS days ($EXPIRATION_IN_SECONDS seconds)"
echo "file,url"
for bucketFile in $BUCKET_FILES
do
  S3_PRESIGNED_URL=`aws s3 presign --expires-in $EXPIRATION_IN_SECONDS $BUCKET_NAME/$bucketFile`
  BITLY_CALL="curl -s --header \"Content-Type: application/json\" --header \"Authorization: Bearer "$BITLY_ACCESS_TOKEN"\" --request POST --data '{ \"domain\": \"bit.ly\",\"long_url\": \""$S3_PRESIGNED_URL"\"}' https://api-ssl.bitly.com/v4/shorten"
  BITLY_SHORTENED_JSON=$(eval $BITLY_CALL)
  BITLY_CLEAN_URL_COMMAND="echo '"$BITLY_SHORTENED_JSON"' | grep -Po '\"link\":.*?[^\\\\]\",' | grep -Po ':.*?[^\\\\]\"' | grep -Po '\".*?[^\\\\]\"' | tr -d '\"'"
  BITLY_LINK=$(eval $BITLY_CLEAN_URL_COMMAND)
  echo "$bucketFile,"$BITLY_LINK
done
