#!/bin/bash

AMARELO="\033[1;33m"
AZUL="\033[1;34m"
VERMELHO="\033[1;31m"
RESET="\033[0m"

set -uo pipefail
IFS=$'\n\t'

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

  if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    echo "Outro processo de apt/dpkg está rodando. Saindo."
    finalizar
    exit 1
  fi

  sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock || true
  sudo apt-get -f install -y || true
  sudo dpkg --configure -a || true
}

relatorio_espaco_root() {
  echo
  echo -e "${AZUL}== Uso de disco em / (top 10 diretórios) ==${RESET}"
  du -h --max-depth=1 / 2>/dev/null | sort -hr | head || true
  echo
}

checar_espaco_root() {
  local livre
  livre=$(df -Pm / | awk 'NR==2 {print $4}')
  echo -e "${AZUL}Espaço livre atual em /: ${livre} MB${RESET}"

  local limiar=1024  # 1 GB

  if (( livre < limiar )); then
    echo -e "${VERMELHO}Atenção: pouco espaço em / (< ${limiar} MB).${RESET}"
    relatorio_espaco_root
    echo -e "${AMARELO}Sugestões rápidas antes de atualizar:${RESET}"
    echo "  - Limpar arquivos grandes em /root (ISOs, capturas, backups)."
    echo "  - Mover material pesado para /opt (onde há bastante espaço livre)."
    echo
    echo -e "${AZUL}Deseja continuar mesmo assim com o full-upgrade? (s/N)${RESET}"
    read -r CONT || CONT=""
    if [[ "$CONT" != "s" && "$CONT" != "S" ]]; then
      echo "Abortando para evitar erro de 'No space left on device'."
      finalizar
      exit 1
    fi
  fi
}

listar_kernels() {
  echo -e "${AZUL}== Kernels instalados (linux-image-*) ==${RESET}"
  dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/ {print $2}' | sort -V || true
  echo
}

limpar_kernels_antigos() {
  echo
  echo -e "${AZUL}== Limpeza opcional de kernels antigos ==${RESET}"

  local current
  current=$(uname -r)
  echo "Kernel em uso (uname -r): $current"

  mapfile -t imagens < <(dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/ {print $2}' | sort -V)
  if ((${#imagens[@]} <= 2)); then
    echo "Menos ou igual a 2 kernels instalados, nada para remover."
    return 0
  fi

  echo "Kernels instalados:"
  printf '  %s\n' "${imagens[@]}"

  local current_pkg=""
  for p in "${imagens[@]}"; do
    if [[ "$p" == *"$current"* ]]; then
      current_pkg="$p"
      break
    fi
  done

  if [[ -z "$current_pkg" ]]; then
    echo -e "${VERMELHO}Não foi possível mapear o kernel atual para um linux-image-*. Abortando limpeza automática de kernel.${RESET}"
    return 1
  fi

  local keep=()
  keep+=("$current_pkg")

  local idx=-1
  for i in "${!imagens[@]}"; do
    if [[ "${imagens[$i]}" == "$current_pkg" ]]; then
      idx=$i
      break
    fi
  done
  if ((idx > 0)); then
    keep+=("${imagens[$((idx-1))]}")
  fi

  echo
  echo "Pacotes de kernel que serão mantidos:"
  printf '  %s\n' "${keep[@]}"

  local remove=()
  for p in "${imagens[@]}"; do
    local k=0
    for kpkg in "${keep[@]}"; do
      if [[ "$p" == "$kpkg" ]]; then
        k=1
        break
      fi
    done
    ((k == 0)) && remove+=("$p")
  done

  if ((${#remove[@]} == 0)); then
    echo "Nenhum kernel extra para remover."
    return 0
  fi

  echo
  echo -e "${AMARELO}Kernels candidatos à remoção (velhos):${RESET}"
  printf '  %s\n' "${remove[@]}"
  echo
  echo -e "${AZUL}Remover AGORA esses kernels antigos com apt purge? (s/N)${RESET}"
  read -r RESP_K || RESP_K=""
  if [[ "$RESP_K" != "s" && "$RESP_K" != "S" ]]; then
    echo "Remoção de kernels antigos cancelada."
    return 0
  fi

  echo
  echo -e "${AZUL}Executando: sudo apt purge ${remove[*]}${RESET}"
  sudo apt purge -y "${remove[@]}" || {
    echo -e "${VERMELHO}Falha ao remover kernels antigos.${RESET}"
    return 1
  }

  echo -e "${AZUL}Kernels antigos removidos. Atualizando GRUB (se aplicável).${RESET}"
  if command -v update-grub >/dev/null 2>&1; then
    sudo update-grub || true
  fi

  relatorio_espaco_root
}

# === Tela de boas-vindas ===
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
# ===========================

check_dpkg

echo -e "${AZUL}=== Atualização do sistema ===${RESET}"
sleep 1

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
echo -e "${AZUL}0) Limpeza inicial (autoremove/autoclean/clean)...${RESET}"
sudo apt-get autoremove -y || true
sudo apt-get autoclean || true
sudo apt-get clean || true

relatorio_espaco_root
listar_kernels

echo
echo -e "${AZUL}Deseja rodar a limpeza OPCIONAL de kernels antigos agora? (s/N)${RESET}"
read -r LIMPAK || LIMPAK=""
if [[ "$LIMPAK" == "s" || "$LIMPAK" == "S" ]]; then
  limpar_kernels_antigos
fi

echo
echo -e "${AZUL}1) apt update${RESET}"
sudo apt update || { echo "Falha em apt update"; finalizar; exit 1; }

echo
echo -e "${AZUL}2) Resumo de upgrades disponíveis (até 30 pacotes)...${RESET}"
sudo apt list --upgradable 2>/dev/null | sed '1d' | head -n 30 || true
echo "..."

echo
echo -e "${AZUL}Aplicar upgrades AGORA (apt full-upgrade de tudo)? (s/N)${RESET}"
echo -e "${AZUL}Resposta N = modo rápido (apenas verificar e listar, sem aplicar).${RESET}"
read -r RESP || RESP=""

if [[ "$RESP" != "s" && "$RESP" != "S" ]]; then
  echo -e "${AZUL}Full-upgrade completo cancelado (modo rápido concluído).${RESET}"

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
echo -e "${AZUL}3) Checando espaço em / antes do full-upgrade...${RESET}"
checar_espaco_root

echo
echo -e "${AZUL}4) Aplicando apt full-upgrade (todos os pacotes pendentes)...${RESET}"
if ! sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y; then
  echo -e "${VERMELHO}Falha em apt full-upgrade (provavelmente falta de espaço).${RESET}"
  relatorio_espaco_root
  finalizar
  exit 1
fi
echo -e "${AZUL}Upgrades instalados.${RESET}"

echo
echo -e "${AZUL}5) Limpeza pós-upgrade (autoremove/autoclean/clean)${RESET}"
sudo apt-get autoremove -y || true
sudo apt-get autoclean || true
sudo apt-get clean || true

relatorio_espaco_root
listar_kernels

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
