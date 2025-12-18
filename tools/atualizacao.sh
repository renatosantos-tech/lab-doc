#!/bin/bash

# Script de Atualização e Upgrade

# Cores
AZUL="\033[1;34m"   # azul claro/negrito
RESET="\033[0m"     # volta para a cor padrão do terminal

# Encerra o script se algum comando crítico falhar
set -e

echo -e "${AZUL}=================================================${RESET}"
echo -e "${AZUL} Iniciando rotina de atualização do sistema${RESET}"
echo -e "${AZUL}=================================================${RESET}"
sleep 1

echo
echo -e "${AZUL}1) Atualizando lista de pacotes (apt update)...${RESET}"
echo "-------------------------------------------------"
sudo apt update
echo "Lista de pacotes atualizada."
sleep 1

echo
echo -e "${AZUL}2) Verificando upgrades disponíveis (modo simulação)...${RESET}"
echo "-------------------------------------------------"
# Mostra um resumo do que seria atualizado
sudo apt upgrade -s | grep "upgraded," || true
echo
echo "Pacotes que podem ser atualizados:"
sudo apt list --upgradable
sleep 1

echo
echo -e "${AZUL}Deseja aplicar os upgrades agora? (s/N)${RESET}"
read -r RESP

if [[ "$RESP" != "s" && "$RESP" != "S" ]]; then
  echo -e "${AZUL}Upgrade cancelado pelo usuário.${RESET}"
  echo "Encerrando sem aplicar atualizações."
  exit 0
fi

echo
echo -e "${AZUL}3) Instalando upgrades disponíveis...${RESET}"
echo "-------------------------------------------------"
sudo apt upgrade -y
echo "Upgrades instalados."
sleep 1

echo
echo -e "${AZUL}4) Removendo pacotes desnecessários (autoremove)...${RESET}"
echo "-------------------------------------------------"
sudo apt autoremove -y
echo "Limpeza concluída."

echo
echo -e "${AZUL}=================================================${RESET}"
echo -e "${AZUL} Rotina de atualização finalizada com sucesso${RESET}"
echo -e "${AZUL}=================================================${RESET}"

