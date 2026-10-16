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

