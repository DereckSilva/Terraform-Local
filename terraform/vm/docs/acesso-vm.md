# Acesso e verificação da VM

Tutorial para subir, verificar e acessar a VM `ubunutu-cluster-vm` criada por este módulo Terraform (provider `dmacvicar/libvirt` 0.9.9).

## Visão geral do que é criado

| Recurso | Nome no libvirt | Arquivo |
|---|---|---|
| Pool de armazenamento (`dir`) | `k8s-pool` em `/var/lib/libvirt/images/k8s` | `pool.tf` |
| Imagem base Ubuntu 22.04 | `ubuntu-22.04.qcow2` | `so.tf` |
| Disco da VM (25GB, thin, usa a imagem base como backing store) | `armazenamento-vm.qcow2` | `store.tf` |
| ISO do cloud-init (usuário, senha, chave SSH) | `k8s-cloudinit.iso` | `cloudinit.tf` |
| Rede NAT `192.168.100.0/24` | `cluster-network` | `network.tf` |
| VM (2 vCPU, 6GB RAM, chipset q35) | `ubunutu-cluster-vm` | `vm.tf` |

Dados de rede da VM:

| Item | Valor |
|---|---|
| IP fixo (reserva DHCP pelo MAC `52:54:00:00:00:10`) | `192.168.100.50` |
| Gateway / bridge no host (`virbr1`) | `192.168.100.5` |
| Hostname | `k8s-master` (`api.k8s.local` no DNS da rede) |
| DNS externo | `8.8.8.8` |

## 1. Pré-requisitos no host

Adicione seu usuário ao grupo `libvirt` para usar o `virsh` sem `sudo`:

```bash
sudo usermod -aG libvirt $USER
newgrp libvirt   # ou faça logout/login
```

Aponte o `virsh` para a conexão de sistema (a mesma usada no `main.tf`). Vale colocar no `~/.bashrc`:

```bash
export LIBVIRT_DEFAULT_URI=qemu:///system
```

Crie o `terraform.tfvars` a partir do exemplo e confira se a chave pública existe:

```bash
cp terraform.tfvars.example terraform.tfvars
ls ~/.ssh/id_ed25519.pub   # ou o caminho definido em ssh_public_key_path
```

Se não existir, gere uma: `ssh-keygen -t ed25519`.

## 2. Subir a VM

```bash
terraform init
terraform plan
terraform apply
```

> No provider 0.9.x o `libvirt_domain` não liga a VM por padrão: por isso o `vm.tf` tem `running = true`. Sem isso, a VM fica só definida (desligada).

## 3. Verificar pelo host

```bash
virsh list --all                          # ubunutu-cluster-vm deve estar "running"
virsh net-list --all                      # cluster-network ativa
virsh net-dhcp-leases cluster-network     # 192.168.100.50 / k8s-master
virsh domifaddr ubunutu-cluster-vm        # IP da VM
virsh pool-list --all                     # k8s-pool ativo
virsh vol-list k8s-pool                   # imagem base, disco da VM e ISO do cloud-init
ip -br link | grep -E 'virbr1|vnet'       # virbr1 UP e uma interface vnetX
ping -c3 192.168.100.50
```

## 4. Conectar

### SSH (principal)

```bash
ssh -i ~/.ssh/id_ed25519 <vm_user>@192.168.100.50
```

Para encurtar, adicione ao `~/.ssh/config`:

```
Host k8s-master
    HostName 192.168.100.50
    User <vm_user>
    IdentityFile ~/.ssh/id_ed25519
```

Depois é só `ssh k8s-master`.

### Console serial (quando SSH/rede falham)

```bash
virsh console ubunutu-cluster-vm   # login: vm_user / vm_password do terraform.tfvars
                                   # sair: Ctrl+]
```

Também dá para abrir a tela gráfica pelo `virt-manager`.

## 5. Verificar dentro da VM

```bash
cloud-init status --wait           # deve terminar em "status: done"
hostnamectl                        # hostname k8s-master
ip -br a                           # interface com 192.168.100.50/24
df -h /                            # ~25G no / (disco expandido pelo cloud-init)
sudo whoami                        # root, sem pedir senha
systemctl status qemu-guest-agent  # active (running)
ping -c2 8.8.8.8                   # saída para a internet via NAT
resolvectl query google.com        # resolução DNS
```

Logs do cloud-init: `/var/log/cloud-init.log` e `/var/log/cloud-init-output.log`.

Com o guest agent ativo, o host também consegue consultar a VM por ele:

```bash
virsh domifaddr ubunutu-cluster-vm --source agent
```

## 6. Operações do dia a dia

```bash
virsh shutdown ubunutu-cluster-vm   # desligar de forma limpa
virsh start ubunutu-cluster-vm      # ligar
virsh reboot ubunutu-cluster-vm     # reiniciar
virsh destroy ubunutu-cluster-vm    # "puxar da tomada" (forçar desligamento)
terraform destroy                   # remover tudo (VM, disco, rede, pool)
```

## 7. Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `Storage pool 'default' not found` | Host sem o pool `default` | Os volumes usam `libvirt_pool.k8s.name` (pool próprio em `pool.tf`) |
| `Could not open '.../ubuntu-22.04.qcow2': Permission denied` mesmo com dono `libvirt-qemu` | AppArmor: com o disco referenciado por pool/volume (`source.volume`), o `virt-aa-helper` não segue o backing store e não libera a imagem base para o QEMU | No `vm.tf`, usar `source = { file = { file = libvirt_volume.<nome>.path } }` em vez de `source.volume` |
| `systemctl status qemu-guest-agent` → `inactive (dead)` | VM sem o canal virtio `org.qemu.guest_agent.0` | Manter `channels` no `vm.tf` e desligar/ligar a VM (`virsh shutdown` + `virsh start`; reboot de dentro não basta) |
| `cloud-init status` → `error` com `Runparts: 1 failures (runcmd)` | `systemctl enable` falha: a unit do guest agent é `static` | Usar `systemctl start qemu-guest-agent` no `runcmd`; para rodar o cloud-init de novo: `sudo cloud-init clean --logs --reboot` |
| `driver: raw` para a imagem base no log do QEMU | `backing_store` sem formato | Manter `format = { type = "qcow2" }` no `backing_store` do `store.tf` |
| `Update Not Supported` em `libvirt_volume` | Provider 0.9.x não altera volumes existentes | `terraform apply -replace=libvirt_volume.<nome>` |
| `an os <type> must be specified` | Provider 0.9.x não preenche o bloco `os` | Manter `os = { type = "hvm", ... }` no `vm.tf` |
| VM não liga após o apply | Falta `running = true` | Adicionar no `vm.tf` ou `virsh start ubunutu-cluster-vm` |
| `failed to connect to the hypervisor` / permissão negada | Usuário fora do grupo `libvirt` | Ver seção 1 |
| `ping` não responde | VM desligada ou ainda no boot | `virsh list --all` e `virsh console` |
| `Permission denied (publickey)` | cloud-init não terminou ou chave errada | Pelo console: `cloud-init status` e `cat ~/.ssh/authorized_keys` |
| IP diferente de `.50` | MAC do `vm.tf` diferente da reserva no `network.tf` | Os dois devem ser `52:54:00:00:00:10` |
| Sem internet dentro da VM | NAT/firewall do host | No host: `sudo iptables -t nat -L -n \| grep 192.168.100` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | VM recriada (nova chave de host) | `ssh-keygen -R 192.168.100.50` |
