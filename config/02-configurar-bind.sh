#!/usr/bin/env bash
# 02 - Configuración de Bind9: copia los ficheros de /vagrant/files, los valida y reinicia named
set -e

# --- COPIA DE FICHEROS ---

cp /vagrant/files/named /etc/default/named
# --- COMPROBACIONES ---

# --- REINICIO ---
systemctl restart named
