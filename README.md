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

1. **Ativa o suporte ao NVMe** — adiciona `dtparam=nvme` ao `/boot/firmware/config.txt` se ainda não estiver presente.
2. **Instala o `rpi-clone`** — copia o binário de `rpi-clone/rpi-clone` para `/usr/local/sbin/`, pulando caso já esteja instalado.
3. **Reconecta o barramento PCIe** — desmonta partições presas e força o kernel a reler a tabela de partições do NVMe. Se o disco não for detectado, oferece a opção de reiniciar o Raspberry Pi.
4. **Sincroniza o Cartão SD para o NVMe** — executa `rpi-clone -u nvme0n1` para clonar o sistema completo.

---

## Solução de problemas

**O sistema inicia pelo NVMe em vez do Cartão SD após a clonagem**

Se o Raspberry Pi passar a inicializar direto pelo SSD NVMe mesmo com o Cartão SD inserido, ajuste a ordem de boot no bootloader/EEPROM:

1. Abra a configuração da EEPROM:
   ```bash
   sudo rpi-eeprom-config --edit
   ```
2. Defina o parâmetro `BOOT_ORDER` para priorizar o Cartão SD (código `1`) antes do NVMe (código `6`):
   ```text
   BOOT_ORDER=0xf164
   ```
3. Salve com `Ctrl+O`, confirme com `Enter` e saia com `Ctrl+X`.
4. Reinicie o sistema:
   ```bash
   sudo reboot
   ```
> *Caso não consiga acessar o terminal porque o sistema iniciou pelo NVMe, desligue o Pi, desconecte fisicamente o NVMe/cabo HAT, ligue apenas com o Cartão SD, faça a alteração acima e reconecte o NVMe.*

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
## Para confirmar que os dois discos agora têm identificadores de partição diferentes (e que o script ajustou as rotas de boot do NVMe), execute este comando no terminal:

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

**`Outras duas verificações úteis:**
Confirmar em qual disco o Pi subiu agora:

```bash
findmnt /
```
Se retornar /dev/mmcblk0p2, significa que ele ligou pelo Cartão SD.

Se retornar /dev/nvme0n1p2, significa que subiu pelo NVMe.

---

## Referências

- [rpi-clone by geerlingguy](https://github.com/geerlingguy/rpi-clone)
- [Documentação oficial do Raspberry Pi — NVMe](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
