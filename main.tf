terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.97.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "gsm" {
  name     = "gsm-resources"
  location = "westeurope"
}

resource "azurerm_virtual_network" "gsm" {
  name                = "gsm-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.gsm.location
  resource_group_name = azurerm_resource_group.gsm.name
}

resource "azurerm_network_security_group" "gsm" {
  name                = "gsm-security-group"
  location            = azurerm_resource_group.gsm.location
  resource_group_name = azurerm_resource_group.gsm.name
  

  security_rule {
    name                       = "all-ports"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "gsm" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.gsm.name
  virtual_network_name = azurerm_virtual_network.gsm.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "gsm" {
  subnet_id                 = azurerm_subnet.gsm.id
  network_security_group_id = azurerm_network_security_group.gsm.id
}

resource "azurerm_public_ip" "gsm" {
    name                         = "gsm-public-ip"
    location                     = azurerm_resource_group.gsm.location
    resource_group_name          = azurerm_resource_group.gsm.name
    allocation_method            = "Dynamic"
}

resource "azurerm_network_interface" "gsm" {
  name                = "gsm-nic"
  location            = azurerm_resource_group.gsm.location
  resource_group_name = azurerm_resource_group.gsm.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.gsm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gsm.id
  }
}

resource "azurerm_linux_virtual_machine" "gsm" {
  name                = "gsm-linux"
  resource_group_name = azurerm_resource_group.gsm.name
  location            = azurerm_resource_group.gsm.location
  size                = "Standard_D2_v4"

  admin_username      = "azure"
  admin_ssh_key {
    username   = "azure"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.gsm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb = 64
  }

  source_image_reference {
    publisher = "credativ"
    offer     = "Debian"
    sku       = "9"
    version   = "latest"
  }
}

output "public_ip" {
  value = azurerm_linux_virtual_machine.gsm.public_ip_address
}
