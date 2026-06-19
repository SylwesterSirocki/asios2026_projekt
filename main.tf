//definiowany usługodawca MS Azure
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

//typ zasobu Azure, nazwa projektu oraz lokacja serwera
resource "azurerm_resource_group" "rg" {
  name     = "rg_netproj_Sirocki_Sylwester"
  location = "PolandCentral"
}

//zdefiniowanie sieci głównej wirtualnej oraz puli adresów IP
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-main-proj"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

//definicja podsieci dla frontend
resource "azurerm_subnet" "frontend" {
  name                 = "frontend_subnet"
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

//definicja podsieci dla backend
resource "azurerm_subnet" "backend" {
  name                 = "backend_subnet"
  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

// ---------------- definicja grupy bezpieczenstwa NSG dla frontendu
resource "azurerm_network_security_group" "frontend_nsg" {
  name                = "NSG-frontend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  /*
    security_rule {
        name = "Allow-SSH-from-MyIP"
        priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = var.my_public_ip
        destination_address_prefix = "*"
    }
*/
  security_rule {
    name                       = "Allow-RDP-from-MyIP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.my_public_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

//grupa bezpieczenstwa dla Backend'u
resource "azurerm_network_security_group" "backend_nsg" {
  name                = "NSG-backend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name


  security_rule {
    name                       = "Allow-RDP-from-Frontend"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "10.0.2.0/24"
  }

  security_rule {
    name                       = "Deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


//tworzenie publicznego IP dla frontendu
resource "azurerm_public_ip" "frontend_public_ip" {
  name                = "PublicIP-for-VM-Frontend"
  allocation_method   = "Static"
  sku                 = "Standard"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

//tworzenie interface'u IP dla frontendu
resource "azurerm_network_interface" "frontend_nic" {
  name                = "NIC-VM-frontend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-frontend"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.frontend_public_ip.id
  }
}

//tworzenie interface'u IP dla backendu
resource "azurerm_network_interface" "backend_nic" {
  name                = "NIC-VM-backend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-backend"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }
}

//przypisanie interface'u frontend z NSG
resource "azurerm_network_interface_security_group_association" "frontend_nsg_assoc" {
  network_interface_id     = azurerm_network_interface.frontend_nic.id
  network_security_group_id = azurerm_network_security_group.frontend_nsg.id
}

//przypisanie interface'u backend z NSG
resource "azurerm_network_interface_security_group_association" "backend_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.backend_nic.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}


// ---------------- utworzenie maszyn wirtualnych
resource "azurerm_windows_virtual_machine" "frontnend_vm" {
  name                = "VM-Frontend"
  resource_group_name = azurerm_resource_group.rg.name

  location = azurerm_resource_group.rg.location
  size     = "Standard_B2als_v2"

  admin_username = var.front_admin_username
  admin_password = var.front_admin_pass
  patch_mode     = "AutomaticByPlatform"
  network_interface_ids = [
    azurerm_network_interface.frontend_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "backend_vm" {
  name                = "VM-backend"
  resource_group_name = azurerm_resource_group.rg.name

  location = azurerm_resource_group.rg.location
  size     = "Standard_B2als_v2"

  admin_username = var.back_admin_username
  admin_password = var.back_admin_pass
  patch_mode     = "AutomaticByPlatform"
  network_interface_ids = [
    azurerm_network_interface.backend_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
}