# Configuración de un servidor DNS paso a paso

| Dato | Valor |
|---|---|
| Autor | Luis Villegas Rivera |
| Anfitrión | Fedora Linux (VirtualBox + Vagrant) |
| Máquina virtual | Debian 12 (`debian/bookworm64`) |
| Zona directa | `luis.test` |
| Zona inversa | `56.168.192.in-addr.arpa` |
| Red privada | `192.168.56.0/24` |
| IP del servidor | `192.168.56.33` (`debian.luis.test`) |

## Índice
1. [Teoría: sistema de nombres jerárquico](#1-teoría-sistema-de-nombres-jerárquico)
2. [Entorno y máquina virtual](#2-entorno-y-máquina-virtual-vagrantfile)
3. [Instalación de Bind9](#3-instalación-de-bind9)
4. [Configuración del servidor](#4-configuración-del-servidor)
5. [Configuración del cliente](#5-configuración-del-cliente)
6. [Comprobación con dig](#6-comprobación-con-dig)
7. [Comprobación con nslookup](#7-comprobación-con-nslookup)
8. [Tareas de ampliación](#8-tareas-de-ampliación)
9. [Script de autocomprobación](#9-script-de-autocomprobación-testsh)
10. [Despliegue desde cero y entrega](#10-despliegue-desde-cero-y-entrega)

## 1. Teoría: sistema de nombres jerárquico

DNS traduce nombres a IPs. Es una base de datos **distribuida y jerárquica** en forma de árbol; se lee de derecha a izquierda:

```text
.                  <- raíz (13 grupos de servidores raíz)
└── test           <- dominio de primer nivel (TLD; .test está reservado para pruebas)
    └── luis       <- dominio / zona (la que administramos)
        ├── debian <- host:  debian.luis.test.
        └── web    <- alias: web.luis.test.
```

- **FQDN:** nombre completo hasta la raíz, acabado en punto: `debian.luis.test.`
- **Zona:** parte del árbol que gestiona un servidor *autoritativo*. Aquí hay dos:
  - **Directa** (`luis.test`): nombre → IP.
  - **Inversa** (`56.168.192.in-addr.arpa`): IP → nombre (la IP se escribe al revés).
- **Registros usados:** `SOA` (datos de la zona), `NS` (servidor de nombres), `A` (nombre→IPv4), `PTR` (IP→nombre), `CNAME` (alias), `TXT` (texto libre).
- **Servidor autoritativo** responde por sus zonas; **recursivo/caché** resuelve en nombre del cliente consultando a otros. Nuestro Bind9 hace ambas cosas, pero la recursión se limita por seguridad a una ACL.

## 2. Entorno y máquina virtual (Vagrantfile)

- Box `debian/bookworm64` (Debian 12, BIND 9.18, la misma versión que el `dig` del enunciado).
- Tarjeta de red **privada** en `192.168.56.0/24`: el `.1` es del anfitrión (*Host-only*) y el servidor usa el **`.33`**.
- Carpeta del repositorio compartida en `/vagrant` mediante **rsync**. Tras editar en el anfitrión: `vagrant rsync && vagrant provision`.
- `files/` contiene los **ficheros de configuración** que se copian a la VM; `config/` contiene los **scripts de provisión**.

![vagrant up](img/01-vagrant-up.png)

Estado de la VM tras arrancar:

```console
$ vagrant ssh -c "grep PRETTY /etc/os-release; hostname; ip -4 -br a" -- -q
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
debian
lo               UNKNOWN        127.0.0.1/8 
eth0             UP             10.0.2.15/24 
eth1             UP             192.168.56.33/24 
```


## 3. Instalación de Bind9

Paquetes oficiales de Debian, instalados en `config/01-instalar-bind.sh`:
`bind9` (servidor), `bind9utils` (`named-checkconf`, `named-checkzone`), `bind9-doc` y `bind9-dnsutils` (`dig`, `nslookup`).

```console
$ vagrant ssh -c "dpkg -l bind9 bind9utils bind9-doc bind9-dnsutils | grep ^ii; systemctl is-active named" -- -q
ii  bind9          1:9.18.49-1~deb12u2 amd64        Internet Domain Name Server
ii  bind9-dnsutils 1:9.18.49-1~deb12u2 amd64        Clients provided with BIND 9
ii  bind9-doc      1:9.18.49-1~deb12u2 all          Documentation for BIND 9
ii  bind9utils     1:9.18.49-1~deb12u2 all          Transitional package for bind9-utils
active
```


## 4. Configuración del servidor

### 4.0 Solo IPv4 (`/etc/default/named`)

Fichero `files/named`. Solo usamos IPv4, así que arrancamos `named` con `-4`.
Nota: el enunciado escribe `OPTIONS = "..."` con espacios, pero es un fichero de shell y no los admite; se escribe `OPTIONS="-u bind -4"`.

```console
$ vagrant ssh -c "cat /etc/default/named; ps -eo args | grep [n]amed" -- -q
# /etc/default/named - Práctica DNS (Luis Villegas Rivera)
RESOLVCONF=no
# -u bind: ejecutar como usuario "bind" | -4: usar solo IPv4
OPTIONS="-u bind -4"
/usr/sbin/named -f -u bind -4
bash -l -c cat /etc/default/named; ps -eo args | grep [n]amed
```


### 4.1 `named.conf.options`

Fichero `files/named.conf.options`. Antes de sobrescribirlo, el script guarda una **copia de seguridad** (`named.conf.options.backup`).

| Nº | Directiva | Función |
|---|---|---|
| 1 | `directory "/var/cache/bind"` | Directorio de caché |
| 2 | `allow-transfer { none; }` | Sin transferencias de zona |
| 3 | `listen-on port 53 {127.0.0.1; 192.168.56.33;}` | Escucha solo en localhost y en la IP privada |
| 4 | `recursion yes` | Permite recursión... |
| 5 | `allow-recursion { confiables; }` | ...solo a la ACL `confiables` (`127.0.0.1` y `192.168.56.0/24`) |
| 6 | `dnssec-validation auto` | Validación DNSSEC con la clave raíz integrada (por defecto en Debian) |
| 7 | `// listen-on-v6` | IPv6 desactivado |

Comprobación de sintaxis, estado del servicio y puertos en escucha:

![estado de named](img/02-named-status.png)

```console
$ vagrant ssh -c "sudo named-checkconf /etc/bind/named.conf.options && echo OK-sintaxis; sudo ss -lnup | grep :53" -- -q
OK-sintaxis
UNCONN 0      0      192.168.56.33:53        0.0.0.0:*    users:(("named",pid=5189,fd=19))  
UNCONN 0      0          127.0.0.1:53        0.0.0.0:*    users:(("named",pid=5189,fd=16))  
```


### 4.1 `named.conf.options`

Fichero `files/named.conf.options`. Antes de sobrescribirlo, el script guarda una **copia de seguridad** (`named.conf.options.backup`).

| Nº | Directiva | Función |
|---|---|---|
| 1 | `directory "/var/cache/bind"` | Directorio de caché |
| 2 | `allow-transfer { none; }` | Sin transferencias de zona |
| 3 | `listen-on port 53 {127.0.0.1; 192.168.56.33;}` | Escucha solo en localhost y en la IP privada |
| 4 | `recursion yes` | Permite recursión... |
| 5 | `allow-recursion { confiables; }` | ...solo a la ACL `confiables` (`127.0.0.1` y `192.168.56.0/24`) |
| 6 | `dnssec-validation auto` | Validación DNSSEC con la clave raíz integrada (por defecto en Debian) |
| 7 | `// listen-on-v6` | IPv6 desactivado |

Comprobación de sintaxis, estado del servicio y puertos en escucha:

![estado de named](img/02-named-status.png)

```console
$ vagrant ssh -c "sudo named-checkconf /etc/bind/named.conf.options && echo OK-sintaxis; sudo ss -lnup | grep :53" -- -q
OK-sintaxis
UNCONN 0      0      192.168.56.33:53        0.0.0.0:*    users:(("named",pid=5189,fd=19))  
UNCONN 0      0          127.0.0.1:53        0.0.0.0:*    users:(("named",pid=5189,fd=16))  
```


### 4.2 `named.conf.local` y zona directa

Declaramos que el servidor es **maestro** de `luis.test` (`files/named.conf.local`) y creamos su fichero de zona (`files/luis.test.dns`):

- `SOA`: datos de la zona (servidor primario `debian.luis.test.`, contacto `admin.luis.test.`, serial `AAAAMMDDNN`).
- `NS`: el servidor de nombres de la zona.
- `A`: IP de `debian.luis.test.` → `192.168.56.33`.

```text
files/named.conf.local  ->  /etc/bind/named.conf.local
files/luis.test.dns     ->  /var/lib/bind/luis.test.dns
```


### 4.3 Zona inversa

Segunda zona en `named.conf.local` (`56.168.192.in-addr.arpa`, el tercer byte de la red va en el nombre) y su fichero `files/luis.test.rev`.
El registro `33 IN PTR debian.luis.test.` usa el **último octeto** de la IP del servidor.


### 4.4 Comprobación de las configuraciones

Debe devolver `OK` en ambas zonas, y el log de `named` debe mostrar que cargó las dos:

```console
$ vagrant ssh -c "sudo named-checkzone luis.test /var/lib/bind/luis.test.dns; sudo named-checkzone 56.168.192.in-addr.arpa /var/lib/bind/luis.test.rev" -- -q
zone luis.test/IN: loaded serial 2026101601
OK
zone 56.168.192.in-addr.arpa/IN: loaded serial 2026101601
OK
```

```console
$ vagrant ssh -c "sudo journalctl -u named --no-pager | grep \"loaded serial\" | tail -n 2" -- -q
Oct 16 15:28:25 debian named[6773]: zone localhost/IN: loaded serial 2
Oct 16 15:28:25 debian named[6773]: zone luis.test/IN: loaded serial 2026101601
```

![comprobación de zonas](img/03-checkzone.png)

### 4.4 Comprobación de las configuraciones

Debe devolver `OK` en ambas zonas, y el log de `named` debe mostrar que cargó las dos:

```console
$ vagrant ssh -c "sudo named-checkzone luis.test /var/lib/bind/luis.test.dns; sudo named-checkzone 56.168.192.in-addr.arpa /var/lib/bind/luis.test.rev" -- -q
zone luis.test/IN: loaded serial 2026101601
OK
zone 56.168.192.in-addr.arpa/IN: loaded serial 2026101601
OK
```

```console
$ vagrant ssh -c "sudo journalctl -u named --no-pager | grep \"loaded serial\" | tail -n 2" -- -q
Oct 16 15:28:25 debian named[6773]: zone localhost/IN: loaded serial 2
Oct 16 15:28:25 debian named[6773]: zone luis.test/IN: loaded serial 2026101601
```

![comprobación de zonas](img/03-checkzone.png)

### 4.4 Comprobación de las configuraciones

Debe devolver `OK` en ambas zonas, y el log de `named` debe mostrar que cargó las dos:

```console
$ vagrant ssh -c "sudo named-checkzone luis.test /var/lib/bind/luis.test.dns; sudo named-checkzone 56.168.192.in-addr.arpa /var/lib/bind/luis.test.rev" -- -q
zone luis.test/IN: loaded serial 2026101601
OK
zone 56.168.192.in-addr.arpa/IN: loaded serial 2026101601
OK
```

```console
$ vagrant ssh -c "sudo journalctl -u named --no-pager | grep \"loaded serial\" | tail -n 2" -- -q
Oct 16 15:28:25 debian named[6773]: zone localhost/IN: loaded serial 2
Oct 16 15:28:25 debian named[6773]: zone luis.test/IN: loaded serial 2026101601
```

![comprobación de zonas](img/03-checkzone.png)

### 4.4 Comprobación de las configuraciones

Debe devolver `OK` en ambas zonas, y el log de `named` debe mostrar que cargó las dos:

```console
$ vagrant ssh -c "sudo named-checkzone luis.test /var/lib/bind/luis.test.dns; sudo named-checkzone 56.168.192.in-addr.arpa /var/lib/bind/luis.test.rev" -- -q
zone luis.test/IN: loaded serial 2026101601
OK
zone 56.168.192.in-addr.arpa/IN: loaded serial 2026101601
OK
```

```console
$ vagrant ssh -c "sudo journalctl -u named --no-pager | grep \"loaded serial\" | tail -n 2" -- -q
fOct 16 15:28:25 debian named[6773]: zone localhost/IN: loaded serial 2
Oct 16 15:28:25 debian named[6773]: zone luis.test/IN: loaded serial 2026101601
```

![comprobación de zonas](img/03-checkzone.png)

## 5. Configuración del cliente

El cliente es el propio Fedora. Con `systemd-resolved` se asocia el servidor DNS a la interfaz *host-only* de VirtualBox, solo para nuestras zonas (el prefijo `~` es *routing domain*):

```bash
sudo resolvectl dns vboxnet0 192.168.56.33
sudo resolvectl domain vboxnet0 '~luis.test' '~56.168.192.in-addr.arpa'
```

`/etc/hosts` está limpio, así que la resolución viene realmente del servidor DNS:

```console
$ grep -v "^#" /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
```

```console
$ resolvectl status vboxnet0 | head -n 12
Link 3 (vboxnet0)
    Current Scopes: DNS LLMNR/IPv4 LLMNR/IPv6
         Protocols: -DefaultRoute LLMNR=resolve -mDNS -DNSOverTLS
                    DNSSEC=no/unsupported
Current DNS Server: 192.168.56.33
       DNS Servers: 192.168.56.33
        DNS Domain: ~luis.test ~56.168.192.in-addr.arpa
     Default Route: no
```

```console
$ resolvectl query debian.luis.test
debian.luis.test: 192.168.56.33                             -- link: vboxnet0

-- Information acquired via protocol DNS in 526us.
-- Data is authenticated: no; Data was acquired via local or encrypted transport: no
-- Data from: cache
```


## 6. Comprobación con dig

Consulta directa al servidor (`@192.168.56.33`) desde el anfitrión. Se espera `status: NOERROR`, flag `aa` y la respuesta `192.168.56.33`:

```console
$ dig @192.168.56.33 debian.luis.test

; <<>> DiG 9.18.50 <<>> @192.168.56.33 debian.luis.test
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 11155
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: e40e970b672f4027010000006ad2432ad6e661674e94ed70 (good)
;; QUESTION SECTION:
;debian.luis.test.		IN	A

;; ANSWER SECTION:
debian.luis.test.	86400	IN	A	192.168.56.33

;; Query time: 0 msec
;; SERVER: 192.168.56.33#53(192.168.56.33) (UDP)
;; WHEN: Fri Oct 16 17:30:50 CEST 2026
;; MSG SIZE  rcvd: 89

```

```console
$ dig @192.168.56.33 -x 192.168.56.33

; <<>> DiG 9.18.50 <<>> @192.168.56.33 -x 192.168.56.33
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 11677
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: ee618f1dfbe04b83010000006ad2432a47d92b82dbac7e86 (good)
;; QUESTION SECTION:
;33.56.168.192.in-addr.arpa.	IN	PTR

;; ANSWER SECTION:
33.56.168.192.in-addr.arpa. 86400 IN	PTR	debian.luis.test.

;; Query time: 0 msec
;; SERVER: 192.168.56.33#53(192.168.56.33) (UDP)
;; WHEN: Fri Oct 16 17:30:50 CEST 2026
;; MSG SIZE  rcvd: 113

```

![dig](img/04-dig.png)

## 7. Comprobación con nslookup

```console
$ nslookup debian.luis.test 192.168.56.33
Server:		192.168.56.33
Address:	192.168.56.33#53

Name:	debian.luis.test
Address: 192.168.56.33

```

```console
$ nslookup 192.168.56.33 192.168.56.33
33.56.168.192.in-addr.arpa	name = debian.luis.test.

```

![nslookup](img/05-nslookup.png)

## 8. Tareas de ampliación

### 8.1 Registro CNAME (alias)

Añadido a `files/luis.test.dns`: `web IN CNAME debian.luis.test.` (y serial incrementado a `2026101602`, necesario cada vez que se modifica una zona).

```console
$ dig @192.168.56.33 web.luis.test CNAME +short
debian.luis.test.
```

```console
$ nslookup -type=cname web.luis.test 192.168.56.33
Server:		192.168.56.33
Address:	192.168.56.33#53

web.luis.test	canonical name = debian.luis.test.

```


### 8.2 Registro TXT

Registro descriptivo en la raíz de la zona con mi usuario de GitHub y nombre (serial `2026101603`):

```console
$ dig @192.168.56.33 luis.test TXT +short
"LuisVilRiv - Luis Villegas Rivera"
```

```console
$ nslookup -type=txt luis.test 192.168.56.33
Server:		192.168.56.33
Address:	192.168.56.33#53

luis.test	text = "LuisVilRiv - Luis Villegas Rivera"

```


### 8.3 Resolución inversa (PTR)

La IP del servidor resuelve a su FQDN gracias al registro `33 IN PTR debian.luis.test.` de la zona inversa:

```console
$ dig @192.168.56.33 -x 192.168.56.33 +short
debian.luis.test.
```

```console
$ nslookup 192.168.56.33 192.168.56.33
33.56.168.192.in-addr.arpa	name = debian.luis.test.

```


### 8.4 Comprobación de autoridad (flag `aa`)

Se compara una consulta a nuestro dominio con otra a un dominio externo. Nos fijamos en la línea `;; flags:`:

```console
$ dig @192.168.56.33 debian.luis.test | grep "^;; flags"
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```

```console
$ dig @192.168.56.33 www.google.es | grep "^;; flags"
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```


### 8.4 Comprobación de autoridad (flag `aa`)

Se compara una consulta a nuestro dominio con otra a un dominio externo. Nos fijamos en la línea `;; flags:`:

```console
$ dig @192.168.56.33 debian.luis.test | grep "^;; flags"
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```

```console
$ dig @192.168.56.33 www.google.es | grep "^;; flags"
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```


![flag aa](img/06-flag-aa.png)

**Explicación:** `aa` (*Authoritative Answer*) aparece con `luis.test` porque nuestro servidor es el maestro de esa zona y responde con datos propios; con `www.google.es` no aparece porque la respuesta la obtiene (por recursión) de otros servidores y no es autoritativo de ese dominio.

## 9. Script de autocomprobación (`test.sh`)

`test.sh` (raíz del repo, con permisos de ejecución) comprueba la sintaxis de la configuración y las resoluciones. Se lanza automáticamente en el **último** script de provisión (`config/99-test.sh`) y muestra su resultado al final de `vagrant up`.

![test.sh](img/07-test-sh.png)

Salida real:

```console
$ vagrant ssh -c "sudo /vagrant/test.sh" -- -q
=== 1. Comprobación de sintaxis de ficheros ===
[OK] named.conf.options
zone luis.test/IN: loaded serial 2026101603
OK
[OK] Zona directa
zone 56.168.192.in-addr.arpa/IN: loaded serial 2026101601
OK
[OK] Zona inversa
=== 2. Comprobación de resolución ===
-- A (debian.luis.test):
192.168.56.33
-- CNAME (web.luis.test):
debian.luis.test.
-- TXT (luis.test):
"LuisVilRiv - Luis Villegas Rivera"
-- PTR (192.168.56.33):
debian.luis.test.
=== 3. Autoridad (debe aparecer aa) ===
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```


## 9. Script de autocomprobación (`test.sh`)

`test.sh` (raíz del repo, con permisos de ejecución) comprueba la sintaxis de la configuración y las resoluciones. Se lanza automáticamente en el **último** script de provisión (`config/99-test.sh`) y muestra su resultado al final de `vagrant up`.

![test.sh](img/07-test-sh.png)

Salida real:

```console
$ vagrant ssh -c "sudo /vagrant/test.sh" -- -q
=== 1. Comprobación de sintaxis de ficheros ===
[OK] named.conf.options
zone luis.test/IN: loaded serial 2026101603
OK
[OK] Zona directa
zone 56.168.192.in-addr.arpa/IN: loaded serial 2026101601
OK
[OK] Zona inversa
=== 2. Comprobación de resolución ===
-- A (debian.luis.test):
192.168.56.33
-- CNAME (web.luis.test):
debian.luis.test.
-- TXT (luis.test):
"LuisVilRiv - Luis Villegas Rivera"
-- PTR (192.168.56.33):
debian.luis.test.
=== 3. Autoridad (debe aparecer aa) ===
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```

