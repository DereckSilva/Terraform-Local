locals {
  vms_store = {
    "server" = {
      name = "armazenamento-vm-server.qcow2"
    }
    "agente" = {
      name = "armazenamento-vm-worker.qcow2"
    }
  }
}

resource "libvirt_volume" "store_base" {
  for_each = local.vms_store
  name     = each.value.name
  pool     = libvirt_pool.k8s.name
  target = {
    format = {
      type = "qcow2"
    }
  }
  capacity = 26843545600 # 25GB

  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2" # sem isso o libvirt trata a imagem base como raw
    }
  }
}
