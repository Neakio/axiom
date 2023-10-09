#!/bin/bash

AXIOM_PATH="$HOME/.axiom"
source "$AXIOM_PATH/interact/includes/vars.sh"

appliance_name=""
appliance_key=""
appliance_url=""
token=""
region=""
provider=""
size=""
email=""

BASEOS="$(uname)"
case $BASEOS in
'Linux')
  BASEOS='Linux'
  ;;
'FreeBSD')
  BASEOS='FreeBSD'
  alias ls='ls -G'
  ;;
'WindowsNT')
  BASEOS='Windows'
  ;;
'Darwin')
  BASEOS='Mac'
  ;;
'SunOS')
  BASEOS='Solaris'
  ;;
'AIX') ;;
*) ;;
esac

install_aws_cli() {
  echo -e "${Blue}Installing aws cli...${Color_Off}"
  if [[ $BASEOS == "Mac" ]]; then
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    open AWSCLIV2.pkg
  elif [[ $BASEOS == "Linux" ]]; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    cd /tmp
    unzip awscliv2.zip
    sudo ./aws/install
  fi
}

is_installed() {
  command -v "$1" >/dev/null 2>&1
}

if is_installed "aws"; then
  echo -e "${BGreen}aws cli is already installed${Color_Off}"
else
  install_aws_cli
fi

function awssetup() {
  #Look where is the instance
  if curl -s http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
    #Means that the instance is on AWS
    :
  else
    #Doesn't run on AWS and need access
    echo -e -n "${Green}Please enter your AWS Access Key ID (required): \n>> ${Color_Off}"
    read ACCESS_KEY
    while [[ "$ACCESS_KEY" == "" ]]; do
      echo -e "${BRed}Please provide a AWS Access KEY ID, your entry contained no input.${Color_Off}"
      echo -e -n "${Green}Please enter your token (required): \n>> ${Color_Off}"
      read ACCESS_KEY
    done

    echo -e -n "${Green}Please enter your AWS Secret Access Key (required): \n>> ${Color_Off}"
    read SECRET_KEY
    while [[ "$SECRET_KEY" == "" ]]; do
      echo -e "${BRed}Please provide a AWS Secret Access Key, your entry contained no input.${Color_Off}"
      echo -e -n "${Green}Please enter your token (required): \n>> ${Color_Off}"
      read SECRET_KEY
    done

    aws configure set aws_access_key_id "$ACCESS_KEY"
    aws configure set aws_secret_access_key "$SECRET_KEY"
  fi

  default_region="us-west-2"
  echo -e -n "${Green}Please enter your default region: (Default '$default_region', press enter) \n>> ${Color_Off}"
  read region
  if [[ "$region" == "" ]]; then
    echo -e "${Blue}Selected default option '$default_region'${Color_Off}"
    region="$default_region"
  fi
  echo -e -n "${Green}Please enter your default size: (Default 't2.medium', press enter) \n>> ${Color_Off}"
  read size
  if [[ "$size" == "" ]]; then
    echo -e "${Blue}Selected default option 't2.medium'${Color_Off}"
    size="t2.medium"
  fi
  while true; do
    echo -e -n "${Green}Here are the differents VPCs available : \n${Color_Off}"
    #Get all the VPC on the account and display them
    aws ec2 describe-vpcs --query "Vpcs[*].[Tags[?Key=='Name'].Value]" --output text | awk -F'\t' '{if (NR==1) print "Number \t Subnet"} {print NR-1 "\t" $1}'
    echo -e -n "${Green}Please choose the vpc you want to us: (Default vpc, press enter) \n>> ${Color_Off}"
    read vpc
    vpc_id=$(aws ec2 describe-vpcs --filters --query "Vpcs[$vpc].VpcId" --output text)
    #If default VPC choosed
    if [[ "$vpc" == "" ]]; then
      vpc_id=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)
      if [[ "$vpc_id" == "None" ]]; then
        echo "${BRed}No default vpc available, please choose a vpc.${Color_Off}"
      else
        is_default=$true
        break
      fi
    fi
  done
  while true; do
    echo -e -n "${Green}This vpc has those subnets : \n${Color_Off}"
    if [[ "$is_default" ]]; then
    aws ec2 describe-subnets --filters "Name=vpc-id, Values=$vpc_id" --query "Subnets[*].[AvailabilityZone]" --output text | awk -F'\t' '{if (NR==1) print "Number \t Availability Zone"} {print NR-1 "\t" $1}'
    else
    aws ec2 describe-subnets --filters "Name=vpc-id, Values=$vpc_id" --query "Subnets[*].[Tags[?Key=='Name'].Value]" --output text | awk -F'\t' '{if (NR==1) print "Number \t Subnet"} {print NR-1 "\t" $1}'
    fi
    echo -e -n "${Green}Please choose the subnet you want to use: (number required) \n>> ${Color_Off}"
    read subnet
    subnet_id=$(aws ec2 describe-subnets --filters "Name=vpc-id, Values=$vpc_id" --query "Subnets[$subnet].SubnetId" --output text)
    if [[ "$subnet_id" != "None" && $subnet =~ ^[0-9]+$ ]]; then
      break
    else
      echo -e "${BRed}Please provide a subnet, your entry didn't contain a valid input.${Color_Off}"
    fi
  done

  echo -e -n "${Green}Do you want your instances having public IP addresses ? (required) \n>> ${Color_Off}"
  read public_ip
  while [[ "$public_ip" != "yes" && "$publicIP" != "no" ]]; do
    echo -e -n "${BRed}Your entry didn't contain a valid input. Please respond by 'yes' or 'no'. \n>> ${Color_Off}"
    read public_ip
  done
  if [[ "$public_ip" == "yes" ]]; then
    public_ip=true
  else
    public_ip=false
  fi

  aws configure set default.region "$region"

  echo -e "${BGreen}Creating an Axiom Security Group: ${Color_Off}"
  aws ec2 delete-security-group --group-name axiom >/dev/null 2>&1
  sc="$(aws ec2 create-security-group --group-name axiom --vpc-id $vpc_id --description "Axiom SG")"
  group_id="$(echo "$sc" | jq -r '.GroupId')"
  echo -e "${BGreen}Created Security Group: $group_id ${Color_Off}"

  ######################################################################################################## we should add this to whitelist your IP - TODO
  group_rules="$(aws ec2 authorize-security-group-ingress --group-id "$group_id" --protocol tcp --port 2266 --cidr 0.0.0.0/0)"
  group_owner_id="$(echo "$group_rules" | jq -r '.SecurityGroupRules[].GroupOwnerId')"
  sec_group_id="$(echo "$group_rules" | jq -r '.SecurityGroupRules[].SecurityGroupRuleId')"

  data="$(echo "{\"aws_access_key\":\"$ACCESS_KEY\",\"aws_secret_access_key\":\"$SECRET_KEY\",\"group_owner_id\":\"$group_owner_id\",\"security_group_id\":\"$sec_group_id\",\"region\":\"$region\",\"vpc_id\":\"$vpc_id\",\"subnet_id\":\"$subnet_id\",\"public_ip\":\"$public_ip\",\"provider\":\"aws\",\"default_size\":\"$size\"}")"

  echo -e "${BGreen}Profile settings below: ${Color_Off}"
  echo $data | jq
  echo -e "${BWhite}Press enter if you want to save these to a new profile, type 'r' if you wish to start again.${Color_Off}"
  read ans

  if [[ "$ans" == "r" ]]; then
    $0
    exit
  fi

  echo -e -n "${BWhite}Please enter your profile name (e.g 'personal', must be all lowercase/no specials)\n>> ${Color_Off}"
  read title

  if [[ "$title" == "" ]]; then
    title="personal"
    echo -e "${Blue}Named profile 'personal'${Color_Off}"
  fi

  echo $data | jq >"$AXIOM_PATH/accounts/$title.json"
  echo -e "${BGreen}Saved profile '$title' successfully!${Color_Off}"
  $AXIOM_PATH/interact/axiom-account $title

}

awssetup
