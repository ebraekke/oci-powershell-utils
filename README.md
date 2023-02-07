# ebraekke/oci-powershell-utils

PowerShell scripts that utilize the the PowerShell API for OCI.

The goal is to highlight the possibilities inherent in the robust feature set of OCI
by replicating some of the functionality available inside of the OCI cloud console  

Key services used: Bastion and Database Tools in addition to MySQL and Autonomous DB.  

There are three main scripts: 

* `Invoke_Ssh_Session.ps1` invokes an ssh session via a Bastion.
* `Invoke_Mysqlsh_Session.ps1` invokes a mysqlsh via a Bastion.
* `Invoke_Sqlcl_Session.ps1` invokes sqlcl via Bastion.

These highlight how a secure channel can be created via Bastion and then utilized by another process.

## How it works

The `Invoke_*.ps1` scripts have the same structure:

* Validate presence of SSH software
* Validate inputs
    * Collect additional information based on inputs
* Validate presence of software needed for this specific invoke (for example "mysqlsh")  
* Delegate to cmdlet `New-OpuPortForwardingSessionFull`
    * Create ephemeral SSH key pair
    * Create Bastion session
    * Create SSH port forwarding session 
    * Return object containing information abt Bastion session, SSH process, SSH keys and  Local port 
* Create the specific (interactive) session (SSH, mysqlsh, etc) trough the Local Port retuned by cmdlet
    * Wait for completion
* Request teardown via cmdlet `Remove-OpuPortForwardingSessionFull`

## Notes 

In a real life DevOps scenario the setup -- and later teardown -- of connectivity would most likely be done by one process,
while the actual state change would be done by another process. 
This "other" process could for example be Ansible for virtual machines and Liquibase for databases.  

The script `New_Port_Forwarding_Sesssion_Full.ps1` is such a setup script. 

It returns an object: 
```PowerShell
$BastionSessionDescription = [PSCustomObject]@{
    BastionSession = <The_OCI_Bastion_Session_Object>
    SShProcess = <The_Process_Handle_for_the_SSH_Session>
    PrivateKey = "<The name of the ephemeral private SSH key used>"
    PublicKey = "<The name of the public key for the PrivateKey above>"
    LocalPort = <The_listening_port_for_the_SSH_session>
}
```

This object can be used for teardown. The destroy process is handled by `Remove_Port_Forwarding_Session_Full.ps1`.
Pass the object returned by `New_Port_Forwarding_Sesssion_Full.ps1` as parameter `-BastionSessionDescription`. 

## Requirements 

The following software must be installed in your environment: 

* OCI PowerShell Modules
* OpenSSH binaries
* Mysqlsh (for Invoke_Mysqlsh_Session.ps1)
* Sql (AKA sqlcl for Invoke_Sqlcl.ps1)

## Windows only? 

PowerShell is cross-platform, so it should work.  
But, for now I short-circuit and fail on purpose if you try to run on Mac or Linux. 

## Why not managed SSH session? 

I have decided to (only) use port forwarding for two reasons: 

1. Simplicity: To create a session to a service endpoint, for instance a database listener, port forwarding is the only option. So I decided to keep it DRY (Don't Repeat Yourself). 

2. Managed SSH sessions requires that an agent is activated on the target. This agent is not always present. In some instances the agent may not be available. This was the case initially with Ubuntu on ARM for example.  

## Why PowerShell?

PowerShell is an extremely powerful and forgiving environment for exploring an API.
I especially appreciate the ability to inspect returned objects.
This is the ultimate learning environment for me. 
