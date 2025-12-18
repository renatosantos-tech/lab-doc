# Baseline Kali para lab

## Objetivo
Padronizar a configuração inicial do Kali usado nos labs de segurança (RNP PoPs).

## Passos
1. Atualizar sistema (`apt update && apt full-upgrade`).
2. Configurar IPs (eth0 NAT, eth1 host-only 192.168.56.x).
3. Habilitar SSH e hardening básico.
4. Clonar repositório lab-doc.
5. Ajustar hostname e registrar no inventário.

