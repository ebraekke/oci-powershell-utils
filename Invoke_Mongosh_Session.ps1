<#
.SYNOPSIS
Invoke  an mongosh sesssion with a target host accessible through the OCI Bastion service.

.DESCRIPTION
Using the Bastion service and tunneling a mongosh session will be invoked on the target DB system. 
A ephemeral key pair for the Bastion session is created (and later destroyed). 
This combo will allow you to "connect" through the Bastion service via a local port and to your destination: $TargetHost:$TargetPort   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER ConnectionId
OCID of connection containing the details about the database system. 

.PARAMETER TestOnly
Set to $true to perform setup and teardown, but skip the start of sqlcl.
Incurs a 30 second wait. 

.EXAMPLE 
## Successfully invoking script and connecting to DB via bastion

## Invoking script without setting path to sqlcl (sql)

## Invoking script with -TestOnly $true

## Invoking script and getting errors and you do not know why (tip: go off VPN)

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
    ## Make sure mongosh is within reach first
    Test-OpuMongoshAvailable

    ## Grab connection
    $adbConnectionDescription = New-OpuAdbConnection -ConnectionId $ConnectionId

    ## Assign to local variables for readability, note we are using the mongo port of 27017
    $userName = $adbConnectionDescription.UserName
    $passwordBase64 = $adbConnectionDescription.PasswordBase64
    $targetHost = $adbConnectionDescription.TargetHost
    $targetPort = "27017"

    if ($false -eq $adbConnectionDescription.IsMongoApiEnabled) {
        throw "MongoApi is not enabled"
    }
  
    ## Create session and process, ask for dyn local port, get information in custom object -- used in teardown below
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort -LocalPort 0
    $localPort = $bastionSessionDescription.LocalPort
  
    $password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($passwordBase64))

    if ($true -eq $TestOnly) {
        Out-Host -InputObject "DEBUG: Waiting in 30 secs while you check stuff ..."
        Start-Sleep -Seconds 30
        return $true
    }
  
    $urlEncodedPassword = [System.Web.HttpUtility]::UrlEncode($password)

    ## Stitch together a connection url for mongosh
    ## Use localhost, 127.0.0.1 will result in "MongoNetworkError: Client network socket disconnected before secure TLS connection was established"
    $connUrl = "mongodb://${userName}:${urlEncodedPassword}@localhost:${localPort}/${userName}" + '?authMechanism=PLAIN&authSource=$external&ssl=true&retryWrites=false&loadBalanced=true'

    Out-Host -InputObject "Launching mongosh"
    Out-Host -InputObject "mongosh --tls --tlsAllowInvalidCertificates '$connUrl'"

    ## TODO: Resolve challenge with quoting of parameter string
    mongosh --tls --tlsAllowInvalidCertificates `"$connUrl`"

    if ($true) {
        Out-Host -InputObject "DEBUG: Waiting in 60 secs while you check stuff ..."
        Start-Sleep -Seconds 60    
    }
}
catch {
    ## What else can we do?
    Write-Error "Invoke_Mongosh_Session.ps1: $_"
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
