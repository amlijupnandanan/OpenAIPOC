# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "RG-Neo4j-VM"
  location = "North Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-neo4j"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-neo4j"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 🔹 Move Public IP Creation ABOVE the NIC
resource "azurerm_public_ip" "pip" {
  name                = "pip-neo4j"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

# Network Interface (NIC) - Uses the Public IP
resource "azurerm_network_interface" "nic" {
  name                = "nic-neo4j"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id  # Attach Public IP here
  }
}

# NSG - Ensure SSH and Neo4j Ports are Open
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-neo4j"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowNeo4j"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7474" # Neo4j HTTP
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "AllowNeo4jBolt"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7687" # Neo4j Bolt Protocol
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# VM - Uses the NIC
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-neo4j"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh/vm.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/cloud-init.yml"))  # Cloud-init script to install Neo4j
}

## 🔹 Qdrant VM Setup ##

# Public IP for Qdrant
resource "azurerm_public_ip" "pip-qdrant" {
  name                = "pip-qdrant"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

# Network Interface for Qdrant
resource "azurerm_network_interface" "nic-qdrant" {
  name                = "nic-qdrant"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-qdrant.id
  }
}

# NSG for Qdrant
resource "azurerm_network_security_group" "nsg-qdrant" {
  name                = "nsg-qdrant"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowQdrantAPI"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6333" # Qdrant API
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowQdrantGRPC"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6334" # Qdrant GRPC
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Qdrant NIC
resource "azurerm_network_interface_security_group_association" "nsg_assoc_qdrant" {
  network_interface_id      = azurerm_network_interface.nic-qdrant.id
  network_security_group_id = azurerm_network_security_group.nsg-qdrant.id
}

# Qdrant VM
resource "azurerm_linux_virtual_machine" "vm-qdrant" {
  name                = "vm-qdrant"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic-qdrant.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh/vm.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

#   custom_data = base64encode(file("${path.module}/cloud-init-qdrant.yml"))
}