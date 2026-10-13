resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-22.04.qcow2"
  pool = libvirt_pool.k8s.name
  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
    }
  }
}
