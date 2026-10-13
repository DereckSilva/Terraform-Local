resource "libvirt_volume" "store_base" {
  name = "armazenamento-vm.qcow2"
  pool = libvirt_pool.k8s.name
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
