getent passwd vagrant >/dev/null 2>&1
if [ $? -ne 0 ]; then
  useradd -d /home/vagrant -G adm,sudo -m -s /bin/bash vagrant
fi

chown -R vagrant: /vagrant/*
