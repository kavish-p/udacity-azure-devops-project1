#!/bin/bash

sudo apt-get update
sudo apt-get install -y apache2

echo 'Hello, World!' > index.html
sudo rm /var/www/html/index.html
sudo mv index.html /var/www/html/index.html