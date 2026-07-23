#!/usr/bin/env bash
# Script de Clonagem NVMe para Raspberry Pi (Modo Offline)
# Requer que a pasta rpi-clone/ esteja no mesmo diretório que este script.
set -e

CONFIG_FILE="/boot/firmware/config.txt"
DEST_DISK_DEV="/dev/nvme0n1"
DEST_DISK_NAME="nvme0n1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPI_CLONE_BIN="$SCRIPT_DIR/rpi-clone/rpi-clone"

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
    echo "-> rpi-clone já está instalado no sistema."
else
    if [ -f "$RPI_CLONE_BIN" ]; then
        echo "-> Instalando rpi-clone a partir da pasta local rpi-clone/ (Modo Offline)..."
        sudo cp "$RPI_CLONE_BIN" /usr/local/sbin/
        sudo chmod +x /usr/local/sbin/rpi-clone
        echo "-> rpi-clone instalado com sucesso!"
    else
        echo "Erro: Binário rpi-clone não encontrado em '$RPI_CLONE_BIN'."
        echo "Certifique-se de que a pasta rpi-clone/ está no mesmo diretório que este script."
        exit 1
    fi
fi

echo ""
echo "=== 3. Atualizando barramento PCIe e verificando o NVMe ==="
sudo umount /dev/nvme0n1p* 2>/dev/null || true
sudo partprobe /dev/nvme0n1 2>/dev/null || true
sleep 1

if [ ! -b "$DEST_DISK_DEV" ] || ! grep -q "$DEST_DISK_NAME" /proc/partitions; then
    echo "AVISO: O NVMe não foi detectado no barramento PCIe."
    echo "Como o hardware pode ter desconectado, um reboot é necessário para reativá-lo."
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
echo "Executando rpi-clone para $DEST_DISK_NAME..."
sudo rpi-clone -u "$DEST_DISK_NAME"

echo ""
echo "======================================================"
echo " Processo concluído com sucesso!"
echo "======================================================"
