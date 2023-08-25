

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/hosts.tftpl", {

    ####################### Global Parameters #######################
    ssh_private_key_file = var.ssh_private_key_file

    ####################### NFS VM parameters #######################
    nfs_ip          = var.nfs_ip
    nfs_vm_user     = var.nfs_vm_user
    nfs_vm_password = var.nfs_vm_password

    ####################### DNS VM parameters #######################
    dns_ip          = var.dns_ip
    dns_vm_user     = var.dns_vm_user
    dns_vm_password = var.dns_vm_password

    ####################### K8s Master parameters #######################
    k8s_master_amount = var.k8s_master_amount
    master_user       = var.master_user
    master_ips        = var.master_ips
    master_password   = var.master_password

    ####################### K8s Workers parameters #######################
    k8s_worker_amount = var.k8s_worker_amount
    worker_user       = var.worker_user
    worker_ips        = var.worker_ips
    worker_password   = var.worker_password
  })

  filename        = "../../servers-setup/hosts.yaml"
  file_permission = "0600"
}