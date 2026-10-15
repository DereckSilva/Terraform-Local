resource "libvirt_network" "vm-network" {
  #inserir for each
  name      = "cluster-network"
  autostart = true
  forward = {
    mode = "nat" # busca info na internet para as vms
  }

  # DNS local
  domain = {
    name       = "k8s.local"
    local_only = "yes"
  }

  dns = {
    enable = "yes" # comunicar via dns

    forwarders = [{
      addr = "8.8.8.8" # oq não é local manda para esse ip
    }]

    host = [{
      # cada ip recebe um hostname
      ip = "192.168.100.50"
      hostnames = [{
        hostname = "api.k8s.local"
      }]
    }]
  }

  ips = [{
    address = "192.168.100.5"
    prefix  = 24

    dhcp = {
      ranges = [{
        start = "192.168.100.100"
        end   = "192.168.100.200"
      }]

      hosts = [
        { mac = "52:54:00:00:00:10", name = "k8s-master", ip = "192.168.100.50" },
      ]
    }
  }]
}
