locals {
  vms = {
    "server" = {
      name         = "ubunutu-cluster-vm-server"
      address      = "52:54:00:00:00:10"
      file_disk    = libvirt_volume.store_base["server"].path
      file_cdroom  = libvirt_volume.k8s_init["server"].path
      name_network = libvirt_network.vm-network.name
    }
    "agente" = {
      name         = "ubunutu-cluster-vm-worker"
      address      = "52:54:00:00:00:20"
      file_disk    = libvirt_volume.store_base["agente"].path
      file_cdroom  = libvirt_volume.k8s_init["agente"].path
      name_network = libvirt_network.vm-network.name
    }
  }
}

resource "libvirt_domain" "ubunutu-vm-k8s" {
  for_each    = local.vms
  name        = each.value.name
  memory      = each.key == "server" ? 3072 : 2048 # master 3GB, worker 2GB
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"
  running     = true # sobe a vm

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  devices = {
    disks = [
      {
        # caminho do arquivo (e não pool/volume): assim o virt-aa-helper segue
        # o backing store e libera a imagem base no perfil AppArmor da VM
        source = {
          file = {
            file = each.value.file_disk
          }
        }
        driver = { type = "qcow2" }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"
        source = {
          file = {
            file = each.value.file_cdroom
          }
        }
        target = { dev = "sda", bus = "sata" }
      },
    ]
    # canal virtio do qemu-guest-agent: sem ele o serviço não sobe na VM
    channels = [{
      source = {
        unix = { mode = "bind" } # sem path: o libvirt gera o socket sozinho
      }
      target = {
        virt_io = { name = "org.qemu.guest_agent.0" }
      }
    }]
    interfaces = [{
      source = {
        network = {
          network = each.value.name_network
        }
      }
      mac = {
        address = each.value.address
      }
      model = {
        type = "virtio"
      }
      wait_for_ip = {
        source  = "lease"
        timeout = 300
      }
    }]
  }
}
