# Unpack the archive
Expand-Archive C:\vagrant\elastic-agent-8.0.0-windows-x86_64.zip -DestinationPath 'C:\Program Files'

# Install the agent
& 'C:\Program Files\elastic-agent-8.0.0-windows-x86_64\elastic-agent.exe' install -f --url=https://192.168.1.44:8220 --certificate-authorities='C:\vagrant\ca.crt' --enrollment-token=$(Get-Content C:\vagrant\AEtoken.txt)
