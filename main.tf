terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = "your subscription id"
  client_id = "your client-id"
  client_secret = "your client-secret"
  tenant_id = "your tenant-id"
}

#resource group
resource "azurerm_resource_group" "cfc-dev" {
    name = "cfc-dev"
    location = "West Europe"
    tags = {
      environment = "dev"
    }
  
}

#virtual network
resource "azurerm_virtual_network" "cfc-vnet" {
  name = "cfc-vnetwork"
  resource_group_name = azurerm_resource_group.cfc-dev.name
  location = azurerm_resource_group.cfc-dev.location
  address_space = [ "10.123.0.0/16" ]
  tags = {
    environment = "dev"
  }
}

#subnet
resource "azurerm_subnet" "cfc-subnet" {
  name = "cfc-subnet"
  resource_group_name = azurerm_resource_group.cfc-dev.name
  virtual_network_name = azurerm_virtual_network.cfc-vnet.name
  address_prefixes = [ "10.123.1.0/24" ]
  
}

resource "azurerm_network_security_group" "cfc-sg" {
  name = "cfc-sg"
  location = azurerm_resource_group.cfc-dev.location
  resource_group_name = azurerm_resource_group.cfc-dev.name
  tags = {
    environment = "dev"
  }
  
}

#security rule
resource "azurerm_network_security_rule" "cfc-sg-dev-rule" {
  name = "cfc-sg-dev-rule"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "*"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "123.123.123.123/32"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.cfc-dev.name
  network_security_group_name = azurerm_network_security_group.cfc-sg.name
  
}

#subnet network security group association
resource "azurerm_subnet_network_security_group_association" "cfc-sga" {
  subnet_id = azurerm_subnet.cfc-subnet.id
  network_security_group_id = azurerm_network_security_group.cfc-sg.id
  
}

#public IP
resource "azurerm_public_ip" "cfc-ip" {
  name = "cfc-ip"
  resource_group_name = azurerm_resource_group.cfc-dev.name
  location = azurerm_resource_group.cfc-dev.location
  allocation_method = "Dynamic"
  
  tags = {
    environment = "dev"
  }
}

#network Interface
resource "azurerm_network_interface" "cfc-ni-dev" {
  name = "cfc-ni-dev"
  location = azurerm_resource_group.cfc-dev.location
  resource_group_name = azurerm_resource_group.cfc-dev.name
  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.cfc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.cfc-ip.id
  }

  tags = {
    environment = "dev"
  }
  
}

#Creating VM
resource "azurerm_linux_virtual_machine" "cfc-dev-vm" {
  name = "cfc-dev-vm"
  resource_group_name = azurerm_resource_group.cfc-dev.name
  location = azurerm_resource_group.cfc-dev.location
  size = "Standard_B1s"
  admin_username = "adminuser"
  network_interface_ids = [azurerm_network_interface.cfc-ni-dev.id]

  #to install docker into VM
  custom_data = filebase64("customdata.tpl")

  #to provide ssh key for login
  admin_ssh_key {
    username = "adminuser"
    public_key = file("~/.ssh/princetfkey.pub")
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "18.04-LTS"
    version = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.ssh",{
      hostname = self.public_ip_address,
      user = "adminuser"
      identityfile = "~/.ssh/princetfkey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell","-Command"] : ["bash","-c"]
    # interpreter = [ "bash","-c" ] this is for Mac
  }

  tags = {
    environment = "dev"
  }
  
}

#to query data
data "azurerm_public_ip" "cfc-ip-data" {
  name = azurerm_public_ip.cfc-ip.name
  resource_group_name = azurerm_resource_group.cfc-dev.name
  
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.cfc-dev-vm.name}: ${data.azurerm_public_ip.cfc-ip-data.ip_address}"  
}
