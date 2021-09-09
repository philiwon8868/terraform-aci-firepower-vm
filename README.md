# terraform-aci-firepower-vm

Sample [Terraform Cloud](https://www.terraform.io/cloud) Integration with [Cisco ACI Network](https://www.cisco.com/go/aci).

This project is derived from a previous project: https://github.com/philiwon8868/terraform-aci. It is a working sample for those who would like to leverage on ACI's Terraform integration to experience the power of "Infrastructure As Code".

The sample ACI application environment is a typical 3-Tier "web-app-db", leveraging ACI contracts and L4-L7 service graph with a Cisco Firepower Threat Defense (FTD) Virtual Device to govern their communication policies. The FTD devie will be managed by Cisco Firepower Management Center (FMC). FMC has Terraform provider support which allows us to push policies to FMC console, at which security operator can deploy to the target FTD devices.

![image](https://user-images.githubusercontent.com/8743281/131292771-7ddd9e23-bbf6-4f70-aad4-ecfb7d1e7063.png)

Terraform HCL is a declarative language which will provision the followings onto an ACI private cloud environment: 
* 3 End-Point Groups (EPGs): "Web", "App" and "DB"
* 2 Contracts:
  * Between "App" and "DB": TCP Port 80 (HTTP) and ICMP
  * Between "Web" and "App": permit ALL with a Service Graph
* Service Graph:
  * 2-Arm Routed Mode Unmanaged Firewall with Policy Based Redirect (PBR).
![image](https://user-images.githubusercontent.com/8743281/131295043-5ce7fd77-a04d-46e4-96b2-c59d84c85a7b.png)
* FMC access rules
  * allow SSH (tcp port 22) from "inside" to "outside"
  * allow SSH (tcp port 22) from "outside" to "inside"
  ![image](https://user-images.githubusercontent.com/8743281/131295220-69fe776a-1eee-42c0-b1cc-d669637a479c.png)
* VM provisioning
  * Associate VMM Domain to all 3 EPGs
  * Provision 3 Sample VMs - one for each of the 3 EPGs
  * Attach these 3 VMs to their corresponding EPGs

## Pre-requisites

The repository is originally developed to be triggered by a [Terraform Cloud](https://www.terraform.io/cloud) account to execute planning, cost estimation and then deployment. Therefore, the login credentials to APIC controller as well as such parameters as the target ACI tenant name are defined in "Variables" section of the Terraform Cloud environment. If the code is to be tested in a private Terraform environment, one may have to manually include these parameters in the variable file.

## Requirements
Name | Version
---- | -------
[terraform](https://www.terraform.io/downloads.html)| >= 0.13

## Providers
Name | Version
---- | -------
aci | >= 0.7.1
fmc | >= 0.1.1
vsphere | >= 2.0.2

## Compatibility
This sample is developed and tested with Cisco ACI 5.2(1g) and [Terraform Cloud](https://www.terraform.io/cloud) 1.0.5. However, it is expected to work with Cisco ACI >=4.2 and terraform >=0.13.

## Use Case Description

3-Tier application composing of Web, App and Database Tiers with 2-armed mode Service Graph between Web-Tier and App-Tier is a very typical application profile. This sample serves as a quick reference to create all the necessary components on APIC with Terraform HCL. More complicated applicatioon profiles can be derived from this sample.

## Installation 

1. Install and setup your Terraform environment
2. Simply copy the 2 files (**main.tf** and **variable.tf**) onto your Terraform runtime environment

## Configuration

Basically all variables are defined in the file "variable.tf" except for APIC login credential, APIC IP address, the FMC host and user name, the VMM domain name and the target ACI Tenant, which are defined in "Variables" section of the Terraform Cloud environment.
![image](https://user-images.githubusercontent.com/8743281/131301973-1c99c8a8-678b-4286-8d3b-28cbb58aca22.png)

Modify **variable.tf** to include the parameters for APIC login credentials, the target ACI tenant name, the FMC host and the VMM domain name.

All variables in the sample, including the **"Devices"** (for the Service Appliance) and the **"PBRs"**, are self-explanatory and may be modified to cater for one's environment. However, there is a cross-reference of 2 parameters for them, which are highlighted below:

variable **"Devices"** {
```
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
```
}

In this case, the inside_pbr "**Inside_PBR**" and outside_pbr "**Outside_PBR**" in the **"Devices"** section must match the name of Inside_PBR and Outside_PBR in the variable section **"PBRs"**.

variable **"PBRs"** {
```
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
```
}

**Referring to such FMC definitions as FTD device, security zones and networks to define access rules...**
```
# FMC Section

data "fmc_access_policies" "acp" {
    name = "Access-Control-Policy"
}

data "fmc_security_zones" "inside" {
    name = "Inside"
}

data "fmc_security_zones" "outside" {
    name = "Outside"
}

data "fmc_file_policies" "file_policy" {
    name = "File_Policies"
}

resource "fmc_network_objects" "any_network" {
  name        = "Any_network"
  value       = "0.0.0.0/0"
}

data "fmc_devices" "device" {
    name = "FTD232"
}

resource "fmc_port_objects" "ssh" {
    name = "SSH_Access"
    port = "22"
    protocol = "TCP"
}
```

**Defining sample FMC Acess rules**

resource "**fmc_access_rules**" "access_rule1" {
```
    acp = data.fmc_access_policies.acp.id
    section = "mandatory"
    name = "SSH-Outside-In"
    action = "allow"
    enabled = true
    enable_syslog = true
    syslog_severity = "alert"
    send_events_to_fmc = true
    file_policy = data.fmc_file_policies.file_policy.id
    log_files = true
    log_end = true
    source_zones {
        source_zone {
            id = data.fmc_security_zones.outside.id
            type =  data.fmc_security_zones.outside.type
        }
    }
    destination_zones {
        destination_zone {
            id = data.fmc_security_zones.inside.id
            type =  data.fmc_security_zones.inside.type
        }
    }
    source_networks {
        source_network {
            id = fmc_network_objects.any_network.id
            type =  fmc_network_objects.any_network.type
        }
    }
    destination_networks {
        destination_network {
            id = fmc_network_objects.any_network.id
            type =  fmc_network_objects.any_network.type
        }
    }
    destination_ports {
        destination_port {
            id = fmc_port_objects.ssh.id
            type =  fmc_port_objects.ssh.type
        }
    }
    depends_on = [
      fmc_port_objects.ssh,
    ]
```
}

**Provisioning VMs for each of the 3 EPGs**

variable "**vm**" {
```
    type = map
    default = {
      web = {
        name = "web"
        cpu = 2
        memory = 4096
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
```
}

## Usage

*To provision:*
 * Execute with usual *terraform init*, *terraform plan* and *terraform apply*

*To destroy:*
 * Destroy the deployment with *terraform destroy* command.

## Credits and references

1. [Cisco Infrastructure As Code](https://developer.cisco.com/iac/)
2. [ACI provider Terraform](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs)
3. [FMC provider Terraform](https://registry.terraform.io/providers/CiscoDevNet/fmc/latest/docs)
