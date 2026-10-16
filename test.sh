#!/usr/bin/env bash
# test.sh - Autocomprobación del servidor DNS (se ejecuta dentro de la VM, como último paso del vagrant up)
# Se usa 127.0.0.1 en vez de "localhost" porque named solo escucha en IPv4 (-4) y así dig no prueba ::1.

echo "=== 1. Comprobación de sintaxis de ficheros ==="
named-checkconf /etc/bind/named.conf.options && echo "[OK] named.conf.options"
named-checkzone luis.test /var/lib/bind/luis.test.dns && echo "[OK] Zona directa"
named-checkzone 56.168.192.in-addr.arpa /var/lib/bind/luis.test.rev && echo "[OK] Zona inversa"

echo "=== 2. Comprobación de resolución ==="
echo "-- A (debian.luis.test):";  dig @127.0.0.1 debian.luis.test A +short
echo "-- CNAME (web.luis.test):"; dig @127.0.0.1 web.luis.test CNAME +short
echo "-- TXT (luis.test):";       dig @127.0.0.1 luis.test TXT +short
echo "-- PTR (192.168.56.33):";   dig @127.0.0.1 -x 192.168.56.33 +short

echo "=== 3. Autoridad (debe aparecer aa) ==="
dig @127.0.0.1 debian.luis.test | grep "^;; flags"
