# Ansible

Comandos utilizados para gerenciar as máquinas definidas no `inventory.ini`.

> Todos os comandos devem ser executados de dentro do diretório `ansible/`.

## Inventário

O arquivo `inventory.ini` define os hosts gerenciados pelo Ansible, organizados em grupos:

```ini
[myhosts]
192.168.100.50
```

## Comandos

### Listar o inventário

```bash
ansible-inventory -i inventory.ini --list
```

Lista os hosts que o Ansible vai gerenciar, ou seja, as máquinas que vão receber as tarefas de configuração. A saída é um JSON com os grupos e os IPs definidos no inventário. Serve para conferir se o Ansible está lendo o `inventory.ini` corretamente.

| Parâmetro | Descrição |
|-----------|-----------|
| `-i inventory.ini` | Arquivo de inventário a ser usado |
| `--list` | Exibe todos os grupos e hosts em formato JSON |

### Testar a comunicação com os hosts

```bash
ansible myhosts -m ping -i inventory.ini
```

Testa a comunicação com cada máquina do grupo `myhosts`. Se a máquina responder `"ping": "pong"`, o Ansible conseguiu se conectar a ela.

> **Atenção:** não é um ping de rede (ICMP). O módulo `ping` do Ansible conecta na máquina via **SSH** e verifica se há um **Python** utilizável nela. Assim, ele confirma que o Ansible realmente consegue executar tarefas no host.

| Parâmetro | Descrição |
|-----------|-----------|
| `myhosts` | Grupo (ou host) do inventário em que o comando será executado |
| `-m ping` | Módulo a ser executado (`ping`) |
| `-i inventory.ini` | Arquivo de inventário a ser usado |

### Executar um playbook

```bash
ansible-playbook -i inventory.ini playhooks/install-k3s.yaml
```

Executa as tasks do playbook `install-k3s.yaml` nas máquinas configuradas no `inventory.ini`.

| Parâmetro | Descrição |
|-----------|-----------|
| `ansible-playbook` | Comando do Ansible que executa playbooks |
| `-i inventory.ini` | Arquivo de inventário com os hosts onde as tasks serão executadas |
| `playhooks/install-k3s.yaml` | Caminho do playbook com as tasks a serem executadas |
