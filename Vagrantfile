# -*- mode: ruby -*-
# Práctica DNS paso a paso - Luis Villegas Rivera
Vagrant.configure("2") do |config|
  # Debian 12 (bookworm): incluye BIND 9.18, la misma versión que muestra el enunciado
  config.vm.box = "debian/bookworm64"
  config.vm.hostname = "debian"

  # Tarjeta de red PRIVADA 192.168.56.0/24. El .1 es del anfitrión, el servidor es el .33
  config.vm.network "private_network", ip: "192.168.56.33"

  # Carpeta del repo -> /vagrant en la VM (por rsync; en el anfitrión se actualiza con "vagrant rsync")
  config.vm.synced_folder ".", "/vagrant", type: "rsync",
    rsync__exclude: [".git/", ".vagrant/"]

  config.vm.provider "virtualbox" do |vb|
    vb.name = "dns-luis"
    vb.memory = 1024
    vb.cpus = 1
  end

  # Provisión: los scripts de config/ se ejecutan en orden (se añaden fase a fase)
  config.vm.provision "shell", path: "config/01-instalar-bind.sh"
  config.vm.provision "shell", path: "config/02-configurar-bind.sh"
  config.vm.provision "shell", path: "config/99-test.sh"
end
