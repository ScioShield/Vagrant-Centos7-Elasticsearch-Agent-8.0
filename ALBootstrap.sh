#!/usr/bin/env bash
# This will only work on Centos 7 (it has not been tested on other distros)

# unpack the agent
tar -xvf /vagrant/elastic-agent-8.0.0-linux-x86_64.tar.gz -C /opt/

# Check if Kibana is reachable 
kcheck=$(curl -L --silent --output /dev/null --cacert /vagrant/ca.crt -XGET 'https://192.168.1.44:5601' --write-out %{http_code})
until [ $kcheck -eq 200 ]
do
  echo "Checking if Kibana is reachable, retrying..."
  sleep 5
done
echo "Kibana is reachable"

# Install the agent
sudo /opt/elastic-agent-8.0.0-linux-x86_64/elastic-agent install -f \
  --url=https://192.168.1.44:8220 \
  --enrollment-token=$(cat /vagrant/AEtoken.txt) \
  --certificate-authorities=/vagrant/ca.crt

echo "Script done. To connect go to https://192.168.1.44:5601 on your host system"
echo "The elastic password will be displayed in the terminal you ran Vagrant from"
echo "Under the line --Security autoconfiguration information--"