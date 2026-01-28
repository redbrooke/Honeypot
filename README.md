prerequisites

Insure the following are installed:

- Terraform
- Azure CLI

Setup an azure subscription, free tier is sufficient. 

First time setup

az login

az account show

az account list

az account set --subscription "<SUBID>"

az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<SUBID>"

Then set the following env variables

$Env:ARM_CLIENT_ID = "<APPID_VALUE>"
$Env:ARM_CLIENT_SECRET = "<PASSWORD_VALUE>"
$Env:ARM_SUBSCRIPTION_ID = "<SUBSCRIPTION_ID>"
$Env:ARM_TENANT_ID = "<TENANT_VALUE>"

terraform init -upgrade

terraform plan -out main.tfplan
