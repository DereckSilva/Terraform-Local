resource "libvirt_pool" "k8s" {
  name = "k8s-pool"
  type = "dir" # pool baseado em diretório no host

  target = {
    # precisa ficar dentro de /var/lib/libvirt/images: o AppArmor do Ubuntu
    # só deixa o virt-aa-helper ler discos (e achar o backing store) ali
    path = "/var/lib/libvirt/images/k8s"
  }

  create = {
    build     = true # cria o diretório do pool
    start     = true
    autostart = true
  }
}
