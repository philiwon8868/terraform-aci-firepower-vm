variable "user" {
  type = map(any)
}

variable "vmm_domain" {
  type = map(any)
}

variable "vSphere_Site" {
    type = map(any)
}

variable "fmc_user" {
    type = map(any)
}

variable "tenant" {
  type = map(any)
}

variable "vrf" {
    type    = string
    default = "VRF"
}

variable "bds" {
    description = "List of bridge domains to be created"
    type = map
    default = {
      web = {
        bd_name = "bd-web"
        subnet  = "10.4.1.254/24"
      },
      app = {
        bd_name = "bd-app"
        subnet  = "10.5.1.254/24"
      },
      db = {
        bd_name = "bd-db"
        subnet = "10.6.1.254/24"
      },
      inside = {
        bd_name = "bd-inside"
        subnet = "1.1.1.1/24"
      },
      outside = {
        bd_name = "bd-outside"
        subnet = "2.2.2.1/24"
      }
    }
}

variable "filters" {
  description = "Create filters with these names and ports"
  type        = map
  default     = {
    filter_http = {
      filter   = "http",
      entry    = "http",
      protocol = "tcp",
      port     = "80"
    },
    filter_icmp = {
      filter   = "icmp",
      entry    = "icmp",
      protocol = "icmp",
      port     = "0"
    },
    filter_any = {
      filter   = "any",
      entry    = "any",
      protocol = "unspecified",
      port     = "unspecified"
    }
  }
}
variable "contracts" {
  description = "Create contracts with these filters"
  type        = map
  default     = {
    contract_http = {
      contract = "http",
      subject  = "http",
      filter   = "filter_http"
    },
    contract_icmp = {
      contract = "icmp",
      subject  = "icmp",
      filter   = "filter_icmp"
    },
    contract_SG_FTDv = {
      contract = "SG_FTDv",
      subject  = "SG_FTDv",
      filter   = "filter_any"
    }
  }
}
variable "ap" {
    description = "Create application profile"
    type        = string
    default     = "3T-App"
}
variable "epgs" {
    description = "Create epg"
    type        = map
    default     = {
        web     = {
            epg   = "web",
            bd    = "bd-web"
        },
        app     = {
            epg   = "app",
            bd    = "bd-app"
        },
        db      = {
            epg   = "db",
            bd    = "bd-db"
        }
    }
}
variable "epg_contracts" {
    description = "epg contracts"
    type        = map
    default     = {
        terraform_1 = {
            epg           = "app",
            contract      = "contract_http",
            contract_type = "consumer"
        },
        terraform_2 = {
            epg           = "app",
            contract      = "contract_icmp",
            contract_type = "consumer"
        },
        terraform_3 = {
            epg           = "db",
            contract      = "contract_icmp",
            contract_type = "provider"
        },
        terraform_4 = {
            epg           = "db",
            contract      = "contract_http",
            contract_type = "provider"
        },
        terraform_5 = {
            epg           = "app",
            contract      = "contract_SG_FTDv",
            contract_type = "provider"
        },
        terraform_6 = {
            epg           = "web",
            contract      = "contract_SG_FTDv",
            contract_type = "consumer"
        }
    }
}

variable "Devices" {
    description = "L4-L7 Device FirePower Threat Defense Definition"
    type = map
    default = {
       FTD232 = {
           name = "FTD232"
           device_type = "FW"
           managed = "false"
           interface_name = "Device-Interfaces"
           inside_interface = "Inside"
           outside_interface = "Outside"
           inside_bd = "bd-inside"
           outside_bd = "bd-outside"
           inside_pbr = "Inside_PBR"
           outside_pbr = "Outside_PBR"
           inside_pod = "1"
           outside_pod = "1"
           inside_node = "105"
           outside_node = "105"
           inside_eth = "48"
           outside_eth = "48"
           inside_vlan = "1088"
           outside_vlan = "1089"
           phy_domain = "phys"
           phy_vlan_pool = "VLAN-Phys"
           contract = "SG_FTDv"
       }
    }
}

variable "PBRs" {
    description = "List of PBRs to be defined"
    type = map
    default = {
      Inside_PBR = {
        name = "Inside_PBR"
        ipsla = "IPSLA_Inside"
        redirect_health = "Redirect_Inside"
        dest_type = "L3"
        max_threshold_percent   = "100"
        description             = "Inside PBR Policy"
        threshold_enable        = "yes"
        ip = "1.1.1.254"
        mac = "00:50:56:9b:21:d5"
      }
      Outside_PBR = {
        name = "Outside_PBR"
        ipsla = "IPSLA_Outside"
        redirect_health = "Redirect_Outside"
        dest_type = "L3"
        max_threshold_percent   = "100"
        description             = "Outside PBR Policy"
        threshold_enable        = "yes"
        ip = "2.2.2.254"
        mac = "00:50:56:9b:06:1e"
      }
    }
}

variable "vm" {
    type = map
    default = {
      web = {
        name = "web"
        cpu = 2
        memory = 2048
        ip = "10.4.1.188"
        netmask = "24"
        gateway = "10.4.1.254"
        domain = "mydomain.com"
        folder = "Terraform VMs"
      },
      app = {
        name = "app"
        cpu = 4
        memory = 4096
        ip = "10.5.1.188"
        netmask = "24"
        gateway = "10.5.1.254"
        domain = "mydomain.com"
        folder = "Terraform VMs"
      },
      db = {
        name = "db"
        cpu = 8
        memory = 4096
        ip = "10.6.1.188"
        netmask = "24"
        gateway = "10.6.1.254"
        domain = "mydomain.com"
        folder = "Terraform VMs"
      }
    }
}
