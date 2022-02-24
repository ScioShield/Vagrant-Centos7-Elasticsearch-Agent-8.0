#!/usr/bin/env bash
# This will only work on Centos 7 (it has not been tested on other distros)

# Test if the VM can reach the internet to download packages
until ping -c 1 google.com | grep -q "bytes from"
do
    echo "offline, still waiting..."
    sleep 5
done
echo "online"

# Install Elasticsearch, Kibana, and Unzip
yum install -y unzip wget

# Get the GPG key
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# Add Elastic and Kibana and the Elastic Agent
# Download and install Ealsticsearch and Kibana change ver to whatever you want
# For me 8.0.0 is the latest we palce it in /vagrant to not download it again
# The -q flag is need to not spam stdout on the host machine
# We also pull the SHA512 hashes for you to check
VER=8.0.0
wget -nc -q https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$VER-x86_64.rpm -P /vagrant
wget -nc -q https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$VER-x86_64.rpm.sha512 -P /vagrant

wget -nc -q https://artifacts.elastic.co/downloads/kibana/kibana-$VER-x86_64.rpm -P /vagrant
wget -nc -q https://artifacts.elastic.co/downloads/kibana/kibana-$VER-x86_64.rpm.sha512 -P /vagrant

wget -nc -q https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-$VER-linux-x86_64.tar.gz -P /vagrant
wget -nc -q https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-$VER-linux-x86_64.tar.gz.sha512 -P /vagrant

# We output to a temp password file allwoing auto config later on
tar -xvf /vagrant/elastic-agent-8.0.0-linux-x86_64.tar.gz -C /opt/
rpm --install /vagrant/elasticsearch-$VER-x86_64.rpm 2>&1 | tee /root/ESUpass.txt
rpm --install /vagrant/kibana-$VER-x86_64.rpm

# Make the cert dir to prevent pop-up later
mkdir /tmp/certs/

# var settings
IP_ADDR=10.0.0.10
K_PORT=5601
ES_PORT=9200
F_PORT=8220

# Config the instances file for cert gen the ip is 10.0.0.10
cat > /tmp/certs/instance.yml << EOF
instances:
  - name: 'elasticsearch'
    dns: [ 'elasticsearch.localdomain' ]
    ip: [ '$IP_ADDR' ]
  - name: 'kibana'
    dns: [ 'kibana.localdomain' ]
    ip: [ '$IP_ADDR' ]
  - name: 'fleet'
    dns: [ 'fleet.localdomain' ]
    ip: [ '$IP_ADDR' ]
EOF

# Make the certs and move them where they are needed
/usr/share/elasticsearch/bin/elasticsearch-certutil ca --pem --pass secret --out /tmp/certs/elastic-stack-ca.zip
unzip /tmp/certs/elastic-stack-ca.zip -d /tmp/certs/
/usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca-cert /tmp/certs/ca/ca.crt -ca-key /tmp/certs/ca/ca.key --ca-pass secret --pem --in /tmp/certs/instance.yml --out /tmp/certs/certs.zip
unzip /tmp/certs/certs.zip -d /tmp/certs/

mkdir /etc/kibana/certs
mkdir /etc/pki/fleet

cp /tmp/certs/ca/ca.crt /tmp/certs/elasticsearch/* /etc/elasticsearch/certs
cp /tmp/certs/ca/ca.crt /tmp/certs/kibana/* /etc/kibana/certs
cp /tmp/certs/ca/ca.crt /tmp/certs/fleet/* /etc/pki/fleet
cp -r /tmp/certs/* /root/

# This cp should be an unaliased cp to replace the ca.crt if it exists in the shared /vagrant dir
cp /tmp/certs/ca/ca.crt /vagrant

# Config and start Elasticsearch (we are also increasing the timeout for systemd to 500)
mv /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak

cat > /etc/elasticsearch/elasticsearch.yml << EOF
# ======================== Elasticsearch Configuration =========================
#
# ----------------------------------- Paths ------------------------------------
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
# ---------------------------------- Network -----------------------------------
network.host: $IP_ADDR
http.port: $ES_PORT
# --------------------------------- Discovery ----------------------------------
discovery.type: single-node
# ----------------------------------- X-Pack -----------------------------------
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.key: /etc/elasticsearch/certs/elasticsearch.key
xpack.security.transport.ssl.certificate: /etc/elasticsearch/certs/elasticsearch.crt
xpack.security.transport.ssl.certificate_authorities: [ "/etc/elasticsearch/certs/ca.crt" ]
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.key: /etc/elasticsearch/certs/elasticsearch.key
xpack.security.http.ssl.certificate: /etc/elasticsearch/certs/elasticsearch.crt
xpack.security.http.ssl.certificate_authorities: [ "/etc/elasticsearch/certs/ca.crt" ]
xpack.security.authc.api_key.enabled: true
EOF

sed -i 's/TimeoutStartSec=75/TimeoutStartSec=500/g' /lib/systemd/system/elasticsearch.service
systemctl daemon-reload
systemctl start elasticsearch
systemctl enable elasticsearch

# Gen the users and paste the output for later use
/usr/share/elasticsearch/bin/elasticsearch-reset-password -b -u kibana_system -a > /root/Kibpass.txt
# /usr/share/elasticsearch/bin/elasticsearch-reset-password -b -u elastic -a > /root/ESUpass.txt

# Add the Kibana password to the keystore
grep "New value:" /root/Kibpass.txt | awk '{print $3}' | sudo /usr/share/kibana/bin/kibana-keystore add --stdin elasticsearch.password

# Configure and start Kibana adding in the unique kibana_system keystore pass and gening the sec keys
cat > /etc/kibana/kibana.yml << EOF
# =========================== Kibana Configuration ============================
# -------------------------------- Network ------------------------------------
server.host: $IP_ADDR
server.port: $K_PORT
# ------------------------------ Elasticsearch --------------------------------
elasticsearch.hosts: ["https://$IP_ADDR:$ES_PORT"]
elasticsearch.username: "kibana_system"
elasticsearch.password: "\${elasticsearch.password}"
# ---------------------------------- Various -----------------------------------
server.ssl.enabled: true
server.ssl.certificate: "/etc/kibana/certs/kibana.crt"
server.ssl.key: "/etc/kibana/certs/kibana.key"
elasticsearch.ssl.certificateAuthorities: [ "/etc/kibana/certs/ca.crt" ]
# ---------------------------------- X-Pack ------------------------------------
xpack.security.encryptionKey: "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32 ; echo '')"
xpack.encryptedSavedObjects.encryptionKey: "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32 ; echo '')"
xpack.reporting.encryptionKey: "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32 ; echo '')"
EOF

systemctl start kibana
systemctl enable kibana

# Test if Kibana is running
echo "Testing if Kibana is online, could take some time, no more than 5 min"
until curl --silent --cacert /tmp/certs/ca/ca.crt -XGET 'https://10.0.0.10:5601/api/fleet/agent_policies' -H 'accept: application/json' -u elastic:$(sudo grep "generated password for the elastic" /root/ESUpass.txt | awk '{print $11}') | grep -vq '"items":\[\]'
do
    echo "Kibana starting, still waiting..."
    sleep 5
done
echo "Kibna online"

# Make the Fleet token
curl --silent -XPOST 'https://10.0.0.10:9200/_security/service/elastic/fleet-server/credential/token/fleet-token-1' \
 --cacert /tmp/certs/ca/ca.crt \
 -u elastic:$(sudo grep "generated password for the elastic" /root/ESUpass.txt | awk '{print $11}') > /root/Ftoken.txt

# Get the policy key
until curl --silent --cacert /tmp/certs/ca/ca.crt -XGET 'https://10.0.0.10:5601/api/fleet/agent_policies' -H 'accept: application/json' -u elastic:$(sudo grep "generated password for the elastic" /root/ESUpass.txt | awk '{print $11}') | grep -q "Default policy"
do 
  echo "Kibana loading policies, still waiting..."
  sleep 5
done
sleep 5
echo "Kibana policies loaded"
curl --silent --cacert /tmp/certs/ca/ca.crt -XGET 'https://10.0.0.10:5601/api/fleet/agent_policies' -H 'accept: application/json' -u elastic:$(sudo grep "generated password for the elastic" /root/ESUpass.txt | awk '{print $11}') > /root/Pid.txt


# Add host IP and yaml settings to Fleet API
curl --silent --cacert /tmp/certs/ca/ca.crt -XPUT 'https://10.0.0.10:5601/api/fleet/outputs/fleet-default-output' \
 -u elastic:$(sudo grep "generated password for the elastic" /root/ESUpass.txt | awk '{print $11}') \
 -H 'accept: application/json' \
 -H 'kbn-xsrf: reporting' \
 -H 'Content-Type: application/json' -d'{
"name": "default",
"type": "elasticsearch",
"is_default": true,
"is_default_monitoring": true,
"hosts": [
  "https://10.0.0.10:9200"
  ],
"ca_sha256": "",
"ca_trusted_fingerprint": "",
"config_yaml": "ssl.certificate_authorities: [\"/vagrant/ca.crt\"]"
}'

# Add fleet server IP to Fleet API
curl --silent --cacert /tmp/certs/ca/ca.crt -XPUT 'https://10.0.0.10:5601/api/fleet/settings' \
 -u elastic:$(sudo grep "generated password for the elastic" /root/ESUpass.txt | awk '{print $11}') \
 -H 'accept: application/json' \
 -H 'kbn-xsrf: reporting' \
 -H 'Content-Type: application/json' -d'{
    "fleet_server_hosts": [
      "https://10.0.0.10:8220"
    ]
}'

# Install the fleet server
yes | sudo /opt/elastic-agent-8.0.0-linux-x86_64/elastic-agent install --url=https://10.0.0.10:8220 \
 --fleet-server-es=https://10.0.0.10:9200 \
 --fleet-server-service-token=$(cat /root/Ftoken.txt | sed "s/\,/'\n'/g" | grep -oP '[^"name"][a-zA-Z0-9]{50,}') \
 --fleet-server-policy=$(cat /root/Pid.txt | sed "s/\},{/'\n'/g" | grep "Default Fleet Server policy" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}') \
 --certificate-authorities=/vagrant/ca.crt \
 --fleet-server-es-ca=/etc/pki/fleet/ca.crt \
 --fleet-server-cert=/etc/pki/fleet/fleet.crt \
 --fleet-server-cert-key=/etc/pki/fleet/fleet.key

# Get the default policy id
cat /root/Pid.txt | sed "s/\},{/'\n'/g" | grep "Default policy" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}' > /root/Eid.txt
curl --silent --cacert /tmp/certs/ca/ca.crt -XGET 'https://10.0.0.10:5601/api/fleet/enrollment_api_keys' -H 'accept: application/json' -u elastic:$(sudo grep "generated password for the elastic" /root/ESUpass.txt | awk '{print $11}') | sed "s/\},{/'\n'/g" | grep -E -m1 $(cat /root/Eid.txt) | grep -oP '[a-zA-Z0-9\=]{40,}' > /vagrant/AEtoken.txt