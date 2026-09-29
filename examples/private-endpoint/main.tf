module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "westeurope"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"


  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.18.0.0/16"]

    subnets = {
      endpoints = {
        address_prefixes = ["10.18.1.0/24"]
      }
    }
  }
}

module "private_dns" {
  source  = "codectl/pdns/azure"
  version = "~> 1.0"

  resource_group_name = module.rg.groups.demo.name

  zones = {
    private = {
      staticsites = {
        name = "privatelink.azurestaticapps.net"
        virtual_network_links = {
          link1 = {
            virtual_network_id = module.network.vnet.id
          }
        }
      }
    }
  }
}

module "stapp" {
  source  = "codectl/stapp/azure"
  version = "~> 1.0"

  app = {
    name                = module.naming.static_web_app.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name

    sku_tier = "Standard"
    sku_size = "Standard"
  }
}

module "privatelink" {
  source  = "codectl/pe/azure"
  version = "~> 1.0"

  resource_group_name = module.rg.groups.demo.name
  location            = module.rg.groups.demo.location

  endpoints = {
    stapp = {
      name      = module.naming.private_endpoint.name
      subnet_id = module.network.subnets.endpoints.id

      private_dns_zone_group = {
        private_dns_zone_ids = [module.private_dns.private_zones.staticsites.id]
      }

      private_service_connection = {
        private_connection_resource_id = module.stapp.app.id
        subresource_names              = ["staticSites"]
      }
    }
  }
}
