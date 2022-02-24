#!/usr/bin/env bash
# This will only work on Centos 7 (it has not been tested on other distros)

# unpack the agent
tar -xvf /vagrant/elastic-agent-8.0.0-linux-x86_64.tar.gz -C /opt/

# Install the agent
yes | sudo /opt/elastic-agent-8.0.0-linux-x86_64/elastic-agent install -f \
  --url=https://10.0.0.10:8220 \
  --enrollment-token=$(cat /vagrant/AEtoken.txt) \
  --certificate-authorities=/vagrant/ca.crt

echo "Script done. To connect go to https://10.0.0.10:5601 on your host system"
echo "The elastic password will be displayed in the terminal you ran Vagrant from"
echo "Under the line --Security autoconfiguration information--"