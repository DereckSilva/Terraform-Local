resource "libvirt_cloudinit_disk" "k8s_init" {
  name = "k8s-cloudinit"

  meta_data = <<-EOF
    instance-id: k8s-master
    local-hostname: k8s-master
  EOF

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml", {
    user     = var.vm_user
    password = var.vm_password
    ssh_key  = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })
}

resource "libvirt_volume" "k8s_init" {
  name = "k8s-cloudinit.iso"
  pool = libvirt_pool.k8s.name

  create = {
    content = {
      url = libvirt_cloudinit_disk.k8s_init.path
    }
  }
}
