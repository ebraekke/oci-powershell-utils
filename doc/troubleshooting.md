
## Before you begin 

This script suite is not replacement for knowing your ssh. 
The ssh client, the most common implementation of the ssh protocol,  is often referred to as a Swiss Army Knife. 

Please ensure that you can establish port forwarding sessions to your desired bastion service endpoint 
**before** experimenting with these utilities.

## Make sure ~/.ssh/known_hosts includes the bastion service endpoints you will be using

The port forwarding process may fail if there is not a proper entry for the bastion endpoint for the specific region.  

I collect this information by manually creating a port forwarding session and ensuring that I save the 
fingerprint to my `~/.ssh/known_hosts` file.

As of 5th of April 2023 these are the settings I use for FRA (Frankfurt) and ARN (Stockholm): 
```
host.bastion.eu-stockholm-1.oci.oraclecloud.com,129.149.83.110 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMZtuRdd/IgT4/chkaG7s123h6U16MkbG/IUWev9e/DEOno3swbYy7EfmO3nlhf4/rHKKVU7wxYSsjMzH9OnYL43ln/DyaT1ROxIaSMJsckGfo20kfbvfKs+LEGD0Qz0FZIfDPl2P1J6iQH80DHPntMkS2HnSk/xO7BhFqkZ1XbuthZ6RKbRbKM7dTbXr1Q+O4EGfM/JcwCeZvIgf1nr/Gw7zLLBqYqnOuLfxMdnptzZoOWKD0dlY8GWuIPxepN0QFKrOS8/GSIL49EOo7CRPatvXtrbzBX4MI+je/hJVZf1aonvmEA7Q0q2nAI8+jboJkYIZv5Xw7Yo3aAt2ZRzTh
host.bastion.eu-frankfurt-1.oci.oraclecloud.com,138.1.40.158 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqnxXAAdFhIdgPepPUcKbBfMU9CX0b546OhxAamNzo7E0Bp+mdSR191/Cvx97dccsi2R/ijL7FSg2c/FnNqOqo8VGjT+uXPCnS2YIGTdlA0u9UsnW+wGKbDhmyhncHHGr7heAax5ic0C1iE4HUVhDHb2+LbBQK7xcigoO+7Bshj9/4obQsnuxNZyLE3badwDEDgHJ9xbtmdXU93CzSHWgzZdwEWb2wSPLKPzrUTIZg7JvH/SpMdqZ2yoDdXI6nG+7ZnypanMpZMrbIpaz68PP+Q4EoY2ojKW8WnoL+pxK5cXzY182DCSAAf1QXAVX38dDnCmU0S52VpoI+O6xiqi0T
```

## Key exchange errors

On my personal setup (Windows on Intel) I have seen some weird behaviors wrt key exchanges.

The section below is from my `~/.ssh/config` file. 
You may need one entry like this for each region if you experience similar problems.

```
# Hack due to challenges with bastion service with newer ssh (client) versions
# At least 8.9 and 9.x have this problem:
#
# Unable to negotiate with 138.1.40.158 port 22: no matching host key type found. Their offer: ssh-rsa
# kex_exchange_identification: Connection closed by remote host
# Connection closed by UNKNOWN port 65535
#
# Also based on doc:
# https://docs.oracle.com/en-us/iaas/Content/Bastion/Tasks/troubleshooting_connect_session_failed.htm
host host.bastion.eu-frankfurt-1.oci.oraclecloud.com
        HostKeyAlgorithms +ssh-rsa
        PubkeyAcceptedKeyTypes +ssh-rsa
        ServerAliveInterval 120
        ServerAliveCountMax 3
```
