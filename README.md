prerequisites

Insure the following are installed:

- Terraform
- Azure CLI

Setup an azure subscription, free tier is sufficient. 

First time setup

az login

az account show

az account list

az account set --subscription "<SUBID>-subscription-id"

terraform init -upgrade

terraform plan -out main.tfplan
