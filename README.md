# Vagrant-Centos7-Elasticsearch-Agent-8  

## Blog  
Post - TBD  

## Requirements
RAM - 13GB  
CPU - 8 vCores  

## Setup  
Vagrantfile to setup single node ES + Kib + Fleet cluster and a stand alone Elastic Agent on Linux and Windows  
To start the Vagrant VM run <code>vagrant up</code>  
To log in run  
<code>vagrant ssh Elastic</code>  
<code>vagrant ssh Linux</code>  
<code>vagrant ssh Windows</code>  

### DNS settings
Replace (Vagrant host ip) with the IP of the host machine you will run Vagrant from  
Windows Powershell  
<code>Add-Content 'C:\Windows\System32\Drivers\etc\hosts' "(Vagrant host ip) elastic-8-sec"</code>  
Linux Bash  
<code>echo "(Vagrant host ip) elastic-8-sec" >> /etc/hosts</code>  

## Kibana  
Log into Kibana (local)  
<code>https://10.0.0.10:5601</code>   
Log into Kibana (remote)  
<code>https://elastic-8-sec:5601</code>  
Username: <code>elastic</code>  
The password is printed to the console / terminal you ran <code>vagrant up</code> from  
under the section <code>--Security autoconfiguration information--</code>  
Log into Caldera (remote)  