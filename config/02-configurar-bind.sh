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
cp /vagrant/files/luis.test.rev /var/lib/bind/luis.test.rev
chown bind:bind /var/lib/bind/luis.test.rev
# --- COMPROBACIONES ---

named-checkconf /etc/bind/named.conf.options
named-checkconf /etc/bind/named.conf.options
named-checkzone luis.test /var/lib/bind/luis.test.dns
named-checkzone 56.168.192.in-addr.arpa /var/lib/bind/luis.test.rev
# --- REINICIO ---
systemctl restart named
