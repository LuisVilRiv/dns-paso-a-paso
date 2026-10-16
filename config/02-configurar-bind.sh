#!/usr/bin/env bash
# 02 - Configuración de Bind9: copia los ficheros de /vagrant/files, los valida y reinicia named
set -e

# --- COPIA DE FICHEROS ---

cp /vagrant/files/named /etc/default/named
[ -f /etc/bind/named.conf.options.backup ] || cp /etc/bind/named.conf.options /etc/bind/named.conf.options.backup
cp /vagrant/files/named.conf.options /etc/bind/named.conf.options
[ -f /etc/bind/named.conf.options.backup ] || cp /etc/bind/named.conf.options /etc/bind/named.conf.options.backup
cp /vagrant/files/named.conf.options /etc/bind/named.conf.options
cp /vagrant/files/named.conf.local /etc/bind/named.conf.local
cp /vagrant/files/luis.test.dns /var/lib/bind/luis.test.dns
chown bind:bind /var/lib/bind/luis.test.dns
# --- COMPROBACIONES ---

named-checkconf /etc/bind/named.conf.options
named-checkconf /etc/bind/named.conf.options
named-checkzone luis.test /var/lib/bind/luis.test.dns
# --- REINICIO ---
systemctl restart named
