
# ####################### DNS VM #######################
module "dns" {
  source = "./modules/proxmox_vms"

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.dns_vm_id
  vm_name = var.dns_vm_name

  # VM resources
  vm_cpu       = var.dns_cpu
  vm_memory    = var.dns_vm_memory
  vm_disk_size = var.dns_vm_disk_size

  # VM user
  vm_user          = var.dns_vm_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.dns_vm_network_ip_suffix

  # VM tags
  vm_tags = var.dns_vm_tags
}


# ####################### NFS VM #######################
module "nfs" {
  source = "./modules/proxmox_vms"

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.nfs_vm_id
  vm_name = var.nfs_vm_name

  # VM resources
  vm_cpu       = var.nfs_cpu
  vm_memory    = var.nfs_vm_memory
  vm_disk_size = var.nfs_vm_disk_size

  # VM user
  vm_user          = var.nfs_vm_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.nfs_vm_network_ip_suffix

  # VM tags
  vm_tags = var.nfs_vm_tags
}






# ####################### k8s_master VM #######################
module "k8s_master" {

  source = "./modules/proxmox_vms"

  loop = var.k8s_master_amount

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.k8s_master_id
  vm_name = var.k8s_master_name

  # VM resources
  vm_cpu       = var.k8s_master_cpu
  vm_memory    = var.k8s_master_memory
  vm_disk_size = var.k8s_master_disk_size

  # VM user
  vm_user          = var.k8s_master_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.k8s_master_network_ip_suffix

  # VM tags
  vm_tags = var.k8s_master_tags
}

# ####################### k8s_worker VM #######################
module "k8s_worker" {

  source = "./modules/proxmox_vms"

  loop = var.k8s_worker_amount

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.k8s_worker_id
  vm_name = var.k8s_worker_name

  # VM resources
  vm_cpu       = var.k8s_worker_cpu
  vm_memory    = var.k8s_worker_memory
  vm_disk_size = var.k8s_worker_disk_size

  # VM user
  vm_user          = var.k8s_worker_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.k8s_worker_network_ip_suffix

  # VM tags
  vm_tags = var.k8s_worker_tags
}
