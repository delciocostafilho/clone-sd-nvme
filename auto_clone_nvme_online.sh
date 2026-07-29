#!/usr/bin/env bash
#
# Script de automação para ativar NVMe, instalar rpi-clone e clonar o sistema.
#Versao: 1.0

set -e

CONFIG_FILE="/boot/firmware/config.txt"
DEST_DISK_DEV="/dev/nvme0n1"
DEST_DISK_NAME="nvme0n1"

echo "=== 1. Verificando suporte a NVMe no config.txt ==="
if [ -f "$CONFIG_FILE" ]; then
    if grep -q "^dtparam=nvme" "$CONFIG_FILE"; then
        echo "-> 'dtparam=nvme' já está presente em $CONFIG_FILE."
    else
        echo "-> Adicionando 'dtparam=nvme' ao $CONFIG_FILE..."
        echo -e "\n# Ativar suporte ao NVMe\ndtparam=nvme" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo "-> Suporte adicionado com sucesso!"
    fi
else
    echo "Erro: Arquivo $CONFIG_FILE não encontrado."
    exit 1
fi

echo ""
echo "=== 2. Verificando / Instalando rpi-clone ==="
if command -v rpi-clone &> /dev/null; then
    echo "-> rpi-clone já está instalado."
else
    echo "-> Instalando rpi-clone..."
    curl -sSL https://raw.githubusercontent.com/geerlingguy/rpi-clone/master/install | sudo bash
    echo "-> rpi-clone instalado com sucesso!"
fi

echo ""
echo "=== 3. Atualizando barramento PCIe e verificando o NVMe ==="
# Desmonta partições se estiverem presas
sudo umount /dev/nvme0n1p* 2>/dev/null || true

# Força o kernel a reler a tabela de partições do NVMe
sudo partprobe /dev/nvme0n1 2>/dev/null || true
sleep 1

if [ ! -b "$DEST_DISK_DEV" ] || ! grep -q "$DEST_DISK_NAME" /proc/partitions; then
    echo "AVISO: O NVMe perdeu a conexão com o barramento PCIe."
    echo "Como o hardware desconectou por causa do erro anterior, um reboot é necessário para reativá-lo."
    read -p "Deseja reiniciar o Raspberry Pi agora? (s/N): " REBOOT_NOW
    if [[ "$REBOOT_NOW" =~ ^[Ss]$ ]]; then
        sudo reboot
    else
        exit 1
    fi
fi

echo "-> Disco $DEST_DISK_DEV detectado e pronto na tabela de partições!"
echo ""
echo "=== 4. Iniciando a clonagem / sincronização ==="
echo "Executando rpi-clone para $DEST_DISK_NAME com desvinculação de referências (-e)..."
sudo rpi-clone -f -U -e "$DEST_DISK_NAME" "$DEST_DISK_NAME"

# =====================================================================
# CORREÇÃO AUTOMÁTICA DE NOMENCLATURA DAS PARTIÇÕES NVME (p1 / p2)
# =====================================================================
echo "Verificando e corrigindo caminhos do NVMe no cmdline.txt e fstab..."

# Criar pontos de montagem temporários
TMP_BOOT="/tmp/nvme_fix_boot"
TMP_ROOT="/tmp/nvme_fix_root"
mkdir -p "$TMP_BOOT" "$TMP_ROOT"

# Montar as partições recém-clonadas do NVMe
mount /dev/nvme0n1p1 "$TMP_BOOT"
mount /dev/nvme0n1p2 "$TMP_ROOT"

# 1. Corrigir o cmdline.txt na partição BOOT do NVMe
if [ -f "$TMP_BOOT/cmdline.txt" ]; then
    sed -i 's/nvme0n11/nvme0n1p1/g' "$TMP_BOOT/cmdline.txt"
    sed -i 's/nvme0n12/nvme0n1p2/g' "$TMP_BOOT/cmdline.txt"
fi

# 2. Corrigir o /etc/fstab na partição ROOT do NVMe
if [ -f "$TMP_ROOT/etc/fstab" ]; then
    sed -i 's/nvme0n11/nvme0n1p1/g' "$TMP_ROOT/etc/fstab"
    sed -i 's/nvme0n12/nvme0n1p2/g' "$TMP_ROOT/etc/fstab"
fi

# Forçar a gravação de alterações no disco e desmontar
sync
umount "$TMP_BOOT"
umount "$TMP_ROOT"
rm -rf "$TMP_BOOT" "$TMP_ROOT"

echo "Correção dos caminhos NVMe concluída com sucesso!"

echo ""
echo "======================================================="
echo " Processo concluído com sucesso!"
echo "======================================================="
