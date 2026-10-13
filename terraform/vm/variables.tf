variable "vm_user" {
  description = "Usuário criado na VM pelo cloud-init"
  type        = string
}

variable "vm_password" {
  description = "Senha do usuário"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Caminho da chave pública SSH liberada para o usuário da VM"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
