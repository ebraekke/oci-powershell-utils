<#
.SYNOPSIS
Invoke  an mysqlsh sesssion with a target host accessible through the OCI Bastion service.

.DESCRIPTION
Using the Bastion service and tunneling a mysqlsh session will be invoked on the target DB system. 
A ephemeral key pair for the Bastion session is created (and later destroyed). 
This combo will allow you to "connect" through the Bastion service via a local port and to your destination: $TargetHost:$TargetPort   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER ConnectionId
OCID of connection containing the details about the database system. 

.PARAMETER TestOnly
Set to $true to perform setup and teardown, but skip the start of msqlsh.
Incurs a 30 second wait. 

.EXAMPLE 
## Successfully invoking script and accessing DB via bastion 
❯ .\Invoke_Mysqlsh_Session.ps1 -BastionId $bastion_ocid -connectionId $conn_ocid
Getting details from connection
Creating ephemeral key pair
Creating Port Forwarding Session to 10.0.1.27:3306
Waiting for creation of bastion session to complete
Creating SSH tunnel
Launching mysqlsh
MySQL Shell 8.0.31

Copyright (c) 2016, 2022, Oracle and/or its affiliates.
Oracle is a registered trademark of Oracle Corporation and/or its affiliates.
Other names may be trademarks of their respective owners.

Type '\help' or '\?' for help; '\quit' to exit.
WARNING: Using a password on the command line interface can be insecure.
Creating a session to 'admin@127.0.0.1:9004'
Fetching schema names for auto-completion... Press ^C to stop.
Your MySQL connection id is 38
Server version: 8.0.32-cloud MySQL Enterprise - Cloud
No default schema selected; type \use <schema> to set one.
 MySQL  127.0.0.1:9004 ssl  JS >

## Invoke the script without setting path to mysqlsh
❯ .\Invoke_Mysqlsh_Session.ps1 -BastionId $bastion_ocid -connectionId $conn_ocid
Write-Error: mysqlsh not found
Remove-OpuPortForwardingSessionFull: C:\Users\espenbr\GitHub\oci-powershell-utils\Invoke_Mysqlsh_Session.ps1:103
Line |
 103 |  … dingSessionFull -BastionSessionDescription $bastionSessionDescription
     |                                               ~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Cannot bind argument to parameter 'BastionSessionDescription' because it is null.
Write-Error: Error: Mysqlsh not properly installed

## Invoke script with -TestOnly $true
❯ .\Invoke_Mysqlsh_Session.ps1 -BastionId $bastion_ocid -connectionId $conn_ocid -TestOnly $true
Getting details from connection
Creating ephemeral key pair
Creating Port Forwarding Session to 10.0.1.27:3306
Waiting for creation of bastion session to complete
Creating SSH tunnel
DEBUG: Waiting in 30 secs while you check stuff ...
True
#>

param(
    [Parameter(Mandatory, HelpMessage='OCID of Bastion')]
    [String]$BastionId, 
    [Parameter(Mandatory, HelpMessage='OCID of connection')]
    [String]$ConnectionId,
    [Boolean]$TestOnly=$false
)

## START: generic section
$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location
## END: generic section

try {
    ## START: generic section
    ## check that mandatory sw is installed    
    Test-OpuSshAvailable
    ## END: generic section

    ## Make sure mysqlsh is within reach first
    Test-OpuMysqlshAvailable

    ## Import the modules needed here
    Import-Module OCI.PSModules.Mysql
    Import-Module OCI.PSModules.Databasetools
    Import-Module OCI.PSModules.Secrets

    Out-Host -InputObject "Getting details from connection"

    ## Grab main handle, ensure it is in correct lifecycle state and that it points to a mysql db system
    try {
        $connection = Get-OCIDatabasetoolsconnection -DatabaseToolsconnectionId $connectionId -WaitForLifecycleState Active -WaitIntervalSeconds 0 -ErrorAction Stop
    }
    catch {
        throw "Get-OCIDatabasetoolsconnection: $_"
    }
    if ("Mysqldbsystem" -ne $connection.RelatedResource.EntityType) {
        throw "Connection does not point to a MySQL database system"
    }

    ## Grab mysql db system info based on conn handle, ensure it is in correct lifecycle state
    try {
        $mysqlDbSystem = Get-OCIMysqlDbSystem -DbSystemId $connection.RelatedResource.Identifier  -WaitForLifecycleState Active -WaitIntervalSeconds 0 -ErrorAction Stop
    } 
    catch {
        throw "Get-OCIMysqlDbSystem: $_"
    }

    ## Get secret (read password) from connection handle
    try {
        $secret = Get-OCISecretsSecretBundle -SecretId $connection.UserPassword.SecretId -Stage Current -ErrorAction Stop
    }
    catch {
        throw "Get-OCISecretsSecretBundle: $_"
    }

    ## Assign to local variables for readability
    $userName = $connection.UserName
    $passwordBase64 = $secret.SecretBundleContent.Content
    $targetHost = $mysqlDbSystem.IpAddress
    $targetPort = $mysqlDbSystem.Port
  
    ## START: generic section
    ## Create session and process, get information in custom object -- see below
    ## TODO: return $false if errror, need to throw and catch! 
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort
    $localPort = $bastionSessionDescription.LocalPort
    ## END: generic section
  
    $password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($passwordBase64))

    if ($true -eq $TestOnly) {
        Out-Host -InputObject "DEBUG: Waiting in 30 secs while you check stuff ..."
        Start-Sleep -Seconds 30
        return $true
    }
    
    Out-Host -InputObject "Launching mysqlsh"
    mysqlsh --sql -u $userName -h 127.0.0.1 --port=$localPort --password=$password
}
catch {
    ## What else can we do? 
    Write-Error "Error: $_"
    return $false
}
finally {
    ## START: generic section
    ## To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
    
    ## Request cleanup if session object has been created
    if ($null -ne $bastionSessionDescription) {
        Remove-OpuPortForwardingSessionFull -BastionSessionDescription $bastionSessionDescription
    }

    ## Finally, unload module from memory 
    Set-Location $PSScriptRoot
    Remove-Module oci-powershell-utils
    Pop-Location

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
    ## END: generic section
}
