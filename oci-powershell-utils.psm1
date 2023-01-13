

<#
Internal functions
#>

function Test-Executable {
    param(
        ## Name of executable to test
        [String]$ExeName, 
        ## Argument list to use
        [String]$ExeArguments
    )

    if ($null -eq $ExeName) {
        $myError = "ExeName must be provided"
        Write-Debug $myError
        Throw $myError
    }
    if ($null -eq $ExeArguments) {
        $myError = "ExeArguments must be provided"
        Write-Debug $myError
        Throw $myError
    }

    try {
        # run process 
        Start-Process -FilePath $ExeName -ArgumentList $ExeArguments -WindowStyle Hidden 
    }
    catch {
        $myError = "${ExeName} not found"
        Write-Error $myError
        throw $myError
    }
}

<#
Exported functions
Al with names like <Verb>-OpuXX
#>

<#
.SYNOPSIS
Check if the required ssh tools (ssh and ssh-keygen) are installed and available.

.DESCRIPTION
Used by port forwarding utils before engaging with the ssh tools. 
Can also be called independently.  

.EXAMPLE
## Test that ssh is installed is successful.

Test-OpuSshAvailability
True

.EXAMPLE
## Test that ssh tools are installed that fails because of no ssh.

Test-OpuSshAvailability
Write-Error: ssh not found
False

.EXAMPLE
## Test that ssh tools are installed that fails because of no ssh-keygen.

Test-OpuSshAvailability
Write-Error: ssh-keygen not found
False
#>
function Test-OpuSshAvailable {
    try {
        Test-Executable -ExeName "ssh" -ExeArguments "--help"
        Test-Executable -ExeName "ssh-keygen" -ExeArguments "--help"
        
        Return $true
    }
    catch {
        return $false
    }    
}

<#
.SYNOPSIS
Check if the required mysqlsh is installed and available.

.DESCRIPTION
Used by session utils before engaging with the mysqlsh. 
Can also be called independently.  

.EXAMPLE
## Test that ssh is installed is successful.

Test-OpuMysqlshAvailability
True

.EXAMPLE
## Test that mysqlsh is installed that fails.

Test-OpuSshAvailability
Write-Error: mysqlsh not found
False
#>
function Test-OpuMysqlshAvailable {
    try {
        Test-Executable -ExeName "mysqlsh" -ExeArguments "--help"

        return $true
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
Create a port forwarding sesssion with OCI Bastion service.
Return the session object to the caller. 

.DESCRIPTION
Creates a port forwarding session with the OCI Bastion Service.
This session will alow you to "ssh" through the Bastion service via a local port and to your destination: $TargetHost:$Port   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER TargetHost
IP address of target host. 
 
.PARAMETER PublicKeyFile
Path to public ssh key to be used for authentication in the SSH session created by the Bastion service.
  
.PARAMETER Port
Port number at TargetHost to create a session to. 
Defaults to 22.  

.EXAMPLE 
## Creating a forwarding session to the default port

New-OpuPortForwardingSession -BastionId $bastion_ocid -TargetHost $target_ip -PublicKeyFile C:\Users\espenbr\.ssh\id_rsa.pub
Creating Port Forwarding Session
Using port: 22
Waiting for creation of bastion session to complete
  
Id                       : ocid1.bastionsession.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaad3vwrwp2e573xnifznjv6v6oyf43echdqtwbry4m4oea
DisplayName              : BastionSession-405066102
BastionId                : ocid1.bastion.oc1.eu-frankfurt-1.SCRAMBLED
BastionName              : BastionFraTest
BastionUserName          : ocid1.bastionsession.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaad3vwrwp2e573xnifznjv6v6oyf43echdqtwbry4m4oea
TargetResourceDetails    : Oci.BastionService.Models.PortForwardingSessionTargetResourceDetails
SshMetadata              : {[command, ssh -i <privateKey> -N -L <localPort>:10.0.0.251:22 -p 22 ocid1.bastionsession.oc1.eu-frankfur
                           t-1.amaaaaaa3gkdkiaad3vwrwp2e573xnifznjv6v6oyf43echdqtwbry4m4oea@host.bastion.eu-frankfurt-1.oci.oraclecl
                           oud.com]}
KeyType                  : Pub
KeyDetails               : Oci.BastionService.Models.PublicKeyDetails
BastionPublicHostKeyInfo :
TimeCreated              : 13.01.2023 13:41:24
TimeUpdated              : 13.01.2023 13:41:31
LifecycleState           : Active
LifecycleDetails         :
SessionTtlInSeconds      : 10800

.EXAMPLE 
## Creating a forwarding session to a mysql port
New-OpuPortForwardingSession -BastionId $bastion_ocid -TargetHost $target_ip -PublicKeyFile C:\Users\espenbr\.ssh\id_rsa.pub -Port 3306
Creating Port Forwarding Session
Using port: 3306

Id                       : ocid1.bastionsession.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaa7um7otneje5x6qfsjtsljeq2lhofkvyacdceytlmlnda
DisplayName              : BastionSession-1367382904
BastionId                : ocid1.bastion.oc1.eu-frankfurt-1.SCRAMBLED
BastionName              : BastionFraTest
BastionUserName          : ocid1.bastionsession.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaa7um7otneje5x6qfsjtsljeq2lhofkvyacdceytlmlnda
TargetResourceDetails    : Oci.BastionService.Models.PortForwardingSessionTargetResourceDetails
SshMetadata              : {[command, ssh -i <privateKey> -N -L <localPort>:10.0.0.251:3306 -p 22 ocid1.bastionsession.oc1.eu-frankf
                           urt-1.amaaaaaa3gkdkiaa7um7otneje5x6qfsjtsljeq2lhofkvyacdceytlmlnda@host.bastion.eu-frankfurt-1.oci.oracle
                           cloud.com]}
KeyType                  : Pub
KeyDetails               : Oci.BastionService.Models.PublicKeyDetails
BastionPublicHostKeyInfo :
TimeCreated              : 13.01.2023 14:09:00
TimeUpdated              : 13.01.2023 14:09:03
LifecycleState           : Active
LifecycleDetails         :
SessionTtlInSeconds      : 10800  
#>
function New-OpuPortForwardingSession {
    param (
        [Parameter(Mandatory,HelpMessage='OCID of bastion')]
        [String]$BastionId, 
        [Parameter(Mandatory,HelpMessage='IP address of target host')]
        [String]$TargetHost,
        [Parameter(Mandatory,HelpMessage='Public Key file for SSH auth')]
        [String]$PublicKeyFile,
        [Int32]$Port=22
    )

    ## TODO: Clean up internal variable names from PascalCase to camelCase

    $UserErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {

        ## Import the modules
        Import-Module OCI.PSModules.Bastion

        ## Make sure mandatory input at least is a proper file  
        if ($false -eq (Test-Path $PublicKeyFile -PathType Leaf)) {
            Throw "${PublicKeyFile} is not a valid file"        
        }
    
        Write-Output "Creating Port Forwarding Session"
        Write-Output "Using port: $Port"

        ## Get Bastion object, use MaxSessionTtlInSeconds
        $BastionService         = Get-OCIBastion -BastionId $BastionId
        $MaxSessionTtlInSeconds = $BastionService.MaxSessionTtlInSeconds

        ## Details of target
        $TargetResourceDetails                                  = New-Object -TypeName 'Oci.BastionService.Models.CreatePortForwardingSessionTargetResourceDetails'
        $TargetResourceDetails.TargetResourcePrivateIpAddress   = $TargetHost    

        ## Generic for both models
        $TargetResourceDetails.TargetResourcePort               = $Port

        ## Details of keyfile
        $KeyDetails                  = New-Object -TypeName 'Oci.BastionService.Models.PublicKeyDetails'
        $K                           = Get-Content $PublicKeyFile
        $KeyDetails.PublicKeyContent = $K

        ## The actual session
        $SessionDetails                       = New-Object -TypeName 'Oci.BastionService.Models.CreateSessionDetails'
        $SessionDetails.DisplayName           = -join("BastionSession-", (Get-Random))
        $SessionDetails.SessionTtlInSeconds   = $MaxSessionTtlInSeconds
        $SessionDetails.BastionId             = $BastionId
        $SessionDetails.KeyType               = "PUB"
        $SessionDetails.TargetResourceDetails = $TargetResourceDetails
        $SessionDetails.KeyDetails            = $KeyDetails
    
        $BastionSession = New-OciBastionSession -CreateSessionDetails $SessionDetails
    
        Write-Output "Waiting for creation of bastion session to complete"
        $BastionSession = Get-OCIBastionSession -SessionId $BastionSession.Id -WaitForLifecycleState Active, Failed
    
        $BastionSession
    } catch {
        ## What else can we do? 
        Write-Error "Error: $_"
    } finally {
        ## To Maximize possible clean ups, continue on error 
        $ErrorActionPreference = "Continue"
        
        ## Done, restore settings
        $ErrorActionPreference = $UserErrorActionPreference
    }
}

Export-ModuleMember -Function Test-OpuSshAvailable
Export-ModuleMember -Function Test-OpuMysqlshAvailable
Export-ModuleMember -Function New-OpuPortForwardingSession
