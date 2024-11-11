# Para ejecutar la aplicación

## Inicia y entra a SSH de vagrant

```
vagrant up
vagrant ssh servidorWeb
```

# 1. Verifica que funciona Apache

Una vez terminen de instalarse todas las dependencias y configuraciones de script.sh al levantar la máquina, puedes verificar que apache funciona entrando a la ruta:
```
192.168.50.2
```
Te saldrá un aviso de que es una página insegura, le das a más detalles e ingresar de todas formas. Si quieres ver el certificado resultante, basta con darle click a la alerta de 'No seguro' al lado del buscador (depende del navegador) y luego a ver certificados. Debería aparecer toda la información relacionada con este proyecto.

Con esto estaríamos comprobando que el servicio seguro de apache funciona pero, ¿cómo lo hace?

El archivo script.sh sigue la siguiente secuencia:

## Claves de SSL

Utilizando el comando
```
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /home/vagrant/webapp/localhost.key -out /home/vagrant/webapp/localhost.crt -subj "/C=ES/ST=Valle del cauca/L=Cali/O=Universidad Autónoma de Occidente/OU=Facultad de Ingeniería/CN=Daniel Hernández Valderrama"
```
Se generan un certificado SSL y una clave dentro de la carpeta webapp y tendrán el nombre de localhost

## Redireccionamiento de raíz HTTP a HTTPS

Para esto, el script crea un archivo llamado my-httpd-vhosts.conf en webapp y coloca el siguiente código dentro:
```
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
```

Esto redirige todas las entradas por el puerto 80 hacia el puerto 443 y lo obliga a entrar en el protocolo seguro utilizando el certificado y la contraseña creados en el paso anterior

## Reubicación de certificado SSL y clave

Para esto solamente hay que copiar el certificado y su clave creados en webapp hacia una carpeta más adecuada, ssl/certs y ssl/private:
```
sudo cp /home/vagrant/webapp/localhost.crt /etc/ssl/certs/localhost.crt
sudo cp /home/vagrant/webapp/localhost.key /etc/ssl/private/localhost.key
```

## Reubicación de configuración customizada para hosts virtuales de Apache

Para ello simplemente se debe copiar el archivo .conf que se creó para hacer la redirección de raíz HTTP a HTTPS en la carpeta sites-available de apache:
```
sudo cp /home/vagrant/webapp/my-httpd-vhosts.conf /etc/apache2/sites-available/my-ssl.conf
```

## Ajustes finales

Luego, el script simplemente habilita los siguientes servicios y reinicia apache:
```
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2dissite 000-default default-ssl
sudo a2ensite my-ssl
sudo a2ensite 000-default.conf
sudo systemctl restart apache2
```

# 2. Verifica que Docker y docker-compose empaquete la aplicación web

Para verificar que funciona el docker y docker-compose, es necesario colocar la siguiente línea:
```
sudo docker-compose up --build
```

Con esto saldrán todos los logs del contenedor vagrant-db-1, ahora para ver su contenido, será necesario entrar a
```
192.168.50.2:8443
```

Aquí se mostrarán todas las carpetas que tiene webapp, demostrando que docker-compose ha empaquetado correctamente la aplicación web

En cuanto a cómo funciona, tenemos los siguientes comandos en script.sh

## 

# 3. EC2 con AWS

# 4. Verificación de Prometheus

# 5. Verificación de Node Exporter

# 6. Verificación de Grafana + Prometheus