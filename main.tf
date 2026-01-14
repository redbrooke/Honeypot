# Terraform is a declarative language made of different blocks. These blocks 'declare' pieces of infrastructure. Full list of block types:
#
#   Terraform Block.
#   Provider Block.
#   Data Block.
#   Resource Block.
#   Module Block.
#   Variable Block.
#   Output Block.
#   Locals Block.
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
# Generate two resource groups and set the location to Wales (not london): 
# Two groups made to make it easier to identify and dump honeypots, the whole group can be easily removed. 

# For sentinel
resource "azurerm_resource_group" "HoneyProject" {
  name     = "SentinelGroup"
  location = "ukwest"
  tag = {"Project" = "Honeypot"}
}

# For the pots
resource "azurerm_resource_group" "HoneyProjectPots" {
  name     = "HoneypotGroup"
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

################################################
# Network setup
# as per the quickstart guide - https://learn.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-terraform

# Create virtual network
resource "azurerm_virtual_network" "honeypot_network" {
  name                = "Honeypot-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.HoneyProjectPots.location
  resource_group_name = azurerm_resource_group.HoneyProjectPots.name
}

# Create subnet
resource "azurerm_subnet" "honeypot_subnet" {
  name                 = "$Honeypot-subnet"
  resource_group_name = azurerm_resource_group.HoneyProjectPots.name
  virtual_network_name = azurerm_virtual_network.honeypot_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "IISPot_public_ip" {
  name                = "$IISPot-public-ip"
  location            = azurerm_resource_group.HoneyProjectPots.location
  resource_group_name = azurerm_resource_group.HoneyProjectPots.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "honeypot_nsg" {
  name                = "$IISPot-nsg"
  location            = azurerm_resource_group.HoneyProjectPots.location
  resource_group_name = azurerm_resource_group.HoneyProjectPots.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "IISPot_nic" {
  name                = "$IISPot-nic"
  location            = azurerm_resource_group.HoneyProjectPots.location
  resource_group_name = azurerm_resource_group.HoneyProjectPots.name

  ip_configuration {
    name                          = "IISPot_nic_configuration"
    subnet_id                     = azurerm_subnet.honeypot_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.IISPot_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "assignNSG" {
  network_interface_id      = azurerm_network_interface.IISPot_nic.id
  network_security_group_id = azurerm_network_security_group.honeypot_nsg.id
}

#####################################################################
# Create storage account for boot diagnostics

resource "azurerm_storage_account" "honeypot_storage_account" {
  name                     = "bootlogs"
  location            = azurerm_resource_group.HoneyProjectPots.location
  resource_group_name = azurerm_resource_group.HoneyProjectPots.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
