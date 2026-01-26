# This script creates a simple windows VM honeypot.

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

#TODO:
# Diagnose if the data collection rule is connected to the LAW created in the parent directory. Outputs may be needed.

resource "azurerm_resource_group" "IISPotGroup" {
  name     = "IISGroup"
  location = "ukwest"
  tags = {"Project" = "Honeypot"}
}

################################################
# Network setup
# as per the quickstart guide - https://learn.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-terraform

# Create virtual network
resource "azurerm_virtual_network" "honeypot_network" {
  name                = "Honeypot-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.IISPotGroup.location
  resource_group_name = azurerm_resource_group.IISPotGroup.name
}

# Create subnet
resource "azurerm_subnet" "honeypot_subnet" {
  name                 = "$Honeypot-subnet"
  resource_group_name = azurerm_resource_group.IISPotGroup.name
  virtual_network_name = azurerm_virtual_network.honeypot_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "IISPot_public_ip" {
  name                = "$IISPot-public-ip"
  location            = azurerm_resource_group.IISPotGroup.location
  resource_group_name = azurerm_resource_group.IISPotGroup.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "honeypot_nsg" {
  name                = "$IISPot-nsg"
  location            = azurerm_resource_group.IISPotGroup.location
  resource_group_name = azurerm_resource_group.IISPotGroup.name

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
  location            = azurerm_resource_group.IISPotGroup.location
  resource_group_name = azurerm_resource_group.IISPotGroup.name

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

#############################
# Create the VM

################### WORK IN PROGRESS CHANGE ME!!!!

# Create virtual machine
resource "azurerm_windows_virtual_machine" "main" {
  name                  = "IIS-vm"
  admin_username        = "azureuser"
  admin_password        = random_password.password.result
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# Install IIS web server to the virtual machine
resource "azurerm_virtual_machine_extension" "web_server_install" {
  name                       = "${random_pet.prefix.id}-wsi"
  virtual_machine_id         = azurerm_windows_virtual_machine.main.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
  SETTINGS
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

resource "random_password" "password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}

#resource "random_pet" "prefix" {
#  prefix = var.prefix
#  length = 1
#}

#####################################################################
# Create storage account for boot diagnostics

resource "azurerm_storage_account" "honeypot_storage_account" {
  name                     = "bootlogs"
  location            = azurerm_resource_group.IISPotGroup.location
  resource_group_name = azurerm_resource_group.IISPotGroup.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Install the azure monitoring agent for windows
# Extension as per https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
# Extensions allow you to dump post install stuff onto a VM, similar to how the web server was set up. Ref - https://learn.microsoft.com/en-us/cli/azure/vm/extension?view=azure-cli-latest

resource "azurerm_virtual_machine_extension" "ama_windows" {
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.main.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# Creates a data collection rule.
# ref : https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule_association

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = "dcr-vm-logs"
  location            = azurerm_resource_group.IISPotGroup.location
  resource_group_name = azurerm_resource_group.IISPotGroup.name

# Creates a destination for logs to be sent to. 
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.IAmTheLaw.id # SET UP THIS WITH THE PREVIOUSLY CREATED LAW azurerm_log_analytics_workspace.law.id
      name                  = "law-destination"
    }
  }

  data_sources {
    windows_event_log {
      name    = "windows-events"
      streams = ["Microsoft-WindowsEvent"]

      x_path_queries = [
        "Security!*",
        "System!*",
        "Application!*"
      ]
    }
  }

  data_flow {
    streams      = ["Microsoft-WindowsEvent"]
    destinations = ["law-destination"]
  }
}

# Associate the DCR with the VM

resource "azurerm_monitor_data_collection_rule_association" "vm_assoc" {
  name                    = "vm-dcr-association"
  target_resource_id      = azurerm_windows_virtual_machine.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
}

