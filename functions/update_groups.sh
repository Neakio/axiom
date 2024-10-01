#!/bin/bash

LOG_FILE="/var/log/dnsscan/update_axiom_security_group.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirect stdout and stderr to the log file

SECURITY_GROUP_NAME="axiom"
REGION="eu-west-1"
NEW_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Starting security group update: $(date)"

# Check for public IP
if [ -z "$NEW_IP" ]; then
  echo "Failed to retrieve public IP."
  exit 1
fi

# Get security group ID
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region $REGION --filters Name=group-name,Values=$SECURITY_GROUP_NAME --query 'SecurityGroups[0].GroupId' --output text)

# Check for security group existence
if [ -z "$SECURITY_GROUP_ID" ]; then
  echo "Security group $SECURITY_GROUP_NAME not found."
  exit 1
fi

# Retrieve current inbound rules for the security group
RULES=$(aws ec2 describe-security-groups --region $REGION --group-ids $SECURITY_GROUP_ID --query 'SecurityGroups[0].IpPermissions' --output json)

# Update rules
echo "$RULES" | jq -c '.[]' | while read -r rule; do
  PROTOCOL=$(echo "$rule" | jq -r '.IpProtocol')
  FROM_PORT=$(echo "$rule" | jq -r '.FromPort')
  TO_PORT=$(echo "$rule" | jq -r '.ToPort')
  OLD_IPS=$(echo "$rule" | jq -r '.IpRanges[].CidrIp // empty')  # Avoid errors if no IPs

  for OLD_IP in $OLD_IPS; do
    # Revoke the rule for the old IP
    if [ "$PROTOCOL" == "icmp" ]; then
      aws ec2 revoke-security-group-ingress --region $REGION --group-id $SECURITY_GROUP_ID \
        --protocol icmp --port -1 --cidr "$OLD_IP"
      echo "Revoked ICMP rule from IP $OLD_IP"
    else
      aws ec2 revoke-security-group-ingress --region $REGION --group-id $SECURITY_GROUP_ID \
        --protocol "$PROTOCOL" --port "$FROM_PORT-$TO_PORT" --cidr "$OLD_IP"
      echo "Revoked rule: protocol=$PROTOCOL, ports=$FROM_PORT-$TO_PORT from IP $OLD_IP"
    fi
  done

  # Authorize the new IP address
  if [ "$PROTOCOL" == "icmp" ]; then
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $SECURITY_GROUP_ID \
      --protocol icmp --port -1 --cidr "${NEW_IP}/32"
    echo "Updated ICMP rule to IP $NEW_IP"
  else
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $SECURITY_GROUP_ID \
      --protocol "$PROTOCOL" --port "$FROM_PORT-$TO_PORT" --cidr "${NEW_IP}/32"
    echo "Updated rule: protocol=$PROTOCOL, ports=$FROM_PORT-$TO_PORT to IP $NEW_IP"
  fi

done

echo "All rules updated with new IP $NEW_IP for security group $SECURITY_GROUP_NAME."
