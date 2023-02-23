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

.PARAMETER CmdAsVerbose
Set to $true to perform current steps, which includes printing URL. 
$false is default and causes process to stop.

.EXAMPLE 
## Successfully invoking script and connecting to DB via bastion

## Invoking script without setting path to sqlcl (sql)

## Invoking script and getting errors and you do not know why (tip: go off VPN)

#>

param(
    [Parameter(Mandatory, HelpMessage='OCID of Bastion')]
    [String]$BastionId, 
    [Parameter(Mandatory, HelpMessage='OCID of connection')]
    [String]$ConnectionId,
    [Parameter(HelpMessage='Run mongosh in verbose mode')]
    [bool]$CmdAsVerbose=$false
)

## START: generic section
$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location
## END: generic section

try {
    if ($false -eq $ForceOutput) {
        Out-Host -InputObject "ForceOutput must be true, exiting ..."
        return $false
    }
  
    ## Make sure mongosh is within reach first
    Test-OpuMongoshAvailable

    ## Grab connection
    $adbConnectionDescription = New-OpuAdbConnection -ConnectionId $ConnectionId -AsMongoDbApi $true

    ## Assign to local variables for readability, port magic handled in cmdlet
    $userName = $adbConnectionDescription.UserName
    $passwordBase64 = $adbConnectionDescription.PasswordBase64
    $targetHost = $adbConnectionDescription.TargetHost
    $targetPort = $adbConnectionDescription.TargetPort
  
    ## Create session and process, ask for dyn local port, get information in custom object -- used in teardown below
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort -LocalPort 0
    $localPort = $bastionSessionDescription.LocalPort
  
    $password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($passwordBase64))
    $urlEncodedPassword = [System.Web.HttpUtility]::UrlEncode($password)

    ## Stitch together a connection url for mongosh
    ## Use localhost, 127.0.0.1 will result in "MongoNetworkError: Client network socket disconnected before secure TLS connection was established"
    $hostUrl = "mongodb://${userName}:${urlEncodedPassword}@localhost:${localPort}/${userName}"
    $paraUrl = '?authMechanism=PLAIN&authSource=$external&ssl=true&retryWrites=false&loadBalanced=true'

    $connUrl = "${hostUrl}${paraUrl}"
    Out-Host -InputObject "Launching mongosh"
 
    if ($true -eq $CmdAsVerbose) {
        mongosh --verbose --tls --tlsAllowInvalidCertificates "${connUrl}"
    }
    else {
        mongosh --tls --tlsAllowInvalidCertificates "${connUrl}"
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
