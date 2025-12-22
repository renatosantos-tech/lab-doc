#!/bin/bash

AMARELO="\033[1;33m"
RESET="\033[0m"

echo -e "${AMARELO}"
echo    " +-----------------------------------------------------------+"
echo    " |        Bem-vindo ao script de atualização do sistema      |"
echo    " +-----------------------------------------------------------+"
echo    " |  Este script irá verificar pacotes pendentes, aplicar     |"
echo    " |  atualizações com segurança e limpar arquivos obsoletos.  |"
echo    " |             By: Renato Silva — PoP-RS/RNP                 |"
echo    " +-----------------------------------------------------------+"
echo -e "${RESET}"
echo

set -euo pipefail
IFS=$'\n\t'

AZUL="\033[1;34m"
RESET="\033[0m"

finalizar() {
  echo
  echo -e "${AZUL}=== Rotina finalizada ===${RESET}"
  echo
  echo "## 🛠️ By"
  echo "Renato Silva — PoP-RS/RNP"
  echo
}

check_dpkg() {
  echo -e "${AZUL}Verificando estado do dpkg/locks...${RESET}"

  # Se outro apt/dpkg estiver rodando, aborta
  if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    echo "Outro processo de apt/dpkg está rodando. Saindo."
    finalizar
    exit 1
  fi

  # Remove locks órfãos
  sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock || true

  # Tenta corrigir pacotes meio instalados
  sudo apt-get -f install -y || true
  sudo dpkg --configure -a || true
}

check_dpkg

echo -e "${AZUL}=== Atualização do sistema ===${RESET}"
sleep 1

# Estado inicial
OS_BEFORE="$(grep -E 'PRETTY_NAME|VERSION=' /etc/os-release | tr '\n' ' ')"
KERNEL_BEFORE="$(uname -r)"

echo
echo -e "${AZUL}Versão atual do sistema:${RESET}"
echo "--------------------------------"
echo "$OS_BEFORE"
echo
echo "Kernel:"
echo "$KERNEL_BEFORE"
echo "--------------------------------"
sleep 1

echo
echo -e "${AZUL}0) Limpando espaço inicial (autoremove/autoclean/clean)...${RESET}"
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo apt-get clean

echo
echo -e "${AZUL}1) apt-get update${RESET}"
sudo apt-get update

echo
echo -e "${AZUL}2) Resumo de upgrades disponíveis (até 30 pacotes)...${RESET}"
sudo apt list --upgradable 2>/dev/null | sed '1d' | head -n 30
echo "..."

echo
echo -e "${AZUL}Aplicar upgrades AGORA (full-upgrade de tudo)? (s/N)${RESET}"
echo -e "${AZUL}Resposta N = modo rápido (apenas verificar e listar, sem aplicar).${RESET}"
read -r RESP
if [[ "$RESP" != "s" && "$RESP" != "S" ]]; then
  echo -e "${AZUL}Full-upgrade completo cancelado (modo rápido concluído).${RESET}"

  # Estado final no modo rápido (depois de update/limpezas)
  OS_AFTER="$(grep -E 'PRETTY_NAME|VERSION=' /etc/os-release | tr '\n' ' ')"
  KERNEL_AFTER="$(uname -r)"

  echo
  echo -e "${AZUL}Resumo das mudanças de versão/kernel (modo rápido):${RESET}"

  if [ "$OS_BEFORE" != "$OS_AFTER" ]; then
    echo "- Sistema: ALTERADO"
    echo "  De: $OS_BEFORE"
    echo "  Para: $OS_AFTER"
  else
    echo "- Sistema: mantido (sem mudança de versão)."
  fi

  if [ "$KERNEL_BEFORE" != "$KERNEL_AFTER" ]; then
    echo "- Kernel: ALTERADO"
    echo "  De: $KERNEL_BEFORE"
    echo "  Para: $KERNEL_AFTER"
  else
    echo "- Kernel: mantido (sem mudança de versão)."
  fi

  finalizar
  exit 0
fi

echo
echo -e "${AZUL}3) Aplicando full-upgrade (todos os pacotes pendentes)...${RESET}"
sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
echo -e "${AZUL}Upgrades instalados.${RESET}"

echo
echo -e "${AZUL}[KERNEL] Limpando kernels antigos (mantendo atual e mais recente)...${RESET}"
CURRENT="$(uname -r)"
# lista kernels genéricos instalados, ordenados por versão
mapfile -t KERNELS < <(dpkg --list | awk '/linux-image-[0-9].*-generic/ {print $2}' | sort -V)

if [ "${#KERNELS[@]}" -gt 2 ]; then
  KEEP1="linux-image-${CURRENT}"
  KEEP2="${KERNELS[-1]}"
  echo "[KERNEL] Mantendo: $KEEP1 e $KEEP2"
  for K in "${KERNELS[@]}"; do
    if [ "$K" != "$KEEP1" ] && [ "$K" != "$KEEP2" ]; then
      echo "[KERNEL] Removendo kernel antigo: $K"
      sudo apt-get remove --purge -y "$K"
    fi
  done
  sudo apt-get autoremove --purge -y
else
  echo "[KERNEL] Já há ${#KERNELS[@]} kernels ou menos; nada a remover."
fi

echo
echo -e "${AZUL}4) Limpeza pós-upgrade (autoremove/autoclean/clean)${RESET}"
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo apt-get clean

# Estado final após full-upgrade
OS_AFTER="$(grep -E 'PRETTY_NAME|VERSION=' /etc/os-release | tr '\n' ' ')"
KERNEL_AFTER="$(uname -r)"

echo
echo -e "${AZUL}Resumo das mudanças de versão/kernel:${RESET}"

if [ "$OS_BEFORE" != "$OS_AFTER" ]; then
  echo "- Sistema: ALTERADO"
  echo "  De: $OS_BEFORE"
  echo "  Para: $OS_AFTER"
else
  echo "- Sistema: mantido (sem mudança de versão)."
fi

if [ "$KERNEL_BEFORE" != "$KERNEL_AFTER" ]; then
  echo "- Kernel: ALTERADO"
  echo "  De: $KERNEL_BEFORE"
  echo "  Para: $KERNEL_AFTER"
else
  echo "- Kernel: mantido (sem mudança de versão)."
fi

finalizar

