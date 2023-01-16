

<#
Internal functions
#>

function Get-TempDir {
    ## Windows only for now() 
    if ($IsWindows) {
        return $env:TEMP
    } else {
        throw "Currently no support for *nix platforms"
    }
}

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
TargetResourceDetails    : Oci.bastionService.Models.PortForwardingSessionTargetResourceDetails
SshMetadata              : {[command, ssh -i <privateKey> -N -L <localPort>:10.0.0.251:22 -p 22 ocid1.bastionsession.oc1.eu-frankfur
                           t-1.amaaaaaa3gkdkiaad3vwrwp2e573xnifznjv6v6oyf43echdqtwbry4m4oea@host.bastion.eu-frankfurt-1.oci.oraclecl
                           oud.com]}
KeyType                  : Pub
KeyDetails               : Oci.bastionService.Models.PublicKeyDetails
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
TargetResourceDetails    : Oci.bastionService.Models.PortForwardingSessionTargetResourceDetails
SshMetadata              : {[command, ssh -i <privateKey> -N -L <localPort>:10.0.0.251:3306 -p 22 ocid1.bastionsession.oc1.eu-frankf
                           urt-1.amaaaaaa3gkdkiaa7um7otneje5x6qfsjtsljeq2lhofkvyacdceytlmlnda@host.bastion.eu-frankfurt-1.oci.oracle
                           cloud.com]}
KeyType                  : Pub
KeyDetails               : Oci.bastionService.Models.PublicKeyDetails
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
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {

        Import-Module OCI.PSModules.Bastion

        ## Make sure mandatory input at least is a proper file  
        if ($false -eq (Test-Path $PublicKeyFile -PathType Leaf)) {
            Throw "${PublicKeyFile} is not a valid file"        
        }
    
        Out-Host -InputObject "Creating Port Forwarding Session"
        Out-Host -InputObject "Using port: $Port"

        ## Get Bastion object, use MaxSessionTtlInSeconds
        $bastionService         = Get-OCIBastion -BastionId $BastionId
        $maxSessionTtlInSeconds = $bastionService.MaxSessionTtlInSeconds

        ## Details of target
        $targetResourceDetails                                  = New-Object -TypeName 'Oci.bastionService.Models.CreatePortForwardingSessionTargetResourceDetails'
        $targetResourceDetails.TargetResourcePrivateIpAddress   = $TargetHost    
        $targetResourceDetails.TargetResourcePort               = $Port

        ## Details of keyfile
        $keyDetails                  = New-Object -TypeName 'Oci.bastionService.Models.PublicKeyDetails'
        $keyDetails.PublicKeyContent = Get-Content $PublicKeyFile

        ## The actual session
        $sessionDetails                       = New-Object -TypeName 'Oci.bastionService.Models.CreateSessionDetails'
        $sessionDetails.DisplayName           = -join("BastionSession-", (Get-Random))
        $sessionDetails.SessionTtlInSeconds   = $maxSessionTtlInSeconds
        $sessionDetails.BastionId             = $BastionId
        $sessionDetails.KeyType               = "PUB"
        $sessionDetails.TargetResourceDetails = $TargetResourceDetails
        $sessionDetails.KeyDetails            = $keyDetails
    
        $bastionSession = New-OciBastionSession -CreateSessionDetails $sessionDetails
    
        Out-Host -InputObject "Waiting for creation of bastion session to complete"
        $bastionSession = Get-OCIBastionSession -SessionId $bastionSession.Id -WaitForLifecycleState Active, Failed
    
        $bastionSession
    } catch {
        ## What else can we do? 
        Write-Error "Error: $_"
        return $false
    } finally {
        ## To Maximize possible clean ups, continue on error 
        $ErrorActionPreference = "Continue"
        
        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}


<#
.SYNOPSIS
Create an interactive SSH sesssion with OCI Bastion service based on a (local) private SSH key.

.DESCRIPTION
Creates a port forwarded SSH session with the OCI Bastion Service.
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER TargetHost
IP address of target host. 
 
.PARAMETER SshKey
Path to private ssh key to be used for authentication in the SSH session created by the Bastion service.
  
.PARAMETER Port
Port number at TargetHost to create a session to. 
Defaults to 22.  

.PARAMETER OsUSer
Ooperating System user at target. 
Defaults to opc.  

.EXAMPLE
## Proper invocation with user specified 

New-OpuSshSession -BastionId $bastion_ocid -TargetHost $target_ip -SshKey C:\Users\espenbr\tmp\id_rsa_fagdag -OsUser ubuntu
Creating Port Forwarding Session
Using port: 22
Waiting for creation of bastion session to complete
Welcome to Ubuntu 22.04.1 LTS (GNU/Linux 5.15.0-1026-oracle x86_64)

... 

Last login: Fri Jan 13 15:30:57 2023 from 10.0.0.49
ubuntu@controller:~$

.EXAMPLE 
## Invoked without a file as $SshKey

New-OpuSshSession -BastionId $bastion_ocid -TargetHost $target_ip -SshKey C:\Users\espenbr\.ssh\id_rsaX 
New-OpuSshSession: Error: C:\Users\espenbr\.ssh\id_rsaX is not a valid file

.EXAMPLE 
## Invoked without a valid ssh private key file as $SshKey

New-OpuSshSession -BastionId $bastion_ocid -TargetHost $target_ip -SshKey C:\Users\espenbr\tmp\id_rsa_fagdag.tull 
New-OpuSshSession: Error: C:\Users\espenbr\tmp\id_rsa_fagdag.tull is not a valid private ssh key
#>
function New-OpuSshSessionByKey {
    param (
        [Parameter(Mandatory,HelpMessage='OCID of bastion')]
        [String]$BastionId, 
        [Parameter(Mandatory,HelpMessage='IP address of target host')]
        [String]$TargetHost,
        [Parameter(Mandatory,HelpMessage='Private SSH Key file for auth')]
        [String]$SshKey,
        [Int32]$Port=22,
        [String]$OsUser="opc"
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {
        ## Make sure mandatory input at least is a proper file  
        if ($false -eq (Test-Path $SshKey -PathType Leaf)) {
            Throw "${SshKey} is not a valid file"        
        }

        if ($false -eq (Test-OpuSshAvailable)) {
            Throw "SSH not properly installed"
        }

        # use ssh-keygen to print public part of key
        # ssh-keygen on Windows does not like "~", so convert to "$HOME"
        ssh-keygen -y -f ($sshKey.Replace("~", $HOME)) | Out-Null
        if ($false -eq $?) {
            throw "$SshKey is not a valid private ssh key"
        }

        Import-Module OCI.PSModules.Bastion

        $tmpDir = Get-TempDir

        ## Range 2223 to 2299
        $localPort = Get-Random -Minimum 2223 -Maximum 2299

        ## Generate ephemeral key pair in $tmpDir.  
        ## name: bastionkey-yyyy_dd_MM_HH_mm_ss-$localPort
        ##
        ## Process will fail if another key with same name exists, in that case -- do not delete key file(s) on exit
        $deleteKeyOnExit = $false
        $keyFile = -join("${tmpDir}/bastionkey-",(Get-Date -Format "yyyy_MM_dd_HH_mm_ss"),"-${LocalPort}")
        ssh-keygen -t rsa -b 2048 -f $keyFile -q -N ''
        $deleteKeyOnExit = $true

        $bastionSession = New-OpuPortForwardingSession -BastionId $BastionId -TargetHost $TargetHost -PublicKeyFile (-join($keyFile, ".pub")) -Port $Port

        ## Create ssh command argument string with relevant parameters
        $sshArgs = $bastionSession.SshMetadata["command"]
        $sshArgs = $sshArgs.replace("ssh",          "") 
        $sshArgs = $sshArgs.replace("<privateKey>", $keyFile)
        $sshArgs = $sshArgs.replace("<localPort>",  $localPort)

        Write-Debug "CONN: ssh ${sshArgs}"
        $sshProcess = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -WindowStyle Hidden -PassThru
     
        ## -o "NoHostAuthenticationForLocalhost yes" ensures no verification of locally forwarded port and localhost combos 
        ssh -o "NoHostAuthenticationForLocalhost yes" -p $localPort 127.0.0.1 -l $OsUser -i $sshKey 

    }
    catch {
        ## What else can we do? 
        Write-Error "Error: $_"
        return $false
    }
    finally {
        ## To Maximize possible clean ups, continue on error 
        $ErrorActionPreference = "Continue"
        
        # Kill SSH process
        Stop-Process -InputObject $sshProcess

        ## Delete ephemeral key pair if all went well
        if ($true -eq $deleteKeyOnExit) {
            Remove-Item $keyFile
            Remove-item (-join($keyFile, ".pub"))    
        } 
    
        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}

<#
.SYNOPSIS
Create a port forwarding sesssion with OCI Bastion service based on an SSH  key stored in the OCI key vault as a secret.

.DESCRIPTION
Creates a port forwarded SSH session with the OCI Bastion Service.
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER TargetHost
IP address of target host. 
 
.PARAMETER SecretId
OCID of teh secret containing the private ssh key to be used for authentication in the SSH session created by the Bastion service.
  
.PARAMETER Port
Port number at TargetHost to create a session to. 
Defaults to 22.  

.PARAMETER OsUSer
Ooperating System user at target. 
Defaults to opc.  

.EXAMPLE
## Session created with different Operating System User than default. 

New-OpuSshSessionBySecret -BastionId $bastion_ocid -TargetHost $target_ip -SecretID $secret_ocid -OsUser ubuntu
Getting Secret from Vault
Creating Port Forwarding Session
Using port: 22
Waiting for creation of bastion session to complete
Welcome to Ubuntu 22.04.1 LTS (GNU/Linux 5.15.0-1026-oracle x86_64)

...

Last login: Fri Jan 13 17:00:28 2023 from 10.0.0.49
#>
function New-OpuSshSessionBySecret {
    param (
        [Parameter(Mandatory,HelpMessage='OCID of bastion')]
        [String]$BastionId, 
        [Parameter(Mandatory,HelpMessage='IP address of target host')]
        [String]$TargetHost,
        [Parameter(Mandatory,HelpMessage='OCID of secret containing SSH Key file for auth')]
        [String]$SecretId,
        [Int32]$Port=22,
        [String]$OsUser="opc"
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {

        $tmpDir = Get-TempDir

        Import-Module OCI.PSModules.Secrets

        Out-Host -InputObject "Getting Secret from Vault"
        $secretBase64 = (Get-OCISecretsSecretBundle -SecretId $SecretId).SecretBundleContent.Content
        $secret = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($secretBase64))


        ## Range 4001 to 4099
        $random = Get-Random -Minimum 4001 -Maximum 4099

        ## Create ephemeral key pair in $tmpDir.  
        ## name: secretkey-yyyy_dd_MM_HH_mm_ss-$random
        ##
        ## Process will fail if another key with same name exists, in that case -- do not delete key file(s) on exit
        $deleteKeyOnExit = $false
        $sshKeyCopy = -join("${tmpDir}/secretkey-",(Get-Date -Format "yyyy_MM_dd_HH_mm_ss"),"-${random}")
        New-Item -ItemType "file" -Path $sshKeyCopy -Value $secret | Out-Null
        $deleteKeyOnExit = $true
        
        ## use ssh-keygen to creat public part of key
        ## Will not use, but fail here means something is wrong
        ssh-keygen -y -f $sshKeyCopy > "${sshKeyCopy}.pub" | Out-Null
        if ($false -eq $?) {
            Throw "SSH Key in secret is not valid"
        }


<#
        Out-Host -InputObject "Sleep for 30secs whil we verify files ..."
        Start-Sleep -Seconds 30
#>

        New-OpuSshSessionByKey -BastionId $BastionId -TargetHost $TargetHost -SshKey $sshKeyCopy -Port $Port -OsUser $OsUser
        
    }
    catch {
        ## What else can we do? 
        Write-Error "Error: $_"
        return $false
    }
    finally {
        ## To Maximize possible clean ups, continue on error 
        $ErrorActionPreference = "Continue"

        ## Delete ephemeral key pair if all went well
        if ($true -eq $deleteKeyOnExit) {
            Remove-Item $sshKeyCopy
            Remove-item (-join($sshKeyCopy, ".pub"))    
        } 

        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}


Export-ModuleMember -Function Test-OpuSshAvailable
Export-ModuleMember -Function Test-OpuMysqlshAvailable
Export-ModuleMember -Function New-OpuPortForwardingSession
Export-ModuleMember -Function New-OpuSshSessionByKey
Export-ModuleMember -Function New-OpuSshSessionBySecret
