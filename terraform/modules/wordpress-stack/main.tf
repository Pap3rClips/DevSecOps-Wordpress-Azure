# -----------------------------------------------------------------------------
# Module wordpress-stack : un environnement complet (réseau, VM, stockage des
# sauvegardes, secrets applicatifs). Instancié par environments/staging et
# environments/production avec des paramètres différents.
# -----------------------------------------------------------------------------

# Le resource group est créé par le bootstrap : l'identité de CI n'a des droits
# que sur lui, elle ne peut donc pas en créer d'autres.
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  name     = "${var.project}-${var.environment}"
  location = data.azurerm_resource_group.this.location
  tags = merge(var.tags, {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# --- Réseau -------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 1)]

  # Le compte de stockage des sauvegardes n'accepte que le trafic de ce subnet.
  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-${local.name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  tags                = local.tags
}

# Les règles sont des ressources séparées (et non des blocs inline) : la CI
# peut ainsi ajouter puis retirer une règle SSH temporaire pour l'adresse IP
# du runner sans que Terraform ne la supprime ou ne la considère comme dérive.

# HTTP/HTTPS publics uniquement si l'environnement doit être exposé
# (production). Le staging n'est jamais joignable depuis Internet.
# Exception documentée (docs/adr/0002) : un site web public doit accepter
# 80/443 depuis Internet. Limitée à ces deux ports, jamais à SSH.
#trivy:ignore:AZU-0047
resource "azurerm_network_security_rule" "web" {
  count                       = var.public_web_access ? 1 : 0
  name                        = "allow-web-internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Accès SSH d'administration optionnel, restreint à des CIDR explicites.
# Par défaut : aucun. La CI ouvre un accès éphémère pour son propre runner.
resource "azurerm_network_security_rule" "ssh_admin" {
  count                       = length(var.admin_ssh_cidrs) > 0 ? 1 : 0
  name                        = "allow-ssh-admin"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.admin_ssh_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_public_ip" "vm" {
  name                = "pip-${local.name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  allocation_method   = "Static"
  sku                 = "Standard"
  # Fournit un FQDN <label>.<region>.cloudapp.azure.com, utilisé pour TLS.
  domain_name_label = var.dns_label
  tags              = local.tags
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${local.name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# --- Machine virtuelle --------------------------------------------------------

resource "azurerm_linux_virtual_machine" "app" {
  name                  = "vm-${local.name}"
  computer_name         = "${var.project}-${var.environment}"
  resource_group_name   = data.azurerm_resource_group.this.name
  location              = local.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]

  # Authentification par clé uniquement.
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # Trusted Launch : démarrage sécurisé + vTPM.
  secure_boot_enabled = true
  vtpm_enabled        = true

  os_disk {
    name                 = "osdisk-${local.name}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Diagnostics de démarrage (console série) avec stockage géré par Azure.
  boot_diagnostics {}

  tags = local.tags
}

# --- Sauvegardes --------------------------------------------------------------

resource "azurerm_storage_account" "backup" {
  name                     = "st${var.project}${substr(var.environment, 0, 4)}${random_string.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = var.backup_replication_type
  min_tls_version          = "TLS1_2"

  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  # Nécessaire pour générer le jeton SAS de restic (voir ci-dessous).
  shared_access_key_enabled = true

  blob_properties {
    # Protection contre une suppression (accidentelle ou malveillante) des
    # sauvegardes depuis la VM : les blobs supprimés restent récupérables.
    delete_retention_policy {
      days = var.backup_soft_delete_days
    }
    container_delete_retention_policy {
      days = var.backup_soft_delete_days
    }
  }

  # Accès réseau limité au subnet de la VM.
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
    bypass                     = ["AzureServices"]
  }

  tags = local.tags
}

# storage_account_id => création via l'API de gestion Azure : fonctionne même
# si le pare-feu du compte bloque l'adresse IP du runner.
resource "azurerm_storage_container" "restic" {
  name                  = "restic"
  storage_account_id    = azurerm_storage_account.backup.id
  container_access_type = "private"
}

# Jeton SAS limité au seul conteneur restic, à durée de vie bornée et
# renouvelé automatiquement à chaque déploiement passé la date de rotation.
resource "time_rotating" "backup_sas" {
  rotation_days = 90
}

data "azurerm_storage_account_blob_container_sas" "restic" {
  connection_string = azurerm_storage_account.backup.primary_connection_string
  container_name    = azurerm_storage_container.restic.name
  https_only        = true
  start             = time_rotating.backup_sas.rfc3339
  # 30 jours de marge après la date de rotation.
  expiry = timeadd(time_rotating.backup_sas.rotation_rfc3339, "720h")

  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = true
    list   = true
  }
}

# --- Secrets applicatifs ------------------------------------------------------
# Générés une fois, conservés dans le state (chiffré, accès RBAC restreint).
# Pas de caractères spéciaux pour éviter les problèmes d'échappement dans les
# fichiers .env de Docker Compose ; la longueur compense.

resource "random_password" "db_root" {
  length  = 40
  special = false
}

resource "random_password" "db_user" {
  length  = 40
  special = false
}

resource "random_password" "wp_admin" {
  length  = 32
  special = false
}

# Graine des clés de salage WordPress (AUTH_KEY, etc.), dérivées par Ansible :
# les sessions survivent aux redémarrages du conteneur.
resource "random_password" "wp_salt_seed" {
  length  = 64
  special = false
}

resource "random_password" "restic" {
  length  = 48
  special = false
}
