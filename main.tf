terraform {
  required_providers {
    aci = {
      source = "CiscoDevNet/aci"
      version = "0.7.1"
    }
    fmc = {
      source = "CiscoDevNet/fmc"
      version = "0.1.1"
    }
    vsphere = {
      source = "hashicorp/vsphere"
      version = "2.0.2"
    }
  }
}

# Provider for FMC - Firepower Management Center
provider "fmc" {
    fmc_username = var.fmc_user.username
    fmc_password = var.fmc_user.password
    fmc_host = var.fmc_user.host
    fmc_insecure_skip_verify = true
}

# Configure the provider with your Cisco APIC credentials.
provider "aci" {
  username = var.user.username
  password = var.user.password
  url      = var.user.url
  insecure = true # comment
}

# vSphere provider
provider "vsphere" {
  user           = var.vSphere_Site.admin
  password       = var.vSphere_Site.password
  vsphere_server = var.vSphere_Site.server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

# vSphere DC
data "vsphere_datacenter" "dc" {
  name = var.vSphere_Site.datacenter
}

data "vsphere_resource_pool" "pool" {
  name          = var.vSphere_Site.resource
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vSphere_Site.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "VM-Template"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  for_each = var.epgs
  name = "${var.tenant.name}|${var.ap}|${each.value.epg}"
  datacenter_id = data.vsphere_datacenter.dc.id
  depends_on = [
     aci_epg_to_domain.terraform_epg_domain,
  ]
}

resource "vsphere_virtual_machine" "vm" {
  for_each = var.vm
  name             = "${each.value.name}-vm"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus = each.value.cpu
  memory   = each.value.memory
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0
  folder = each.value.folder
  guest_id = data.vsphere_virtual_machine.template.guest_id


  disk {
    label = "disk0"
    size = data.vsphere_virtual_machine.template.disks.0.size
  }

  network_interface {
    network_id   = data.vsphere_network.network[each.value.name].id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "${each.value.name}-vm"
        domain    = each.value.domain
      }

      network_interface {
        ipv4_address = each.value.ip
        ipv4_netmask = each.value.netmask
      }

      ipv4_gateway = each.value.gateway
    }
  }
  depends_on = [
     aci_epg_to_domain.terraform_epg_domain,
  ]
}

# Define an ACI Tenant Resource.
resource "aci_tenant" "terraform_tenant" {
    name        = var.tenant.name
    description = "3-Tiers by terraform-aci-firepower-vm."
}

# Define an ACI Tenant VRF Resource.
resource "aci_vrf" "terraform_vrf" {
    tenant_dn   = aci_tenant.terraform_tenant.id
    description = "VRF Created Using terraform-aci-firepower-vm"
    name        = var.vrf
}

# Define an ACI Tenant BD Resource.
resource "aci_bridge_domain" "terraform_bd" {
    tenant_dn          = aci_tenant.terraform_tenant.id
    relation_fv_rs_ctx = aci_vrf.terraform_vrf.id
    description        = "BDs Created Using terraform-aci-firepower-vm"
    for_each           = var.bds
    name               = each.value.bd_name
}

# Define an ACI Tenant BD Subnet Resource.
resource "aci_subnet" "terraform_bd_subnet" {
    parent_dn   = aci_bridge_domain.terraform_bd[each.key].id
    description = "Subnet Created Using terraform-aci-firepower-vm"
    for_each    = var.bds
    ip          = each.value.subnet
}

# Define an ACI Filter Resource.
resource "aci_filter" "terraform_filter" {
    for_each    = var.filters
    tenant_dn   = aci_tenant.terraform_tenant.id
    description = "Filter ${each.key} created by terraform-aci-firepower-vm"
    name        = each.value.filter
}

# Define an ACI Filter Entry Resource.
resource "aci_filter_entry" "terraform_filter_entry" {
    for_each      = var.filters
    filter_dn     = aci_filter.terraform_filter[each.key].id
    name          = each.value.entry
    ether_t       = "ipv4"
    prot          = each.value.protocol
    d_from_port   = each.value.port
    d_to_port     = each.value.port
}

# Define an ACI Contract Resource.
resource "aci_contract" "terraform_contract" {
    for_each      = var.contracts
    tenant_dn     = aci_tenant.terraform_tenant.id
    name          = each.value.contract
    description   = "Contract created using terraform-aci-firepower-vm"
}

# Define an ACI Contract Subject Resource.
resource "aci_contract_subject" "terraform_contract_subject" {
    for_each                      = var.contracts
    contract_dn                   = aci_contract.terraform_contract[each.key].id
    name                          = each.value.subject
    relation_vz_rs_subj_filt_att  = [aci_filter.terraform_filter[each.value.filter].id]
}

# Define an ACI Application Profile Resource.
resource "aci_application_profile" "terraform_ap" {
    tenant_dn  = aci_tenant.terraform_tenant.id
    name       = var.ap
    description = "App Profile Created Using terraform-aci-firepower-vm"
}

# Define an ACI Application EPG Resource.
resource "aci_application_epg" "terraform_epg" {
    for_each                = var.epgs
    application_profile_dn  = aci_application_profile.terraform_ap.id
    name                    = each.value.epg
    relation_fv_rs_bd       = aci_bridge_domain.terraform_bd[each.key].id
    description             = "EPG Created Using terraform-aci-firepower-vm"
}

# Associate the EPG Resources with a VMM Domain.
resource "aci_epg_to_domain" "terraform_epg_domain" {
    for_each              = var.epgs
    application_epg_dn    = aci_application_epg.terraform_epg[each.key].id
    tdn   = var.vmm_domain.name
    res_imedcy = "pre-provision"
    instr_imedcy = "lazy"
}

# Associate the EPGs with the contrats
resource "aci_epg_to_contract" "terraform_epg_contract" {
    for_each           = var.epg_contracts
    application_epg_dn = aci_application_epg.terraform_epg[each.value.epg].id
    contract_dn        = aci_contract.terraform_contract[each.value.contract].id
    contract_type      = each.value.contract_type
}


# Define the L4-L7 Device inside the tenant.name
resource "aci_rest" "device" {
  for_each = var.Devices
  path = "api/node/mo/${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}.json"
  payload = <<EOF
{
  "vnsLDevVip":{
		"attributes":{
				"dn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}",
				"svcType":"${each.value.device_type}",
				"managed":"${each.value.managed}",
				"name":"${each.value.name}",
				"rn":"lDevVip-${each.value.name}",
				"status":"created"
			     },
		"children":[
				{"vnsCDev":{
					"attributes":{
							"dn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/cDev-${each.value.interface_name}",
							"name":"${each.value.interface_name}",
							"rn":"cDev-${each.value.interface_name}",
							"status":"created"
						     },
					"children":[
						    {"vnsCIf":
								{"attributes":{
									"dn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/cDev-${each.value.interface_name}/cIf-[${each.value.inside_interface}]",
									"name":"${each.value.inside_interface}",
									"status":"created"
									},
								 "children":[{
									"vnsRsCIfPathAtt":{
										"attributes":{
											"tDn":"topology/pod-${each.value.inside_pod}/paths-${each.value.inside_node}/pathep-[eth1/${each.value.inside_eth}]",
											"status":"created,modified"},
										"children":[]}
									    }]
								}},
						    {"vnsCIf":
								{"attributes":{
									"dn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/cDev-${each.value.interface_name}/cIf-[${each.value.outside_interface}]",
									"name":"${each.value.outside_interface}",
									"status":"created"
									},
								"children":[{
									"vnsRsCIfPathAtt":{
										"attributes":{
											"tDn":"topology/pod-${each.value.outside_pod}/paths-${each.value.outside_node}/pathep-[eth1/${each.value.outside_eth}]",
											"status":"created,modified"},
										"children":[]}
									   }]
							        }}
						 ]}
  				},
				{"vnsLIf":{
					"attributes":{
						"dn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/lIf-${each.value.inside_interface}",
						"name":"${each.value.inside_interface}",
						"encap":"vlan-${each.value.inside_vlan}",
						"status":"created,modified",
						"rn":"lIf-${each.value.inside_interface}"},
					"children":[
							{"vnsRsCIfAttN":{
								"attributes":{
									"tDn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/cDev-${each.value.interface_name}/cIf-[${each.value.inside_interface}]",
									"status":"created,modified"},
								"children":[]}
							}
						   ]
					  }
				},
			      	{"vnsLIf":{
					"attributes":{
						"dn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/lIf-${each.value.outside_interface}",
						"name":"${each.value.outside_interface}",
						"encap":"vlan-${each.value.outside_vlan}",
						"status":"created,modified",
						"rn":"lIf-${each.value.outside_interface}"},
					"children":[
							{"vnsRsCIfAttN":{
								"attributes":{
									"tDn":"${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/cDev-${each.value.interface_name}/cIf-[${each.value.outside_interface}]",
									"status":"created,modified"},
								"children":[]}
							}
						   ]
					}
				},
				{"vnsRsALDevToPhysDomP":{
					"attributes":{
						"tDn":"uni/phys-${each.value.phy_domain}",
						"status":"created"},
					"children":[]
					}
				}
			]
		}
}
EOF
}

## adding inside VLAN for interfaces of L4-L7 Devices to VLAN Pools
resource "aci_rest" "inside_vlan" {
  for_each = var.Devices
  path = "/api/node/mo/uni/infra/vlanns-[${each.value.phy_vlan_pool}]-dynamic/from-[vlan-${each.value.inside_vlan}]-to-[vlan-${each.value.inside_vlan}].json"
  payload = <<EOF
  {
	"fvnsEncapBlk":{
		"attributes":{
			"dn":"uni/infra/vlanns-[${each.value.phy_vlan_pool}]-dynamic/from-[vlan-${each.value.inside_vlan}]-to-[vlan-${each.value.inside_vlan}]",
			"from":"vlan-${each.value.inside_vlan}",
			"to":"vlan-${each.value.inside_vlan}",
			"descr":"Interface: ${each.value.inside_interface}",
			"allocMode":"static",
			"rn":"from-[vlan-${each.value.inside_vlan}]-to-[vlan-${each.value.inside_vlan}]",
			"status":"created"
		             },
		"children":[]
	                }
  }
  EOF
  depends_on = [
  aci_rest.device,
  ]
}

## adding outside VLAN for interfaces of L4-L7 Devices to VLAN Pools
resource "aci_rest" "outside_vlan" {
  for_each = var.Devices
  path = "/api/node/mo/uni/infra/vlanns-[${each.value.phy_vlan_pool}]-dynamic/from-[vlan-${each.value.outside_vlan}]-to-[vlan-${each.value.outside_vlan}].json"
  payload = <<EOF
  {
	  "fvnsEncapBlk":{
		"attributes":{
			"dn":"uni/infra/vlanns-[${each.value.phy_vlan_pool}]-dynamic/from-[vlan-${each.value.outside_vlan}]-to-[vlan-${each.value.outside_vlan}]",
			"from":"vlan-${each.value.outside_vlan}",
			"to":"vlan-${each.value.outside_vlan}",
			"descr":"Interface: ${each.value.outside_interface}",
			"allocMode":"static",
			"rn":"from-[vlan-${each.value.outside_vlan}]-to-[vlan-${each.value.outside_vlan}]",
			"status":"created"
		             },
		"children":[]
	                }
  }
  EOF
  depends_on = [
  aci_rest.device,
  ]
}

## Create the L4-L7 Service Graph Template
resource "aci_l4_l7_service_graph_template" "ServiceGraph" {
    for_each = var.Devices
    tenant_dn                         = aci_tenant.terraform_tenant.id
    name                              = format("%s%s","SG-",each.value.name)
    l4_l7_service_graph_template_type = "legacy"
    ui_template_type                  = "UNSPECIFIED"
    depends_on = [
    aci_rest.device,
    ]
}

# Create L4-L7 Service Graph Function Node
resource "aci_function_node" "ServiceGraph" {
    for_each = var.Devices
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.ServiceGraph[each.value.name].id
    name                            = each.value.name
    func_template_type              = "FW_ROUTED"
    func_type                       = "GoTo"
    is_copy                         = "no"
    managed                         = "no"
    routing_mode                    = "Redirect"
    sequence_number                 = "0"
    share_encap                     = "no"
    relation_vns_rs_node_to_l_dev   = "${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}"
    depends_on = [
    aci_rest.device,
    ]
}

# Create L4-L7 Service Graph template T1 connection.
resource "aci_connection" "t1-n1" {
    for_each = var.Devices
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.ServiceGraph[each.value.name].id
    name           = "C2"
    adj_type       = "L3"
    conn_dir       = "provider"
    conn_type      = "external"
    direct_connect = "no"
    unicast_route  = "yes"
    relation_vns_rs_abs_connection_conns = [
        aci_l4_l7_service_graph_template.ServiceGraph[each.value.name].term_prov_dn,
        aci_function_node.ServiceGraph[each.value.name].conn_provider_dn
    ]
    depends_on = [
    aci_rest.device,
    ]
}

# Create L4-L7 Service Graph template T2 connection.
resource "aci_connection" "n1-t2" {
    for_each = var.Devices
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.ServiceGraph[each.value.name].id
    name                            = "C1"
    adj_type                        = "L3"
    conn_dir                        = "provider"
    conn_type                       = "external"
    direct_connect                  = "no"
    unicast_route                   = "yes"
    relation_vns_rs_abs_connection_conns = [
        aci_l4_l7_service_graph_template.ServiceGraph[each.value.name].term_cons_dn,
        aci_function_node.ServiceGraph[each.value.name].conn_consumer_dn
    ]
    depends_on = [
    aci_rest.device,
    ]
}

# Create L4-L7 Logical Device Selection Policies / Logical Device Context
resource "aci_logical_device_context" "ServiceGraph" {
    for_each = var.Devices
    tenant_dn                          = aci_tenant.terraform_tenant.id
    ctrct_name_or_lbl                  = each.value.contract
    graph_name_or_lbl                  = format ("%s%s","SG-",each.value.name)
    node_name_or_lbl                   = aci_function_node.ServiceGraph[each.value.name].name
    relation_vns_rs_l_dev_ctx_to_l_dev = "${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}"
    #relation_vns_rs_l_dev_ctx_to_l_dev = aci_rest.device[each.value.name].id
    depends_on = [
    aci_rest.device,
    aci_service_redirect_policy.pbr,
    ]
}

# Create L4-L7 Logical Device Interface Contexts for consumer
resource "aci_logical_interface_context" "consumer" {
  for_each = var.Devices
	logical_device_context_dn        = aci_logical_device_context.ServiceGraph[each.value.name].id
	conn_name_or_lbl                 = "consumer"
	l3_dest                          = "yes"
	permit_log                       = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/lIf-${each.value.outside_interface}"
  relation_vns_rs_l_if_ctx_to_bd   = "${aci_tenant.terraform_tenant.id}/BD-${each.value.outside_bd}"
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.pbr[each.value.outside_pbr].id
  depends_on = [
    aci_rest.device, # wait until the device has been created
    aci_service_redirect_policy.pbr, # wait until the PBRs have been created
  ]
}

# Create L4-L7 Logical Device Interface Contexts for provider
resource "aci_logical_interface_context" "provider" {
  for_each = var.Devices
	logical_device_context_dn        = aci_logical_device_context.ServiceGraph[each.value.name].id
	conn_name_or_lbl                 = "provider"
	l3_dest                          = "yes"
	permit_log                       = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "${aci_tenant.terraform_tenant.id}/lDevVip-${each.value.name}/lIf-${each.value.inside_interface}"
  relation_vns_rs_l_if_ctx_to_bd   = "${aci_tenant.terraform_tenant.id}/BD-${each.value.inside_bd}"
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.pbr[each.value.inside_pbr].id
  depends_on = [
    aci_rest.device,
    aci_service_redirect_policy.pbr,
  ]
}

# Associate subject to Service Graph
resource "aci_contract_subject" "subj" {
  for_each = var.Devices
  contract_dn = "${aci_tenant.terraform_tenant.id}/brc-${each.value.contract}"
  name = "${each.value.contract}"
  relation_vz_rs_subj_graph_att = aci_l4_l7_service_graph_template.ServiceGraph[each.value.name].id
}

# Create IP SLA Monitoring Policy - Using REST-API call to APIC controller
resource "aci_rest" "ipsla" {
    for_each = var.PBRs
    path    = "api/node/mo/${aci_tenant.terraform_tenant.id}/ipslaMonitoringPol-${each.value.ipsla}.json"
    payload = <<EOF
{
	"fvIPSLAMonitoringPol": {
		"attributes": {
			"dn": "${aci_tenant.terraform_tenant.id}/ipslaMonitoringPol-${each.value.ipsla}",
			"name": "${each.value.ipsla}",
			"rn": "ipslaMonitoringPol-${each.value.ipsla}",
			"status": "created"
		},
		"children": []
	}
}
EOF
}

# Create Redirect Health Group for PBRs - Using REST-API call to APIC controller
resource "aci_rest" "rh" {
    for_each = var.PBRs
    path    = "api/node/mo/${aci_tenant.terraform_tenant.id}/svcCont/redirectHealthGroup-${each.value.redirect_health}.json"
    payload = <<EOF
{
	"vnsRedirectHealthGroup": {
		"attributes": {
			"dn": "${aci_tenant.terraform_tenant.id}/svcCont/redirectHealthGroup-${each.value.redirect_health}",
			"name": "${each.value.redirect_health}",
			"rn": "redirectHealthGroup-${each.value.redirect_health}",
			"status": "created"
		},
		"children": []
	}
}
EOF
}

# Associate IPSLA monitoring policy to the PBRs
resource "aci_service_redirect_policy" "pbr" {
  for_each = var.PBRs
  tenant_dn = aci_tenant.terraform_tenant.id
  name = each.value.name
  dest_type = each.value.dest_type
  max_threshold_percent = each.value.max_threshold_percent
  description = each.value.description
  threshold_enable = each.value.threshold_enable
  relation_vns_rs_ipsla_monitoring_pol = "${aci_tenant.terraform_tenant.id}/ipslaMonitoringPol-${each.value.ipsla}"
  depends_on = [ #wait until IPSLA has been completed
    aci_rest.ipsla,
  ]
}

# Associate Redirect Health Group to the PBRs
resource "aci_destination_of_redirected_traffic" "pbr" {
  for_each = var.PBRs
  service_redirect_policy_dn = aci_service_redirect_policy.pbr[each.value.name].id
  ip = each.value.ip
  mac = each.value.mac
  relation_vns_rs_redirect_health_group = "${aci_tenant.terraform_tenant.id}/svcCont/redirectHealthGroup-${each.value.redirect_health}"
  depends_on = [ #wait until Redirect Health Group has been completed
    aci_rest.rh,
  ]
}

# FMC Section
data "fmc_access_policies" "acp" {
    name = "Access-Control-Policy"
}

data "fmc_security_zones" "source_zone" {
    name = "Inside"
}

data "fmc_security_zones" "destination_zone" {
    name = "Outside"
}

resource "fmc_network_objects" "any_network" {
  name        = "Any_network"
  value       = "0.0.0.0/0"
}

data "fmc_devices" "device" {
    name = "FTD232"
}

resource "fmc_ftd_deploy" "ftd" {
    device = data.fmc_devices.device.id
    ignore_warning = false
    force_deploy = false
}

resource "fmc_port_objects" "ssh" {
    name = "SSH_Access"
    port = "22"
    protocol = "TCP"
}

resource "fmc_access_rules" "access_rule" {
    for_each = var.FMC_Access_Rules
    acp = data.fmc_access_policies.acp.id
    section = each.value.section
    name = each.value.name
    action = each.value.action
    enabled = each.value.enabled
    enable_syslog = each.value.enable_syslog
    syslog_severity = each.value.syslog_severity
    send_events_to_fmc = each.value.send_events_to_fmc
    log_files = each.value.log_files
    log_end = each.value.log_end
    source_zones {
        source_zone {
            id = "data.fmc_security_zones.${each.value.source_zone}.id"
            type =  "data.fmc_security_zones.${each.value.source_zone}.type"
        }
    }
    destination_zones {
        destination_zone {
            id = "data.fmc_security_zones.${each.value.destination_zone}.id"
            type =  "data.fmc_security_zones.${each.value.destination_zone}.type"
        }
    }
    source_networks {
        source_network {
            id = "data.fmc_network_objects.${each.value.any_network}.id"
            type =  "data.fmc_network_objects.${each.value.any_network}.type"
        }
    }
    destination_networks {
        destination_network {
            id = "data.fmc_network_objects.${each.value.any_network}.id"
            type =  "data.fmc_network_objects.${each.value.any_network}.type"
        }
    }
    destination_ports {
        destination_port {
            id = "data.fmc_port_objects.${each.value.service}.id"
            type =  "data.fmc_port_objects.${each.value.service}.type"
        }
    }
#    urls {
#        url {
#            id = data.fmc_url_objects.Any.id
#            type = "Url"
#        }
#    }
    #ips_policy = data.fmc_ips_policies.ips_policy.id
    #syslog_config = data.fmc_syslog_alerts.syslog_alert.id
    #new_comments = [ "New", "comment" ]
}
