#!/bin/bash

# Install MySQL
echo "Installing MySQL"

debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

sudo apt update
sudo apt install mysql-server -y
sudo systemctl start mysql.service

#Create and fill Database
echo "Creating and filling database"
sudo mysql -h localhost -u root -proot < /home/vagrant/init.sql

#Adding permissions to remote access
echo "Adding permissions to remote access"
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql.service

# Instal Python Flask and Flask-MySQLdb
sudo apt install python3-dev default-libmysqlclient-dev build-essential pkg-config mysql-client python3-pip -y
pip3 install Flask==2.3.3
pip3 install flask-cors
pip3 install Flask-MySQLdb
pip install Flask-SQLAlchemy

# Install Apache2 to deploy
echo "Installing Apache"
sudo apt install apache2 libapache2-mod-wsgi-py3 -y

# Install Docker
echo "Installing Docker"
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Docker Compose
echo "Installing Docker Compose"
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Generate SSL keys
echo "Generating SSL keys"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /home/vagrant/webapp/localhost.key -out /home/vagrant/webapp/localhost.crt -subj "/C=ES/ST=Valle del cauca/L=Cali/O=Universidad Autónoma de Occidente/OU=Facultad de Ingeniería/CN=Daniel Hernández Valderrama"


# Create my-httpd-vhosts.conf file
echo "Creating my-httpd-vhosts.conf"
sudo bash -c 'cat > /home/vagrant/webapp/my-httpd-vhosts.conf <<EOF
# Redirigir HTTP a HTTPS
<VirtualHost *:80>
    ServerName 192.168.50.2
    DocumentRoot /var/www/webapp

    # Redirige todo el tráfico HTTP a HTTPS
    Redirect permanent / https://192.168.50.2/
</VirtualHost>

<VirtualHost *:443>
    DocumentRoot "/var/www/webapp"
    ServerName localhost

    SSLEngine on
    SSLCertificateFile "/etc/ssl/certs/localhost.crt"
    SSLCertificateKeyFile "/etc/ssl/private/localhost.key"

    <Directory /var/www/webapp>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF'

# Copy SSL certificate and key to the appropriate locations
echo "Copying SSL certificate and key"
sudo cp /home/vagrant/webapp/localhost.crt /etc/ssl/certs/localhost.crt
sudo cp /home/vagrant/webapp/localhost.key /etc/ssl/private/localhost.key

# Enable mod_wsgi module
echo "Enabling mod_wsgi module"
sudo a2enmod wsgi

# Copy the custom Apache virtual host config
echo "Copying custom Apache virtual host config"
sudo cp /home/vagrant/webapp/my-httpd-vhosts.conf /etc/apache2/sites-available/my-ssl.conf

# Enable SSL module, configure Apache for python, and enable our SSL site configuration
echo "Configuring Apache"
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2dissite 000-default default-ssl
sudo a2ensite my-ssl

# Copy webapp directory to /var/www
echo "Copying webapp to /var/www"
sudo cp -r /home/vagrant/webapp /var/www/webapp

# Create application.wsgi file
echo "Creating application.wsgi"
sudo bash -c 'cat > /var/www/webapp/application.wsgi <<EOF
#!/usr/bin/python
import sys
sys.path.insert(0,"/var/www/webapp/")
from run import app as application
EOF'

# Configure Apache
echo "Configuring Apache"
sudo bash -c 'cat > /etc/apache2/sites-available/000-default.conf <<EOF
WSGIScriptAlias / /var/www/webapp/application.wsgi
DocumentRoot /var/www/webapp
<VirtualHost *>
    <Directory /var/www/webapp/>
        Order deny,allow
        Allow from all
    </Directory>
</VirtualHost>
EOF'

# Enable the site and restart Apache
echo "Enabling site"
sudo a2ensite 000-default.conf
echo "Restarting Apache"
sudo systemctl restart apache2

# Apache configuration syntax
echo "Checking Apache configuration syntax"
sudo apachectl -t

# Dockerfile Creation and Configuration
echo "Creating and configuring Dockerfile"
sudo bash -c 'cat > /home/vagrant/webapp/Dockerfile <<EOF
# Usa una imagen base de Python
FROM python:3.9

# Instala dependencias necesarias
RUN apt-get update && \
    apt-get install -y apache2 libapache2-mod-wsgi-py3 libmariadb-dev build-essential pkg-config && \
    pip install Flask==2.3.3 flask-cors Flask-MySQLdb Flask-SQLAlchemy && \
    rm -rf /var/lib/apt/lists/*


# Copia la aplicación y configura Apache
COPY webapp /var/www/webapp
COPY webapp/my-httpd-vhosts.conf /etc/apache2/sites-available/my-ssl.conf

# Habilita SSL y el módulo WSGI de Apache
RUN a2enmod wsgi ssl && \
    a2ensite my-ssl && \
    a2dissite 000-default

# Expone el puerto 443 para HTTPS
EXPOSE 443

# Comando para iniciar Apache
CMD ["apachectl", "-D", "FOREGROUND"]
EOF'

# docker-compose.yml Creation and Configuration
echo "Creating and configuring docker-compose"
sudo bash -c 'cat > /home/vagrant/webapp/docker-compose.yml <<EOF
services:
  webapp:
    build: .
    ports:
      - "8443:443"
    volumes:
      - ./webapp:/var/www/webapp
      - ./webapp/localhost.crt:/etc/ssl/certs/localhost.crt
      - ./webapp/localhost.key:/etc/ssl/private/localhost.key
    depends_on:
      - db
    environment:
      - MYSQL_HOST=db
      - MYSQL_USER=root
      - MYSQL_PASSWORD=root
      - MYSQL_DB=myflaskapp

  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: myflaskapp
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
EOF'

# sudo docker-compose up --build

# Creating User and directories for Prometheus
echo "Creating a System User for Prometheus"
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus

echo "Creating directories for Prometheus"
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

# Getting Prometheus from Github
echo "Getting Prometheus"
wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz
tar vxf prometheus*.tar.gz
cd prometheus*/

# Exporting files from Prometheus zip
echo "Moving files and changing ownership"
sudo mv prometheus /usr/local/bin
sudo mv promtool /usr/local/bin
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

sudo mv consoles /etc/prometheus
sudo mv console_libraries /etc/prometheus
sudo mv prometheus.yml /etc/prometheus
sudo chown prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Node Exporter and Grafena Configuration
echo "Configuring Prometheus to Node Exporter"
sudo bash -c 'cat > /etc/prometheus/prometheus.yml <<EOF

EOF'

# Creating Prometheus Systemd Service
echo "Creating Prometheus Systemd Service"
sudo bash -c 'cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target

EOF'

# Restarting services
echo "Restarting services and enabling ports for firewall"
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo ufw allow 9090/tcp

# Getting Node Exporter from Github
echo "Getting Node Exporter"
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
cd ..

# cd node_exporter-*.*-amd64
# ./node_exporter

