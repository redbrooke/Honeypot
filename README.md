prerequisites

Insure the following are installed:

- Terraform
- Azure CLI

Setup an azure subscription, free tier is sufficient. 

First time setup

You may need to use powershell directly instead of vscode.

az login

az account show

az account list

az account set --subscription "<SUBID>"

Setup:

az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<SUBID>"

Then set the following env variables

$Env:ARM_CLIENT_ID = "<APPID_VALUE>"
$Env:ARM_CLIENT_SECRET = "<PASSWORD_VALUE>"
$Env:ARM_SUBSCRIPTION_ID = "<SUBSCRIPTION_ID>"
$Env:ARM_TENANT_ID = "<TENANT_VALUE>"

terraform init -upgrade

terraform plan -out main.tfplan

terraform apply



If VMs are not avalible in the requested size, check:

az vm list-skus --location northeurope --size Standard_D --all --output table



TODO:

1. Consider adding a backend that writes the tfstate file to a storage blon - https://developer.hashicorp.com/terraform/language/backend/azurerm

2. WATCH ME - https://www.youtube.com/watch?v=GSXx8AZjKK4 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!