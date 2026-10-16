locals {
  vms_cloudinit = {
    "server" = {
      meta_data       = <<-EOF
        instance-id: k8s-master
        local-hostname: k8s-master
      EOF
      name_cloud_disk = "k8s-cloudinit-server"
      name_volume     = "k8s-cloudinit-server.iso"
    }
    "agente" = {
      meta_data       = <<-EOF
        instance-id: k8s-worker
        local-hostname: k8s-worker
      EOF
      name_cloud_disk = "k8s-cloudinit-worker"
      name_volume     = "k8s-cloudinit-worker.iso"
    }
  }
}

resource "libvirt_cloudinit_disk" "k8s_init" {
  for_each = local.vms_cloudinit
  name     = each.value.name_cloud_disk

  meta_data = each.value.meta_data

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml", {
    user     = var.vm_user
    password = var.vm_password
    ssh_key  = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })
}

resource "libvirt_volume" "k8s_init" {
  for_each = local.vms_cloudinit
  name     = each.value.name_volume
  pool     = libvirt_pool.k8s.name

  create = {
    content = {
      url = each.key == "server" ? libvirt_cloudinit_disk.k8s_init["server"].path : libvirt_cloudinit_disk.k8s_init["agente"].path
    }
  }
}
