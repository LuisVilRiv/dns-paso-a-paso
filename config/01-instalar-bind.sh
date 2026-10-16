#!/usr/bin/env bash
# 01 - Instala Bind9 y utilidades (paquetes del enunciado + dig/nslookup para pruebas locales)
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y bind9 bind9utils bind9-doc bind9-dnsutils
