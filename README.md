# Vagrant-Centos7-Elasticsearch-Agent-8  

## Blog  
Post - TBD  

## Requirements
RAM - 11GB  
CPU - 7 vCores  

## Setup  
Vagrantfile to setup single node ES + Kib + Fleet cluster and a stand alone Elastic Agent  
To start the Vagrant VM run <code>vagrant up</code>  
To log in run  
<code>vagrant ssh Elastic</code>  
<code>vagrant ssh Agent</code>  
Log into Kibana  
<code>https://10.0.0.10:5601</code>  
Username: <code>elastic</code>  
The password is printed to the console / terminal you ran <code>vagrant up</code> from  
under the section <code>--Security autoconfiguration information--</code>  