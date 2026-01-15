# Terraform is a declarative language made of different blocks. These blocks 'declare' pieces of infrastructure. Full list of block types:
#
#   Terraform Block - Set versions etc.
#   Provider Block - Sets providers, like an import in Python. 
#   Resource Block - Define a resource for terraform to use. The meat of a terraform project.
#   Module Block - A logical contianer to build out a single component, for example all the architecture for a single web service, (http server, database, storage blob etc)
#   Output Block - Captures return values 
#   Variable Block - variables are for input. Things that you can change via inputs (like a vars file). 
#   Locals Block - Variables, but locals are "private". You can only change them by altering the code. 
#   Data Block - Access data from outside of terraform, e.g pulling state info from a cloud provider.
#   Provisioners block and Dynamic blocks also exist.
#
#
#########################################
# Configure the Azure provider as per the docs
# Read more here: https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build
# A guide on Sentinel and Terraform can be found here - https://techcommunity.microsoft.com/blog/azureinfrastructureblog/cicd-implementation-for-azure-sentinel-using-terraform/4413220
##########################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

######################################
# Generate a resource groups and set the location to Wales (not london): 

# For sentinel
resource "azurerm_resource_group" "HoneyProject" {
  name     = "SentinelGroup"
  location = "ukwest"
  tag = {"Project" = "Honeypot"}
}

########################################
#Creating the Sentinel workspace, as per the docs
# Docs - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
 #                      ______
 #                   ,-~   _  ^^~-.,
 #                 ,^        -,____ ^,         ,/\/\/\,
 #                /           (____)  |      S~        ~7
 #               ;  .---._    | | || _|     S  I AM THE  Z
 #               | |      ~-.,\ | |!/ |     /_   LAW!   _\ 
 #               ( |    ~<-.,_^\|_7^ ,|     _//_      _\
 #               | |      ", 77>   (T/|   _/'   \/\/\/
 #               |  \_      )/<,/^\)i(|
 #               (    ^~-,  |________||
 #               ^!,_    / /, ,'^~^',!!_,..---.
 #                \_ "-./ /   (-~^~-))' =,__,..>-,
 #                  ^-,__/#w,_  '^' /~-,_/^\      )
 #               /\  ( <_    ^~~--T^ ~=, \  \_,-=~^\
 #  .-==,    _,=^_,.-"_  ^~*.(_  /_)    \ \,=\      )
 # /-~;  \,-~ .-~  _,/ \    ___[8]_      \ T_),--~^^)
 #   _/   \,,..==~^_,.=,\   _.-~O   ~     \_\_\_,.-=}
 # ,{       _,.-<~^\  \ \\      ()  .=~^^~=. \_\_,./
 #,{ ^T^ _ /  \  \  \  \ \)    [|   \oDREDD >
 #  ^T~ ^ { \  \ _\.-|=-T~\\    () ()\<||>,' )
 #   +     \ |=~T  !       Y    [|()  \ ,'  /

resource "azurerm_log_analytics_workspace" "law" {
  name                = "IAmTheLaw"
  location            = azurerm_resource_group.HoneyProject.location
  resource_group_name = azurerm_resource_group.HoneyProject.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 5 # Sets a gig limit to prevent the logs getting too full
}

# Puts sentinel in the LAW (log analysis workbench).
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  log_analytics_workspace_id = azurerm_log_analytics_workspace.IAmTheLaw.id
}

########################################
# A sample rule, ripped right from the DOCs:
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_scheduled

resource "azurerm_sentinel_alert_rule_scheduled" "sign_in_alert" {
  name                       = "sign-in-failure-alert"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  display_name               = "Multiple Sign-in Failures"
  query                      = <<QUERY
SigninLogs
| where ResultType == 50074
| summarize count() by bin(TimeGenerated, 5m), UserPrincipalName
QUERY
  severity                   = "Medium"
  tactics                   = ["InitialAccess"]
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 5
  frequency                  = "PT5M"
  query_period               = "PT5M"
  enabled                    = true
}


