#!/bin/bash

if ! command -v aws &> /dev/null; then
    echo -e "\n\033[1;33m- [ AWS CLI not found. Installing... ] \033[0m"
    sudo apt-get install -y curl unzip > /dev/null 2>&1
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip > /dev/null 2>&1
    unzip -q /tmp/awscliv2.zip -d /tmp > /dev/null 2>&1
    sudo /tmp/aws/install > /dev/null 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
    echo -e "\033[1;32m- [ AWS CLI installed. ] \033[0m"
fi

AWS_REGION="us-east-1"
INSTANCE_NAME="Containernet"
SG_NAME="containernet-group"
KEY_NAME="containernet-keypair"
KEY_FILE="utils/credentials/keypair.pem"
TF_DIR="automated-networks/terraform"

aws_access_key=$(awk -F= '/aws_access_key_id/ && !/^#/ {print $2}' aws_access | tr -d ' ')
aws_secret_key=$(awk -F= '/aws_secret_access_key/ && !/^#/ {print $2}' aws_access | tr -d ' ')
aws_session_token=$(awk -F= '/aws_session_token/ && !/^#/ {print $2}' aws_access | tr -d ' ')

export AWS_ACCESS_KEY_ID="$aws_access_key"
export AWS_SECRET_ACCESS_KEY="$aws_secret_key"
export AWS_SESSION_TOKEN="$aws_session_token"
export AWS_DEFAULT_REGION="$AWS_REGION"

echo -e "\n\033[1;33m- [ WARNING: This will delete all containernet resources from AWS! ] \033[0m"
echo -e "\033[1;35m- [ Are you sure? Type 'yes' to continue: ] \033[0m"
read confirm

if [ "$confirm" != "yes" ]; then
    echo -e "\n\033[1;33m- [ Cancelled. ] \033[0m"
    exit 0
fi

echo -e "\n\033[1;36m- [ Step 1/4: Terminating EC2 instance... ] \033[0m"
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running,stopped,pending" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" > /dev/null
    echo -e "  Terminating instance $INSTANCE_ID, waiting..."
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
    echo -e "  \033[1;32mInstance terminated. \033[0m"
else
    echo -e "  No active instance found, skipping."
fi

echo -e "\n\033[1;36m- [ Step 2/4: Deleting security group... ] \033[0m"
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SG_NAME}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    # Retry up to 5 times — ENIs may still be detaching after instance termination
    for attempt in $(seq 1 10); do
        if aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null; then
            echo -e "  \033[1;32mSecurity group $SG_ID deleted. \033[0m"
            break
        fi
        echo -e "  Waiting for network interfaces to detach (attempt $attempt/10)..."
        sleep 15
        if [ "$attempt" -eq 10 ]; then
            echo -e "  \033[1;31mFailed to delete security group $SG_ID after 10 attempts. Delete it manually in the AWS console. \033[0m"
        fi
    done
else
    echo -e "  Security group not found, skipping."
fi

echo -e "\n\033[1;36m- [ Step 3/4: Deleting key pair... ] \033[0m"
KEY_EXISTS=$(aws ec2 describe-key-pairs \
    --key-names "$KEY_NAME" \
    --query 'KeyPairs[0].KeyName' \
    --output text)

if [ "$KEY_EXISTS" == "$KEY_NAME" ]; then
    if aws ec2 delete-key-pair --key-name "$KEY_NAME"; then
        echo -e "  \033[1;32mKey pair deleted. \033[0m"
    else
        echo -e "  \033[1;31mFailed to delete key pair. Delete it manually in the AWS console. \033[0m"
    fi
else
    echo -e "  Key pair not found, skipping."
fi

echo -e "\n\033[1;36m- [ Step 4/4: Cleaning up local files... ] \033[0m"
if [ -f "$KEY_FILE" ]; then
    > "$KEY_FILE"
    echo -e "  \033[1;32mLocal key file cleared. \033[0m"
fi

if [ -d "$TF_DIR" ]; then
    rm -f "$TF_DIR/terraform.tfstate" "$TF_DIR/terraform.tfstate.backup"
    echo -e "  \033[1;32mTerraform state cleared. \033[0m"
fi

rm -f "results/.last_run"

echo -e "\n\033[1;32m- [ Cleanup complete! You can now run ./start.sh again. ] \033[0m\n"
