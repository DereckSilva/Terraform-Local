resource "libvirt_domain" "ubunutu-vm-k8s" {
  name        = "ubunutu-cluster-vm"
  memory      = 6144
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
            file = libvirt_volume.store_base.path
          }
        }
        driver = { type = "qcow2" }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"
        source = {
          file = {
            file = libvirt_volume.k8s_init.path
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
          network = libvirt_network.vm-network.name
        }
      }
      mac = {
        address = "52:54:00:00:00:10"
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
