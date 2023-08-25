provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret

  pm_tls_insecure = true
  pm_timeout      = 1000
}

resource "proxmox_vm_qemu" "this" {

  count = var.loop

  ####################### Generic Settings #######################
  target_node = var.proxmox_target_node
  onboot      = var.on_boot
  agent       = var.agent
  clone       = var.proxmox_vm_template_name
  sockets     = var.vm_socket

  network {
    bridge = var.bridge_network
    model  = var.network_model
  }

  disk {
    type    = var.disk_type
    storage = var.disk_storage
    size    = var.vm_disk_size
  }

  ####################### VM Settings #######################
  vmid   = var.loop > 1 ? var.vm_id + count.index + 1 : var.vm_id
  name   = var.loop > 1 ? format("%s", var.vm_name[count.index]) : var.vm_name[0]
  cores  = var.vm_cpu
  memory = var.vm_memory

  ####################### Cloud Init Settings #######################
  ciuser     = var.loop > 1 ? format("%s-${count.index + 1}", var.vm_user) : var.vm_user
  cipassword = var.vm_user_password
  ipconfig0  = "ip=${cidrhost(var.network_ip_cidr, var.vm_network_ip_suffix + count.index)}/24,gw=${cidrhost(var.network_ip_cidr, 1)}"

  tags = var.vm_tags
}