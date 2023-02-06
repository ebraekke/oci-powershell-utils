

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
## Test that mysqsh is installed is successful.

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
Check if the required sqlcl is installed and available.

.DESCRIPTION
Used by session utils before engaging with the sqlcl. 
Can also be called independently.  

.EXAMPLE
## Test that sqlcl is installed is successful.

Test-OpuSqlclAvailability
True

.EXAMPLE
## Test that Sqlcl is installed that fails.

Test-OpuSshAvailability
Write-Error: sql not found
False
#>
function Test-OpuSqlclAvailable {
    try {
        Test-Executable -ExeName "sql" -ExeArguments "-V"

        return $true
    }
    catch {
        return $false
    }
}


<#
.SYNOPSIS
Removes all traces of previously created "full session", that is Bastion session, SSH process and ephemeral key pair. 

.DESCRIPTION
The SSH process, the ephemeral key pair and then finally teh bastion session are destroyed. 
Process will will continue if a failure happens.
File deletion failures are silent, you need to add debugging to get output.  
Output related to the bastion session deletion will be displayed. 

.PARAMETER BastionSessionDescription

$BastionSessionDescription = [PSCustomObject]@{
    BastionSession = $bastionSession
    SShProcess = $sshProcess
    PrivateKey = $keyFile
    PublicKey = "${keyFile}.pub"
    LocalPort = $localPort
}
 

.EXAMPLE 
## Removing previously created full session
Remove-OpuPortForwardingSessionFull -BastionSessionDescription $full_session

.EXAMPLE 
## Attempting to remove a full session tha thas already been removed. 
Remove_Port_Forwarding_Session_Full.ps1 -BastionSessionDescription $full_session
Write-Error: Error: Error returned by Bastion Service. Http Status Code: 409. ServiceCode: Conflict. OpcRequestId: /6D37DAF3BE84C77C5795641630FEB81F/C8069151DFEDFD9499DD0BBDFC80E109. Message: resource is not allowed to delete with current state
Operation Name: DeleteSession
TimeStamp: 2023-01-25T17:28:17.979Z
Client Version: Oracle-DotNetSDK/51.0.0 (Win32NT/10.0.19044.0; .NET 7.0.0)  Oracle-PowerShell/47.0.0
Request Endpoint: DELETE https://bastion.eu-frankfurt-1.oci.oraclecloud.com/20210331/sessions/ocid1.bastionsession.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaayyi4zkejketqvgs2bzlwirwdoqn5hmvhlsbryelkevxa
For details on this operation's requirements, see https://docs.oracle.com/iaas/api/#/en/bastion/20210331/Session/DeleteSession.
Get more information on a failing request by using the -Verbose or -Debug flags. See https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/powershellconcepts.htm#powershellconcepts_topic_logging
For more information about resolving this error, see https://docs.oracle.com/en-us/iaas/Content/API/References/apierrors.htm#apierrors_409__409_conflict
If you are unable to resolve this Bastion issue, please contact Oracle support and provide them this full error message. 

#>

function Remove-OpuPortForwardingSessionFull {
    param (
        [Parameter(Mandatory,HelpMessage='Full Bastion Session Description Object')]
        $BastionSessionDescription
    )

    ## To Maximize possible clean ups, continue on error
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        Import-Module OCI.PSModules.Bastion

        ## Kill SSH process
        Stop-Process -InputObject $BastionSessionDescription.SshProcess
    
        ## TODO: make this parameter driven in case of debug needs
        ## Delete the ephemeral keys, don't output errors 
        $ErrorActionPreference = 'SilentlyContinue' 
        Remove-Item $BastionSessionDescription.PrivateKey
        Remove-Item $BastionSessionDescription.PublicKey 
        $ErrorActionPreference = "Continue"

        ## Kill Bastion session, with Force, ignore output (it is the work request id)
        Remove-OCIBastionSession -SessionId $BastionSessionDescription.BastionSession.Id -Force | Out-Null
    }

    finally {
        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}

<#
.SYNOPSIS
Create a port forwarding sesssion with OCI Bastion service.
Generate SSH key pair to be used for session.
Create the actual port forwarding SSH process.

Return an object to the caller:

$bastionSessionDescription = [PSCustomObject]@{
    BastionSession = $bastionSession
    SShProcess = $sshProcess
    PrivateKey = $keyFile
    PublicKey = "${keyFile}.pub"
    LocalPort = $localPort
}
        
.DESCRIPTION
Creates a port forwarding session with the OCI Bastion Service and the required SSH port forwarding process.
This combo will allow you to connect through the Bastion service via a local port and to your destination: $TargetHost:$TargetPort   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER TargetHost
IP address of target host. 
   
.PARAMETER TargetPort
Port number at TargetHost to create a session to. 
Defaults to 22.  

.EXAMPLE 
## Creating a forwarding session to the default port
$bastion_session=New-OpuPortForwardingSessionFull -BastionId $bastion_ocid -TargetHost $target_ip
Creating Port Forwarding Session to 10.0.0.251:22
Waiting for creation of bastion session to complete

$bastion_session
BastionSession : Oci.BastionService.Models.Session
SShProcess     : System.Diagnostics.Process (Idle)
PrivateKey     : C:\Users\espenbr\AppData\Local\Temp/bastionkey-2023_01_17_14_43_21-9084
PublicKey      : C:\Users\espenbr\AppData\Local\Temp/bastionkey-2023_01_17_14_43_21-9084.pub
LocalPort      : 9084


Stop-Process -InputObject $bastion_session.SShProcess

Remove-OciBastionSession -SessionId $bastion_session.BastionSession.Id -Force
OpcWorkRequestId
----------------
ocid1.bastionworkrequest.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaai6rzunvyiwtmmvwjslatvglkhynjkdzx2vvwht5gckkq

.EXAMPLE 
## Creating a forwarding session to a mysql port
$bastion_session=New-OpuPortForwardingSessionFull -BastionId $bastion_ocid -TargetHost $target_ip -TargetPort 3306
Creating Port Forwarding Session to 10.0.0.251:3306
Waiting for creation of bastion session to complete

$bastion_session
BastionSession : Oci.BastionService.Models.Session
SShProcess     : System.Diagnostics.Process (Idle)
PrivateKey     : C:\Users\espenbr\AppData\Local\Temp/bastionkey-2023_01_17_14_46_54-9374
PublicKey      : C:\Users\espenbr\AppData\Local\Temp/bastionkey-2023_01_17_14_46_54-9374.pub
LocalPort      : 9374


Stop-Process -InputObject $bastion_session.SShProcess

Remove-OciBastionSession -SessionId $bastion_session.BastionSession.Id -Force
OpcWorkRequestId
----------------
ocid1.bastionworkrequest.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaauz4sperzwv32kjdun4cybqn5ufs6qwnq465vptm6ftpa
#>
function New-OpuPortForwardingSessionFull {
    param (
        [Parameter(Mandatory,HelpMessage='OCID of Bastion')]
        [String]$BastionId, 
        [Parameter(Mandatory,HelpMessage='IP address of target host')]
        [String]$TargetHost,
        [Int32]$TargetPort=22        
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {
        Import-Module OCI.PSModules.Bastion

        $tmpDir = Get-TempDir

        $now = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"
        $localPort = Get-Random -Minimum 9001 -Maximum 9099

        ## Generate ephemeral key pair in $tmpDir.  
        ## name: bastionkey-${now}.{localPort}
        ##
        ## Process will fail if another key with same name exists, in that case -- TODO: decide what to do
        Out-Host -InputObject "Creating ephemeral key pair"
        $keyFile = -join("${tmpDir}/bastionkey-","${now}-${localPort}")
        ssh-keygen -t rsa -b 2048 -f $keyFile -q -N ''
    
        Out-Host -InputObject "Creating Port Forwarding Session to ${TargetHost}:${TargetPort}"

        ## Get Bastion object, use MaxSessionTtlInSeconds
        $bastionService         = Get-OCIBastion -BastionId $BastionId
        $maxSessionTtlInSeconds = $bastionService.MaxSessionTtlInSeconds

        ## Details of target
        $targetResourceDetails                                  = New-Object -TypeName 'Oci.bastionService.Models.CreatePortForwardingSessionTargetResourceDetails'
        $targetResourceDetails.TargetResourcePrivateIpAddress   = $TargetHost    
        $targetResourceDetails.TargetResourcePort               = $TargetPort

        ## Details of keyfile
        $keyDetails                  = New-Object -TypeName 'Oci.bastionService.Models.PublicKeyDetails'
        $keyDetails.PublicKeyContent = Get-Content "${keyFile}.pub"

        ## The actual session, name matches ephemeral key(s)
        $sessionDetails                       = New-Object -TypeName 'Oci.bastionService.Models.CreateSessionDetails'
        $sessionDetails.DisplayName           = -join("BastionSession-${now}-${localPort}")
        $sessionDetails.SessionTtlInSeconds   = $maxSessionTtlInSeconds
        $sessionDetails.BastionId             = $BastionId
        $sessionDetails.KeyType               = "PUB"
        $sessionDetails.TargetResourceDetails = $TargetResourceDetails
        $sessionDetails.KeyDetails            = $keyDetails
    
        $bastionSession = New-OciBastionSession -CreateSessionDetails $sessionDetails
    
        Out-Host -InputObject "Waiting for creation of bastion session to complete"
        $bastionSession = Get-OCIBastionSession -SessionId $bastionSession.Id -WaitForLifecycleState Active, Failed

        ## Create ssh command argument string with relevant parameters
        $sshArgs = $bastionSession.SshMetadata["command"]
        $sshArgs = $sshArgs.replace("ssh",          "") 
        $sshArgs = $sshArgs.replace("<privateKey>", $keyFile)
        $sshArgs = $sshArgs.replace("<localPort>",  $localPort)

        Write-Debug "CONN: ssh ${sshArgs}"
        
        Out-Host -InputObject "Creating SSH tunnel"
        $sshProcess = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -WindowStyle Hidden -PassThru

        ## Create return Object
        $localBastionSession = [PSCustomObject]@{
            BastionSession = $bastionSession
            SShProcess = $sshProcess
            PrivateKey = $keyFile
            PublicKey = "${keyFile}.pub"
            LocalPort = $localPort
        }
        
        $localBastionSession
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

Export-ModuleMember -Function Test-OpuSshAvailable
Export-ModuleMember -Function Test-OpuMysqlshAvailable
Export-ModuleMember -Function Test-OpuSqlclAvailable

Export-ModuleMember -Function Remove-OpuPortForwardingSessionFull
Export-ModuleMember -Function New-OpuPortForwardingSessionFull
