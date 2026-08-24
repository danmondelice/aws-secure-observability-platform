#!/usr/bin/env bash
set -euo pipefail

region=${AWS_REGION:-us-east-2}
terraform_dir=${TERRAFORM_DIR:-terraform}

if ! command -v aws >/dev/null || ! command -v terraform >/dev/null; then
  echo "aws and terraform CLIs are required." >&2
  exit 2
fi

detector_id=$(terraform -chdir="$terraform_dir" output -raw guardduty_detector_id)
recorder_name=$(terraform -chdir="$terraform_dir" output -raw config_recorder_name)

guardduty_status=$(aws guardduty get-detector \
  --region "$region" --detector-id "$detector_id" \
  --query 'Status' --output text)

config_recording=$(aws configservice describe-configuration-recorder-status \
  --region "$region" \
  --configuration-recorder-names "$recorder_name" \
  --query 'ConfigurationRecordersStatus[0].recording' --output text)

config_error=$(aws configservice describe-configuration-recorder-status \
  --region "$region" \
  --configuration-recorder-names "$recorder_name" \
  --query 'ConfigurationRecordersStatus[0].lastErrorCode' --output text)

security_hub_status=$(aws securityhub describe-hub \
  --region "$region" --query 'HubArn' --output text >/dev/null && echo ENABLED)

printf 'GuardDuty detector: %s\n' "$guardduty_status"
printf 'AWS Config recording: %s\n' "$config_recording"
printf 'AWS Config last error: %s\n' "$config_error"
printf 'Security Hub CSPM: %s\n' "$security_hub_status"

[[ $guardduty_status == "ENABLED" ]]
[[ $config_recording == "True" || $config_recording == "true" ]]
[[ $config_error == "None" || $config_error == "null" ]]

echo "PASS: core security services report enabled with no recorder delivery error."
