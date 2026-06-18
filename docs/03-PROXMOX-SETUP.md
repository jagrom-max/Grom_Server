# 🖥️ Instalação e Configuração do Proxmox VE

## Download e Instalação

1. **Download**: https://www.proxmox.com/en/downloads → Proxmox VE ISO atual
2. **Pendrive bootável**: Usar Balena Etcher ou Rufus
3. **Boot**: USB no Mini PC, selecionar Install Proxmox VE

### Opções de Instalação
- **Filesystem**: ext4 (SSD único, melhor performance)
- **Hostname**: `grom-pve.local`
- **IP temporário**: `192.168.0.100/24`
- **Gateway**: `192.168.0.1`
- **DNS**: `1.1.1.1, 8.8.8.8`
- **Senha root**: Definir senha forte
- **Email**: `grom.servidor@gmail.com` para alertas operacionais

---

## Pós-Instalação

Executar o script `scripts/proxmox/post-install.sh` que realiza:

1. Configurar repositório no-subscription
2. Atualizar sistema
3. Instalar pacotes úteis
4. Configurar bridges de rede (vmbr0/vmbr1)
5. Habilitar IOMMU para passthrough
6. Configurar NTP
7. Configurar SMART/sensores
8. Habilitar 2FA

---

## Configuração das Bridges de Rede

Após instalação, editar `/etc/network/interfaces` conforme doc `02-HARDWARE-REDE.md`.

### Verificar interfaces:
```bash
ip addr show
lspci | grep -i net
lsusb | grep -i net
```

---

## Criação dos Containers e VM

### VM: OPNsense Firewall (VM ID: 100)
```bash
# Download da ISO
# Usar https://opnsense.org/download/ com arquitetura amd64 e tipo dvd.
# Baixar tambem checksum/assinatura e validar antes de mover para o Proxmox.
mv OPNsense-*-dvd-amd64.iso /var/lib/vz/template/iso/

# Criar VM via CLI
qm create 100 --name opnsense \
  --memory 2048 --cores 2 --cpu host \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:20,iothread=1,discard=on \
  --cdrom local:iso/OPNsense-24.7-dvd-amd64.iso \
  --boot order=scsi0 --ostype l26 \
  --onboot 1 --startup order=1
```

### Containers LXC
Usar script `scripts/proxmox/create-containers.sh` para criar todos os containers automaticamente.

---

## Acesso ao Proxmox

- **URL**: `https://<IP>:8006`
- **Usuário**: `root@pam`
- **2FA**: Configurar TOTP após primeiro login

> ⚠️ **IMPORTANTE**: Nunca expor a porta 8006 à internet. Acessar apenas via VPN ou rede local.
