#!/bin/bash

AZUL="\033[1;34m"
RESET="\033[0m"
set -e

check_dpkg() {
  echo -e "${AZUL}Verificando estado do dpkg/locks...${RESET}"

  # Se outro apt/dpkg estiver rodando, aborta
  if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    echo "Outro processo de apt/dpkg está rodando. Saindo."
    exit 1
  fi

  # Remove locks órfãos
  rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock || true

  # Tenta corrigir pacotes meio instalados
  apt -f install -y || true
  dpkg --configure -a || true
}

check_dpkg

echo -e "${AZUL}=== Atualização do sistema ===${RESET}"
sleep 1

echo
echo -e "${AZUL}Versão atual do sistema:${RESET}"
echo "--------------------------------"
cat /etc/os-release | egrep 'PRETTY_NAME|VERSION='
echo
echo "Kernel:"
uname -r
echo "--------------------------------"
sleep 1

echo
echo -e "${AZUL}0) Limpando espaço (autoremove/autoclean/clean)...${RESET}"
sudo apt autoremove -y
sudo apt autoclean
sudo apt clean

echo
echo -e "${AZUL}1) apt update${RESET}"
sudo apt update

echo
echo -e "${AZUL}2) Resumo de upgrades disponíveis (até 30 pacotes)...${RESET}"
sudo apt list --upgradable 2>/dev/null | sed '1d' | head -n 30
echo "..."

echo
echo -e "${AZUL}Aplicar upgrades AGORA (full-upgrade de tudo)? (s/N)${RESET}"
read -r RESP
if [[ "$RESP" != "s" && "$RESP" != "S" ]]; then
  echo -e "${AZUL}Full-upgrade completo cancelado.${RESET}"
  echo -e "${AZUL}Se quiser trabalhar em lotes, ajuste o script para usar o bloco de lotes.${RESET}"
  exit 0
fi

echo
echo -e "${AZUL}3) Aplicando full-upgrade (todos os pacotes pendentes)...${RESET}"
sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
echo -e "${AZUL}Upgrades instalados.${RESET}"

echo
echo -e "${AZUL}4) Limpeza pós-upgrade (autoremove/autoclean/clean)${RESET}"
sudo apt autoremove -y
sudo apt autoclean
sudo apt clean

echo
echo -e "${AZUL}Versão após atualização:${RESET}"
echo "--------------------------------"
cat /etc/os-release | egrep 'PRETTY_NAME|VERSION='
echo
echo "Kernel:"
uname -r
echo "--------------------------------"

echo
echo -e "${AZUL}=== Rotina finalizada ===${RESET}"

###############################################################################
# BLOCO OPCIONAL: ATUALIZAÇÃO EM LOTES (EXEMPLO DE ATÉ 100 PACOTES)
#
# Para usar este modo em vez do full-upgrade de tudo:
#  - comente o bloco do full-upgrade acima (passo 3)
#  - descomente o código abaixo e rode o script várias vezes
###############################################################################
#
#echo
#echo -e "${AZUL}Modo LOTE: preparando lista de até 100 pacotes para este ciclo...${RESET}"
#
## Gera lista de pacotes upgradables (nome do pacote, sem versão)
#sudo apt list --upgradable 2>/dev/null \
#  | sed '1d' \
#  | cut -d/ -f1 \
#  | head -n 100 \
#  > /tmp/pacotes_lote.txt
#
#if ! [ -s /tmp/pacotes_lote.txt ]; then
#  echo -e "${AZUL}Nenhum pacote pendente para este lote.${RESET}"
#  exit 0
#fi
#
#echo
#echo -e "${AZUL}Pacotes deste lote (até 100):${RESET}"
#cat /tmp/pacotes_lote.txt
#
#echo
#echo -e "${AZUL}Aplicar upgrades deste lote? (s/N)${RESET}"
#read -r RESP
#if [[ "$RESP" != "s" && "$RESP" != "S" ]]; then
#  echo -e "${AZUL}Upgrade em lote cancelado.${RESET}"
#  exit 0
#fi
#
#echo
#echo -e "${AZUL}Aplicando lote de até 100 pacotes...${RESET}"
#sudo DEBIAN_FRONTEND=noninteractive xargs -a /tmp/pacotes_lote.txt apt install -y
#
#echo
#echo -e "${AZUL}Limpeza pós-lote (autoremove/autoclean)${RESET}"
#sudo apt autoremove -y
#sudo apt autoclean
#
#echo
#echo -e "${AZUL}Lote concluído. Rode o script novamente para o próximo lote.${RESET}"
