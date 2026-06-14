# 🖥️ Instalação e Configuração do Proxmox VE

## Download e Instalação

1. **Download**: https://www.proxmox.com/downloads → Proxmox VE 8.x ISO
2. **Pendrive bootável**: Usar Balena Etcher ou Rufus
3. **Boot**: USB no Mini PC, selecionar Install Proxmox VE

### Opções de Instalação
- **Filesystem**: ext4 (SSD único, melhor performance)
- **Hostname**: `grom-pve.local`
- **IP temporário**: `192.168.0.100/24`
- **Gateway**: `192.168.0.1`
- **DNS**: `1.1.1.1, 8.8.8.8`
- **Senha root**: Definir senha forte
- **Email**: Seu email para alertas

---

## Pós-Instalação

Executar o script `scripts/proxmox/post-install.sh` que realiza:

1. Remover popup de assinatura enterprise
2. Configurar repositório no-subscription
3. Atualizar sistema
4. Instalar pacotes úteis
5. Configurar bridges de rede (vmbr0/vmbr1)
6. Habilitar IOMMU para passthrough
7. Configurar NTP
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
wget https://mirror.dns-root.de/opnsense/releases/24.7/OPNsense-24.7-dvd-amd64.iso.bz2
bunzip2 OPNsense-24.7-dvd-amd64.iso.bz2
mv OPNsense-24.7-dvd-amd64.iso /var/lib/vz/template/iso/

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
