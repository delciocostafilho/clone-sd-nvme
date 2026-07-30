# Clone SD → NVMe para Raspberry Pi

Automatiza a clonagem do cartão SD para um SSD NVMe no Raspberry Pi. Os scripts ativam o suporte ao NVMe, instalam o `rpi-clone` e executam a sincronização — tudo em um único comando.

---

## Scripts disponíveis

| Script | Modo | Descrição |
|---|---|---|
| `auto_clone_nvme_offline.sh` | Offline | Instala o `rpi-clone` a partir da pasta `rpi-clone/` local. Não requer internet. |
| `auto_clone_nvme_online.sh` | Online | Baixa e instala o `rpi-clone` diretamente do GitHub via `curl`. Requer conexão com a internet. |

---

## Pré-requisitos

- Raspberry Pi com slot M.2 / HAT NVMe
- SSD NVMe conectado
- Cartão SD com Raspberry Pi OS em funcionamento
- Acesso `sudo`

---

## Modo Online

Use este modo quando o Raspberry Pi tiver acesso à internet.

1. Torne o script executável:

   ```bash
   chmod +x auto_clone_nvme_online.sh
   ```

2. Execute com privilégios de superusuário:

   ```bash
   sudo ./auto_clone_nvme_online.sh
   ```

---

## Modo Offline

Use este modo quando não houver conexão com a internet. O `rpi-clone` é instalado diretamente da pasta `rpi-clone/` que acompanha este repositório.

### Estrutura de arquivos necessária

Certifique-se de que o script e a pasta `rpi-clone/` estejam juntos no mesmo diretório no cartão SD:

```
/seu/diretorio/
├── auto_clone_nvme_offline.sh
└── rpi-clone/
    └── rpi-clone          ← binário usado na instalação offline
```

### Transferindo os arquivos para o Raspberry Pi

Copie o script e a pasta `rpi-clone/` para o cartão SD (via pendrive, `scp`, ou outro meio):

```bash
cp -r auto_clone_nvme_offline.sh rpi-clone/ /caminho/no/sd/
```

### Executando no Raspberry Pi

1. Acesse o diretório onde estão os arquivos:

   ```bash
   cd /caminho/no/sd/
   ```

2. Torne o script executável:

   ```bash
   chmod +x auto_clone_nvme_offline.sh
   ```

3. Execute com privilégios de superusuário:

   ```bash
   sudo ./auto_clone_nvme_offline.sh
   ```

---

## O que o script faz automaticamente

1. **Habilita o barramento PCIe/NVMe:** Adiciona a linha `dtparam=nvme` ao `/boot/firmware/config.txt` caso ainda não esteja presente, garantindo a ativação física do dispositivo no boot.
2. **Gerencia a ferramenta de clonagem (`rpi-clone`):** Verifica se o utilitário `rpi-clone` está instalado no caminho `/usr/local/sbin/` e realiza a instalação de forma automática se necessário.
3. **Reconecta e prepara o barramento PCIe:** Desmonta partições ativas do NVMe no sistema e força o Kernel Linux a reler a tabela de partições do disco (`/dev/nvme0n1`). Caso o SSD não seja localizado, alerta o usuário e sugere a reinicialização.
4. **Sincroniza o Cartão SD para o NVMe:** Executa a clonagem do sistema de arquivos usando o `rpi-clone` com parâmetros de isolamento de referências (`-e`).
5. **Correção pós-clonagem de partições NVMe (Fix `sed`):** Resolve a falha nativa do `rpi-clone` que omitia o sufixo `p` nas partições NVMe (`nvme0n11` / `nvme0n12`). O script monta temporariamente o NVMe e corrige a nomenclatura para `/dev/nvme0n1p1` e `/dev/nvme0n1p2` nos arquivos:
   - `/boot/firmware/cmdline.txt` (direciona a montagem da raiz)
   - `/etc/fstab` (montagem de `/` e `/boot/firmware`)
6. **Garante a integridade do boot:** Aplica a instrução `sync` para gravar permanentemente as alterações no SSD e desmonta os pontos temporários, deixando o NVMe 100% autônomo.

---
## Verificação de boot

**Confirmar em qual disco o Pi subiu agora:**

```bash
findmnt /
```
Se retornar /dev/mmcblk0p2, significa que ele ligou pelo Cartão SD.

Se retornar /dev/nvme0n1p2, significa que subiu pelo NVMe.

**Para confirmar que os dois discos agora têm identificadores de partição diferentes (e que o script ajustou as rotas de boot do NVMe), execute este comando no terminal:**

```bash
sudo blkid
```
**Ele exibirá uma saída parecida com esta:**

```bash
/dev/mmcblk0p1: LABEL_FATBOOT="bootfs" ... PARTUUID="a1b2c3d4-01"
/dev/mmcblk0p2: LABEL="rootfs"        ... PARTUUID="a1b2c3d4-02"
/dev/nvme0n1p1: LABEL_FATBOOT="bootfs" ... PARTUUID="e5f6g7h8-01"
/dev/nvme0n1p2: LABEL="rootfs"        ... PARTUUID="e5f6g7h8-02"
```
O que você deve observar:

> *Os valores de PARTUUID (ou UUID):
As partições do mmcblk0 (SD) e do nvme0n1 (NVMe) não podem ter exatamente o mesmo código inicial (a parte antes do hífen).
Se estiverem diferentes, a colisão de UUIDs está resolvida!*

---

## Solução de problemas

**Erro ao rodar comando após transferir o arquivo do Windows para o Linux**

Caso aconteça o erro abaixo:
```text
pi@cubagem:~/clone_sd $ sudo ./auto_clone_nvme_offline.sh
env: ‘bash\r’: Arquivo ou diretório inexistente
env: usa -[v]S para passar opções em linhas shebang
 ```
Rode o comando abaixo no terminal para limpar os caracteres invisíveis do Windows (\r) do arquivo:

**MODO OFFLINE**

```bash
sed -i 's/\r$//' auto_clone_nvme_offline.sh
 ```

**MODO ONLINE**

```bash
sed -i 's/\r$//' auto_clone_nvme_online.sh
 ```
Executar novamente o comando do script.

**O NVMe não dá boot quando o Cartão SD é removido (LED verde fixo ou tela preta)**

As configurações de inicialização do barramento PCIe ficam salvas na memória **EEPROM da placa-mãe do Raspberry Pi 5** (e não no Cartão SD/NVMe). Se você trocou de Raspberry Pi ou a EEPROM foi resetada, o bootloader não saberá que deve procurar o SSD.

1. Insira o Cartão SD novamente e ligue o Pi.
2. Abra as configurações do firmware da placa:
   ```bash
   sudo rpi-eeprom-config --edit
    ```
1. Garanta que a seção [all] contenha as diretivas de PCIe e boot:
   ```text
   [all]
   BOOT_UART=1
   BOOT_ORDER=0xf461
   PCIE_PROBE=1
   NET_INSTALL_AT_POWER_ON=1
   DISABLE_HDMI_DIAG=1
   ```
2. Salve (Ctrl+O, Enter) e saia (Ctrl+X).
3. Despois de salvar aguarde o boot ser atualizado, uma mensagem como essa deve aparecer.
   ```text
   Updating bootloader EEPROM
    image: /usr/lib/firmware/raspberrypi/bootloader-2712/default/pieeprom-2025-05-08.bin
   config_src: blconfig device
   config: /tmp/tmpcb94w393/boot.conf
   ################################################################################
   [all]
   BOOT_UART=1
   BOOT_ORDER=0xf461
   PCIE_PROBE=1
   NET_INSTALL_AT_POWER_ON=1
   
   ################################################################################
   *** CREATED UPDATE /tmp/tmpcb94w393/pieeprom.upd  ***
   
      CURRENT: qui 08 mai 2025 14:13:17 UTC (1746713597)
       UPDATE: qui 08 mai 2025 14:13:17 UTC (1746713597)
       BOOTFS: /boot/firmware
   '/tmp/tmp.PBeN4ZLywS' -> '/boot/firmware/pieeprom.upd'
   
   UPDATING bootloader. This could take up to a minute. Please wait
   
   *** Do not disconnect the power until the update is complete ***
   
   If a problem occurs then the Raspberry Pi Imager may be used to create
   a bootloader rescue SD card image which restores the default bootloader image.
   
   flashrom -p linux_spi:dev=/dev/spidev10.0,spispeed=16000 -w /boot/firmware/pieeprom.upd
   Verifying update
   VERIFY: SUCCESS
   UPDATE SUCCESSFUL
   ```
4. Aplique as alterações reiniciando o sistema:
   ```bash
   sudo reboot
   ```

**Está mostrando a tela do Instalador de rede ao Inicializar (Tela Raspberry)**

1. Remover o instalador de rede usando o menu
```bash
sudo raspi-config
```
2. Vá em Advanced Options.
3. Selecione a opção Network Install UI.
4. Escolha "On demand Display the UI if the SHIFT key is pressed or if an error occurs" para remover a interface de rede do boot.
5. Selecione Finish para sair e confirme o reinício do sistema.

**O NVMe não é detectado após executar o script**

O barramento PCIe pode ter desconectado. O script detecta isso e pergunta se deseja reiniciar. Confirme com `s` e execute o script novamente após o reboot.

**Erro: `rpi-clone` não encontrado em `rpi-clone/rpi-clone`**

A pasta `rpi-clone/` não está no mesmo diretório que o script. Verifique a estrutura de arquivos descrita acima.

**Erro: `/boot/firmware/config.txt` não encontrado**

Verifique se o sistema está rodando uma versão recente do Raspberry Pi OS (Bookworm ou posterior). Versões mais antigas usam `/boot/config.txt`.

**`partprobe` não disponível**

Instale o pacote `parted`:

```bash
sudo apt install parted
```
---

## Referências

- [rpi-clone by geerlingguy](https://github.com/geerlingguy/rpi-clone)
- [Documentação oficial do Raspberry Pi — NVMe](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
