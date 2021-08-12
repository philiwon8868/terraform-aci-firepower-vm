# terraform-aci

Sample [Terraform Cloud](https://www.terraform.io/cloud) Integration with [Cisco ACI Network](https://www.cisco.com/go/aci).

This project is inspired by another project: https://github.com/christung16/terraform-mso-aci. It is to provide another working sample for those who would like to leverage on ACI's Terraform integration to experience the power of "Infrastructure As Code" - how to provision an ACI application network with a coding approach using Terraform HCL. This project utilize Terraform ACI integration only to provision the infrastructure on the overlay network policies, the L4-L7 Service Appliance and its associated PBR policies. In future revision, it may be extended to cover the underlay network and virtual compute infrastructure.

![image](https://user-images.githubusercontent.com/8743281/123520075-80b0fb00-d6e1-11eb-8ec5-909ccd8cfbcc.png)

The code will provision the followings onto an on-premise ACI private cloud environment:
* 3 End-Point Groups (EPGs): "Web", "App" and "DB"
* 2 Contracts:
  * Between "App" and "DB": TCP Port 80 (HTTP) and ICMP
  * Between "Web" and "App": permit ALL with a Service Graph
* Service Graph:
  * 2-Arm Routed Mode Unmanaged Firewall with Policy Based Redirect (PBR). The Firewall in this example is a Cisco Virtual ASA Firewall, however, it can be any service appliance.

![image](https://user-images.githubusercontent.com/8743281/123568965-10e16400-d7f8-11eb-9678-8d1c2fd02100.png)

* Associate VMM Domain to all 3 EPGs

## Pre-requisites

The repository is originally developed to be triggered by a [Terraform Cloud](https://www.terraform.io/cloud) account to execute planning, cost estimation and then deployment. Therefore, the login credentials to APIC controller as well as such parameters as the target ACI tenant name are defined in "Variables" section of the Terraform Cloud environment. If the code is to be tested in a private Terraform environment, one may have to manually include these parameters in the variable file.

## Requirements
Name | Version
---- | -------
[terraform](https://www.terraform.io/downloads.html)| >= 0.13

## Providers
Name | Version
---- | -------
aci | >= 0.4.1

## Compatibility
This sample is developed and tested with Cisco ACI 5.2(1g) and [Terraform Cloud](https://www.terraform.io/cloud) 1.0.1. However, it is expected to work with Cisco ACI >=4.2 and terraform >=0.13.

## Use Case Description

3-Tier application composing of Web, App and Database Tiers with 2-armed mode Service Graph between Web-Tier and App-Tier is a very typical application profile. This sample serves as a quick reference to create all the necessary components on APIC with Terraform HCL. More complicated applicatioon profiles can be derived from this sample.

## Installation

1. Install and setup your Terraform environment
2. Simply copy the 2 files (**main.tf** and **variable.tf**) onto your Terraform runtime environment

## Configuration

Basically all variables are defined in the file "variable.tf" except for APIC login credential, APIC IP address, the VMM domain name and the target ACI Tenant, which are defined in "Variables" section of the Terraform Cloud environment.
![image](https://user-images.githubusercontent.com/8743281/123569650-505c8000-d7f9-11eb-95e0-52588e2f06ae.png)

Modify **variable.tf** to include the parameters for APIC login credentials, the target ACI tenant name and the VMM domain name.

All variables in the sample, including the **"Devices"** (for the Service Appliance) and the **"PBRs"**, are self-explanatory and may be modified to cater for one's environment. However, there is a cross-reference of 2 parameters for them, which are highlighted below:

variable **"Devices"** {
```
description = "L4-L7 Device Definition"
    type = map
    default = {
       ASA1000v = {
           name = "ASA1000v"
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
           inside_node = "301"
           outside_node = "301"
           inside_eth = "8"
           outside_eth = "8"
           inside_vlan = "1088"
           outside_vlan = "1089"
           phy_domain = "phys"
           phy_vlan_pool = "Phys-Pool"
           contract = "SG_ASA1000v"
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
        ip = "3.3.3.254"
        mac = "00:50:56:98:4c:52"
      }
      Outside_PBR = {
        name = "Outside_PBR"
        ipsla = "IPSLA_Outside"
        redirect_health = "Redirect_Outside"
        dest_type = "L3"
        max_threshold_percent   = "100"
        description             = "Outside PBR Policy"
        threshold_enable        = "yes"
        ip = "4.4.4.254"
        mac = "00:50:56:98:dc:9e"
      }
    }
}
```
## Usage

*To provision:*
 * Execute with usual *terraform init*, *terraform plan* and *terraform apply*

*To destroy:*
 * Destroy the deployment with *terraform destroy* command.

## Next Project

After the deployment, one may find the virtual portgroups provisioned in the VMM domain for the 3 EPGs. One may need to manually associate these virtual portgroups to the testing VMs. In the upcoming project named "**terraform-aci-vm**", the testing VMs can be specified in the HCL, automatically provisioned and associated with their corresponding EPG's virtual portgroups.

## Credits and references

1. [Cisco Infrastructure As Code](https://developer.cisco.com/iac/)
2. [ACI provider Terraform](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs)
