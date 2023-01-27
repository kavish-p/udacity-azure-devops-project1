provider "azurerm" {
    features {}
}

data "azurerm_image" "packer_image" {
    name                = "ubuntuImage2"
    resource_group_name = "ODL-clouddevops-223613"
}

resource "azurerm_resource_group" "main" {
    name     = "kavish-udacity"
    location = var.location
    tags = {
        environment = "kavish-udacity"
    }
}

resource "azurerm_virtual_network" "main" {
    name                = "${var.prefix}-network"
    address_space       = ["10.0.0.0/22"]
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    tags = {
        environment = "kavish-udacity"
    }
}

resource "azurerm_subnet" "internal" {
    name                 = "internal"
    resource_group_name  = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "custom_nsg" {
    name                = "myNetworkSecurityGroup"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    tags = {
        environment = "kavish-udacity"
    }

    security_rule {
        name                       = "VNetInBound-Allow"
        priority                   = 101
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
    }

    security_rule {
        name                       = "LoadBalancerInBound-Allow"
        priority                   = 102
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Inbound-DenyAll"
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range    = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_public_ip" "example" {
    name                = "LBPublicIp"
    resource_group_name = azurerm_resource_group.main.name
    location            = azurerm_resource_group.main.location
    allocation_method   = "Static"
    tags = {
        environment = "kavish-udacity"
    }
}

resource "azurerm_network_interface" "main" {
    name                = "${var.prefix}-nic-${count.index}"
    resource_group_name = azurerm_resource_group.main.name
    location            = azurerm_resource_group.main.location
    count = var.vm_count
    tags = {
        environment = "kavish-udacity"
    }

    ip_configuration {
        name                          = "internal"
        primary                       = true
        subnet_id                     = azurerm_subnet.internal.id
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.main[count.index].id
    network_security_group_id = azurerm_network_security_group.custom_nsg.id
    count = var.vm_count
}

resource "azurerm_lb" "example" {
    name                = "TestLoadBalancer"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    tags = {
        environment = "kavish-udacity"
    }

    frontend_ip_configuration {
        name                 = "PublicIPAddress"
        public_ip_address_id = azurerm_public_ip.example.id
    }
}

resource "azurerm_lb_probe" "main" {
    loadbalancer_id     = azurerm_lb.example.id
    name                = "${var.prefix}-http-server-probe"
    port                = 80
}

resource "azurerm_lb_backend_address_pool" "example" {
    loadbalancer_id = azurerm_lb.example.id
    name            = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "example" {
    network_interface_id    = azurerm_network_interface.main[count.index].id
    ip_configuration_name   = "internal"
    backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
    count = var.vm_count
}

resource "azurerm_lb_rule" "main" {
    loadbalancer_id                = azurerm_lb.example.id
    name                           = "HTTP"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration[0].name
    probe_id                       = azurerm_lb_probe.main.id
    backend_address_pool_ids       = [azurerm_lb_backend_address_pool.example.id]
}

resource "azurerm_availability_set" "example" {
    name                = "example-aset"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name

    tags = {
        environment = "kavish-udacity"
    }
}

resource "azurerm_linux_virtual_machine" "main" {
    name                            = "${var.prefix}-vm-${count.index}"
    resource_group_name             = azurerm_resource_group.main.name
    location                        = azurerm_resource_group.main.location
    size                            = "Standard_B1s"
    admin_username                  = "${var.username}"
    admin_password                  = "${var.password}"
    disable_password_authentication = false
    network_interface_ids = [
        azurerm_network_interface.main[count.index].id,
    ]
    availability_set_id = azurerm_availability_set.example.id
    source_image_id = data.azurerm_image.packer_image.id
    count = var.vm_count

    tags = {
        environment = "kavish-udacity"
    }

    os_disk {
        storage_account_type = "Standard_LRS"
        caching              = "ReadWrite"
    }
}