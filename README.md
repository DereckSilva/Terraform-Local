# Terraform-Local — Laboratório DevOps


Infraestrutura **100% local** para estudar DevOps na prática: provisionamento com **Terraform**, orquestração com **Kubernetes (k3s)**, entrega contínua com **Argo CD** (GitOps) e uma stack de **observabilidade**. O cluster roda dentro de uma **máquina virtual na máquina local**, então dá para destruir e recriar o ambiente quando quiser, sem gastar com cloud e sem mexer no sistema do host.

---

## Objetivos

- Praticar **Infraestrutura como Código (IaC)** com Terraform.
- Criar e acessar uma **VM local** que serve de servidor do laboratório.
- Subir e operar um cluster Kubernetes leve com **k3s** dentro da VM.
- Aplicar **GitOps** com Argo CD: o estado do cluster vem do Git.
- Montar a observabilidade completa: **métricas, logs e traces**.
- Testar plugins e ferramentas do ecossistema cloud native (ingress, cert-manager, secrets, policies etc.).
- Documentar cada etapa para consultar depois.

---

## Stack

| Camada | Ferramenta | Papel |
|---|---|---|
| Virtualização | [KVM/libvirt](https://libvirt.org/), [VirtualBox](https://www.virtualbox.org/) ou [Multipass](https://multipass.run/) | Hospeda a VM onde o cluster roda |
| IaC | [Terraform](https://developer.hashicorp.com/terraform) | Cria a VM e provisiona namespaces, Helm releases e recursos base |
| Sistema da VM | Ubuntu Server (cloud-init) | SO da VM, configurado no primeiro boot |
| Cluster | [k3s](https://k3s.io/) | Kubernetes leve instalado dentro da VM |
| Pacotes | [Helm](https://helm.sh/) | Instalação de charts |
| GitOps | [Argo CD](https://argo-cd.readthedocs.io/) | Sincroniza as aplicações a partir deste repositório |
| Ingress | Traefik (padrão do k3s) / NGINX Ingress | Exposição de serviços |
| TLS | [cert-manager](https://cert-manager.io/) | Certificados (self-signed / CA local) |
| Métricas | [Prometheus](https://prometheus.io/) + [Grafana](https://grafana.com/) (kube-prometheus-stack) | Coleta e dashboards |
| Logs | [Loki](https://grafana.com/oss/loki/) + Promtail / Grafana Alloy | Agregação de logs |
| Traces | [Tempo](https://grafana.com/oss/tempo/) / [OpenTelemetry Collector](https://opentelemetry.io/) | Tracing distribuído |
| Alertas | Alertmanager | Regras e notificações |
| Segredos | [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) / External Secrets | Segredos versionados com segurança |
| Extras (opcional) | Argo Rollouts, Kyverno, MetalLB, Velero | Deploy progressivo, policies, LoadBalancer, backup |

---

## Arquitetura

```
┌────────────────────────── Máquina local (host) ──────────────────────────┐
│                                                                           │
│   Terraform · kubectl · helm · ssh                                        │
│        │                                                                  │
│        │ cria a VM / SSH / API do Kubernetes (6443)                       │
│        ▼                                                                  │
│   ┌──────────────────────── VM (Ubuntu Server) ───────────────────────┐   │
│   │                                                                    │   │
│   │   ┌──────────────────────── Cluster k3s ───────────────────────┐  │   │
│   │   │                                                             │  │   │
│   │   │   ┌─────────┐      ┌───────────┐                            │  │   │
│ Git ──────►│ Argo CD │─────►│   Apps    │                            │  │   │
│   │   │   └─────────┘      └─────┬─────┘                            │  │   │
│   │   │                          │                                  │  │   │
│   │   │   ┌──────────────────────▼──────────────────────┐           │  │   │
│   │   │   │ Observabilidade: Prometheus · Loki · Tempo  │           │  │   │
│   │   │   │                  Grafana · Alertmanager     │           │  │   │
│   │   │   └─────────────────────────────────────────────┘           │  │   │
│   │   └─────────────────────────────────────────────────────────────┘  │   │
│   └────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
```

**Fluxo:**
1. O Terraform cria a VM na máquina local (disco, rede, chave SSH e cloud-init).
2. No primeiro boot, o cloud-init instala o k3s dentro da VM.
3. O host se conecta à VM por **SSH** e ao cluster pelo **kubeconfig** copiado da VM.
4. O Terraform (providers `kubernetes`/`helm`) instala os componentes base: Argo CD, cert-manager e ingress.
5. O Argo CD lê os manifests deste repositório e sincroniza as aplicações (padrão *App of Apps*).
6. A stack de observabilidade coleta métricas, logs e traces do cluster e das aplicações.

---

## Máquina virtual

Todo o laboratório roda dentro de uma VM criada na máquina local. Assim o host fica limpo e o ambiente se aproxima de um servidor real, acessado remotamente.

**Recursos recomendados para a VM:**

| Recurso | Mínimo | Recomendado |
|---|---|---|
| vCPU | 2 | 4 |
| Memória | 4 GB | 8 GB |
| Disco | 30 GB | 50 GB |
| SO | Ubuntu Server 22.04 LTS | Ubuntu Server 24.04 LTS |

**Rede e conexão:**
- A VM recebe um IP fixo na rede interna do hypervisor (ex.: `192.168.122.10` no libvirt).
- A conexão do host com a VM é feita por **SSH com chave** (sem senha).
- O kubeconfig do k3s (`/etc/rancher/k3s/k3s.yaml`) é copiado para o host, trocando `127.0.0.1` pelo IP da VM.
- A porta **6443** (API do Kubernetes) e as portas do ingress (**80/443**) precisam estar acessíveis a partir do host.

**Opções para criar a VM:**
- **KVM/libvirt** + provider [`dmacvicar/libvirt`](https://registry.terraform.io/providers/dmacvicar/libvirt/latest) — melhor opção no Linux e toda criada via Terraform.
- **VirtualBox** / **Multipass** — mais simples para começar, mas com menos integração com o Terraform.

---

## Estrutura do repositório (planejada)

```
.
├── terraform/
│   ├── modules/
│   │   ├── vm/             # Criação da VM (disco, rede, cloud-init)
│   │   ├── k3s/            # Instalação/configuração do k3s na VM
│   │   └── helm-release/   # Releases Helm reutilizáveis
│   ├── environments/
│   │   └── local/          # Configuração do ambiente local
│   └── README.md
├── cloud-init/             # Templates de user-data da VM
├── kubernetes/
│   ├── bootstrap/          # App of Apps do Argo CD
│   ├── apps/               # Aplicações de exemplo
│   └── platform/           # Ingress, cert-manager, secrets, policies
├── observability/
│   ├── prometheus/
│   ├── grafana/            # Dashboards e datasources
│   ├── loki/
│   └── tempo/
├── scripts/                # Scripts auxiliares (setup, kubeconfig, teardown)
├── docs/                   # Anotações e guias de estudo
└── README.md
```

> A estrutura vai mudar conforme o laboratório evoluir.

---

## Pré-requisitos

**No host (máquina local):**
- Linux com **virtualização habilitada na BIOS** (Intel VT-x / AMD-V)
- Recursos livres para a VM: pelo menos **4 vCPUs e 8 GB de RAM**
- Um hypervisor: **KVM/libvirt** (`qemu-kvm`, `libvirt-daemon-system`, `virtinst`) ou VirtualBox/Multipass
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3
- Cliente SSH e um par de chaves (`ssh-keygen -t ed25519`)
- [Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) (opcional)

**Na VM:** nada manual — o cloud-init instala o k3s e as dependências.

---

## Boas práticas adotadas

- Nada é aplicado manualmente no cluster: o que existe vem do Terraform ou do Argo CD.
- A VM é descartável: qualquer configuração dela fica no cloud-init/Terraform, nunca feita à mão.
- `terraform.tfstate`, arquivos `*.tfvars` com dados sensíveis, chaves SSH e kubeconfigs **não** vão para o Git.
- Versões de providers, charts e imagens sempre fixadas.
- Mudanças passam por `terraform fmt`, `terraform validate` e `terraform plan` antes do `apply`.

---

## Referências

- [Documentação do Terraform](https://developer.hashicorp.com/terraform/docs)
- [Provider libvirt para Terraform](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [cloud-init](https://cloudinit.readthedocs.io/)
- [Documentação do k3s](https://docs.k3s.io/)
- [Documentação do Argo CD](https://argo-cd.readthedocs.io/)

---

## Licença

Projeto pessoal de estudo. Pode usar e adaptar à vontade.
