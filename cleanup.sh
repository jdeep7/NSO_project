#!/bin/bash

# Checking if the required arguments are present - the openrc, the tag and the ssh_key
# The program will not run if these arguments are not present.
: ${1:?" Please specify the cloud_config, id_tag, and access_key"}
: ${2:?" Please specify the cloud_config, id_tag, and access_key"}
: ${3:?" Please specify the cloud_config, id_tag, and access_key"}


current_time=$(date)
cloud_config_file=${1}     # Fetching the cloud configuration file
id_tag=${2}                # Fetching the tag for easy identification of items
access_key=${3}            # Fetching the ssh_key for secure remote access
server_count=$(grep -E '[0-9]' servers.conf) # Fetching the number of nodes from servers.conf


# Sourcing cloud configuration file
echo "$current_time Cleaning up $id_tag using $cloud_config_file"
source $cloud_config_file


# Define variables
network_name="${2}_network"
subnet_name="${2}_subnet"
keypair_name="${2}_key"
router_name="${2}_router"
security_group_name="${2}_security_group"
proxy_server_name="${2}_proxy"
bastion_server_name="${2}_bastion"
dev_server_name="${2}_dev"

ssh_config_file="config"
known_hosts_file="known_hosts"
hosts_file="hosts"
floating_ip_file="$(cat floating_ip2)"

# Retrieving the list of servers with the tag
server_list=$(openstack server list --name "$id_tag" -c ID -f value)
server_count=$(echo "$server_list" | wc -l)
# Deleting each server
if [ -n "$server_list" ]; then
  echo "$(date) We have $server_count nodes, releasing them"
  for server_id in $server_list; do
    openstack server delete $server_id
  done
  echo "$(date) Nodes are gone"
else
  echo "$(date) No nodes to release"
fi


# Deleting the keypair corresponding to the tag
keypair_list=$(openstack keypair list -f value -c Name | grep "$id_tag*")

if [ -n "$keypair_list" ]; then
  for key_name in $keypair_list; do  
    openstack keypair delete $key_name
  done
  echo "$(date) Removed $keypair_name key"
else
  echo "$(date) No keypair to delete."
fi



floating_ips=$(openstack floating ip list --status DOWN -f value -c "Floating IP Address")
# floating_ip_list=(${existing_floating_ip// / })

if [ -n "$floating_ips" ]; then
  for floating_ip in $floating_ips; do
    openstack floating ip delete "$floating_ip"
  done
  echo "$(date) Removed all floating IPs"
else
  echo "$(date) No floating IPs to remove"
fi



# Removing the subnet attached to the networks and router
# subnet_id=$(openstack router show "${router_name}" -f json -c interfaces_info | grep -oP '(?<="subnet_id": ")[^"]+' | awk '{print $1}')

subnet_list=$(openstack subnet list --tag "${id_tag}" -c ID -f value)
if [ -n "${subnet_list}" ]; then
  for subnet_id in ${subnet_list}; do
    openstack router remove subnet "${router_name}" "$subnet_id"
    openstack subnet delete "$subnet_id"
  done
  echo "$(date) Removed ${subnet_name} subnet"
else
  echo "$(date) No subnets to remove"
fi

# remove_ext_gateway=$(openstack router unset --external-gateway ${existing_routers}) 

# Removing the routers corresponding to the tag
router_list=$(openstack router list --tag ${id_tag} -f value -c Name)
if [ -n "$router_list" ]; then
  for router_name in $router_list; do
    openstack router delete "$router_name"
  done
  echo "$(date) Removed ${router_name} router" 
else
  echo "$(date) No routers to remove"
fi


# Removing the networks corresponding to the tag
network_list=$(openstack network list --tag ${id_tag} -f value -c Name)
if [ -n "$network_list" ]; then
  for network_name in $network_list; do
    openstack network delete "$network_name"
  done
  echo "$(date) Removed ${network_name} network"
else
  echo "$(date) No networks to remove"
fi


# Removing security groups corresponding to the tag
security_group_list=$(openstack security group list --tag $id_tag -f value -c Name)
if [ -n "$security_group_list" ]; then
  for sec_group_name in $security_group_list; do
    openstack security group delete "$sec_group_name"
  done
  echo "$(date) Removed ${security_group_name} security group"
else
  echo "$(date) No security groups to remove"
fi

if [[ -f "$ssh_config_file" ]] ; then
    rm "$ssh_config_file"
fi

if [[ -f "$known_hosts_file" ]] ; then
    rm "$known_hosts_file"
fi

if [[ -f "floating_ip1" ]] ; then
    rm "floating_ip1"
fi

if [[ -f "floating_ip2" ]] ; then
    rm "floating_ip2"
fi

if [[ -f "$hosts_file" ]] ; then
    rm "$hosts_file"
fi
