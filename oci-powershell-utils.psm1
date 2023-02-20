

<#
Internal functions
#>

function Get-TempDir {
    ## Windows only for now() 
    if ($IsWindows) {
        return $env:TEMP
    } 
    elseif ($IsLinux) {
        return "/tmp"
    } 
    else {
        throw "Get-TempDir: Currently no support for Mac"
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
        Throw "TestExecutable: -ExeName must be provided"
    }
    try {
        ## check that cmd exists
        Get-Command $ExeName -ErrorAction Stop | Out-Null
    }
    catch {
        throw "${ExeName} not found"
    }
}

<#
.SYNOPSIS
Check if the required ssh tools (ssh and ssh-keygen) are installed and available.

.DESCRIPTION
Used by port forwarding utils before engaging with the ssh tools. 
Can also be called independently.  

.EXAMPLE
## Test that ssh is installed is successful. (no output)

Test-OpuSshAvailability


.EXAMPLE
## Test that ssh tools are installed that fails because of no ssh.

Test-OpuSshAvailability
Exception: ssh not found

.EXAMPLE
## Test that ssh tools are installed that fails because of no ssh-keygen.

Test-OpuSshAvailability
Exception: ssh-keygen not found
#>
function Test-OpuSshAvailable {
    Test-Executable -ExeName "ssh"
    Test-Executable -ExeName "ssh-keygen"        
}

<#
.SYNOPSIS
Check if the required mysqlsh is installed and available.

.DESCRIPTION
Used by session utils before engaging with the mysqlsh. 
Can also be called independently.  

.EXAMPLE
## Test that mysqsh is installed is successful. (no response) 

Test-OpuMysqlshAvailability

.EXAMPLE
## Test that mysqlsh is installed that fails.

Test-OpuSshAvailability
Exception: mysqlsh not found
#>
function Test-OpuMysqlshAvailable {
    Test-Executable -ExeName "mysqlsh"
}

<#
.SYNOPSIS
Check if the required sqlcl is installed and available.

.DESCRIPTION
Used by session utils before engaging with the sqlcl. 
Can also be called independently.  

.EXAMPLE
## Test that sqlcl is installed is successful (no response)
Test-OpuSqlclAvailability

.EXAMPLE
## Test that Sqlcl is installed that fails.

Test-OpuSqlclAvailability
Exception: sql not found
#>
function Test-OpuSqlclAvailable {
    Test-Executable -ExeName "sql"
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
Remove-OpuPortForwardingSessionFull -BastionSessionDescription $full_session
Line |
  54 |      Remove-OpuPortForwardingSessionFull -BastionSessionDescription $B …
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Remove-OpuPortForwardingSessionFull: Error returned by Bastion Service. Http Status Code: 409. ServiceCode: Conflict.
     | OpcRequestId: /80B4D7579823F8E5A114897FB5FA2700/E9666BAA4D1FE96AD3DBD003CC8A9D6D. Message: resource is not allowed to delete
     | with current state Operation Name: DeleteSession TimeStamp: 2023-02-14T13:10:02.584Z Client Version: Oracle-DotNetSDK/51.3.0
     | (Win32NT/10.0.19044.0; .NET 7.0.2)  Oracle-PowerShell/47.3.0  Request Endpoint: DELETE
     | https://bastion.eu-frankfurt-1.oci.oraclecloud.com/20210331/sessions/ocid1.bastionsession.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaacko5aymp2ztq5rm2lstumpzimqn5t7kiszv2e76w5ghq For details on this operation's requirements, see https://docs.oracle.com/iaas/api/#/en/bastion/20210331/Session/DeleteSession. Get more information on a failing request by using the -Verbose or -Debug flags. See https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/powershellconcepts.htm#powershellconcepts_topic_logging For more information about resolving this error, see https://docs.oracle.com/en-us/iaas/Content/API/References/apierrors.htm#apierrors_409__409_conflict If you are unable to resolve this Bastion issue, please contact Oracle support and provide them this full error message.

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
        Stop-Process -InputObject $BastionSessionDescription.SshProcess -ErrorAction SilentlyContinue
    
        ## TODO: make this parameter driven in case of debug needs
        ## Delete the ephemeral keys, don't output errors 
        $ErrorActionPreference = 'SilentlyContinue' 
        Remove-Item $BastionSessionDescription.PrivateKey -ErrorAction SilentlyContinue
        Remove-Item $BastionSessionDescription.PublicKey -ErrorAction SilentlyContinue
        $ErrorActionPreference = "Continue"

        ## Kill Bastion session, with Force, ignore output and error (it is the work request id)
        try {
            Remove-OCIBastionSession -SessionId $BastionSessionDescription.BastionSession.Id -Force -ErrorAction Ignore | Out-Null            
        }
        catch {
            Write-Error "Remove-OpuPortForwardingSessionFull: $_"
        }
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

.PARAMETER LocalPort
Local port to use for port forwarding. 
Defaults to 0, means that it will be randomly assigned.
Error thrown if requesting a port number lower than 1024.  

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
        [Int32]$TargetPort=22,
        [Parameter(HelpMessage='Use this local port, 0 means assign')]
        [Int32]$LocalPort=0
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {
        ## check that mandatory sw is installed    
        Test-OpuSshAvailable

        Import-Module OCI.PSModules.Bastion

        $tmpDir = Get-TempDir

        $now = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"

        ## Assign or verify LocalPort 
        if (0 -eq $LocalPort) {
            $LocalPort = Get-Random -Minimum 9001 -Maximum 9099
        } elseif ($LocalPort -lt 1024) {
            throw "LocalPort cannot be less than 1024!"
        }

        ## Generate ephemeral key pair in $tmpDir.  
        ## name: bastionkey-${now}.{localPort}
        ##
        ## Process will fail if another key with same name exists, in that case -- TODO: decide what to do
        Out-Host -InputObject "Creating ephemeral key pair"
        $keyFile = -join("${tmpDir}/bastionkey-","${now}-${localPort}")

        try {
            if ($IsWindows) {
                ssh-keygen -t rsa -b 2048 -f $keyFile -q -N '' 
            } elseif ($IsLinux) {
                ssh-keygen -t rsa -b 2048 -f $keyFile -q -N '""' 
            } else {
                throw "Platform not supported ... how did you get here?"
            }
        }
        catch {
            throw "ssh-keygen: $_"
        }
    
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
    
        try {
            $bastionSession = New-OciBastionSession -CreateSessionDetails $sessionDetails -ErrorAction Stop
        }
        catch {
            throw "New-OciBastionSession: $_"
        }
    
        Out-Host -InputObject "Waiting for creation of bastion session to complete"
        try {
            $bastionSession = Get-OCIBastionSession -SessionId $bastionSession.Id -WaitForLifecycleState Active, Failed -ErrorAction Stop 
        }
        catch {
            throw "Get-OCIBastionSession: $_"
        }

        ## Create ssh command argument string with relevant parameters
        $sshArgs = $bastionSession.SshMetadata["command"]
        $sshArgs = $sshArgs.replace("ssh",          "-4")    ## avoid "bind: Cannot assign requested address" 
        $sshArgs = $sshArgs.replace("<privateKey>", $keyFile)
        $sshArgs = $sshArgs.replace("<localPort>",  $localPort)

        Write-Debug "CONN: ssh ${sshArgs}"
        
        Out-Host -InputObject "Creating SSH tunnel"
        try {
            if ($IsWindows) {
                $sshProcess = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -WindowStyle Hidden -PassThru -ErrorAction Stop
            } elseif ($IsLinux) {
                $sshProcess = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -PassThru -ErrorAction Stop
            }
        }
        catch {
            throw "Start-Process: $_"
        }

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
        ## Pass exception on back
        throw "New-OpuPortForwardingSessionFull: $_"
    } finally {
        ## To Maximize possible clean ups, continue on error 
        $ErrorActionPreference = "Continue"
        
        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}

<#
return:

        $localMysqlConnection = [PSCustomObject]@{
            UserName = $connection.UserName
            PasswordBase64 = $secret.SecretBundleContent.Content
            TargetHost = $mysqlDbSystem.IpAddress
            TargetPort = $mysqlDbSystem.Port
            LocalPort = $LocalPort
        }


#>
function New-OpuMysqlConnection {
    param (
        [Parameter(Mandatory, HelpMessage='OCID of connection')]
        [String]$ConnectionId,
        [Parameter(HelpMessage='Use this local port, 0 means assign')]
        [Int32]$LocalPort=0
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {
        ## Make sure mysqlsh is within reach first
        Test-OpuMysqlshAvailable

        ## Import the modules needed here
        Import-Module OCI.PSModules.Mysql
        Import-Module OCI.PSModules.Databasetools
        Import-Module OCI.PSModules.Secrets

        ## Assign or verify LocalPort 
        if (0 -eq $LocalPort) {
            $LocalPort = Get-Random -Minimum 9001 -Maximum 9099
        } elseif ($LocalPort -lt 1024) {
            throw "LocalPort cannot be less than 1024!"
        }

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
    
        ## Create return Object
        $localMysqlConnection = [PSCustomObject]@{
            UserName = $connection.UserName
            PasswordBase64 = $secret.SecretBundleContent.Content
            TargetHost = $mysqlDbSystem.IpAddress
            TargetPort = $mysqlDbSystem.Port
            LocalPort = $LocalPort
        }

        $localMysqlConnection
 
    } catch {
        ## Pass exception on back
        throw "New-OpuMysqlConnection: $_"
    } finally {
        ## To Maximize possible clean ups, continue on error 
        $ErrorActionPreference = "Continue"
    
        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}

function Read-OpuBase64String {
    param (
        [Parameter(Mandatory, HelpMessage='BAse64 encoded string')]
        [String]$Base64String
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {
    	[Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($conn.PasswordBase64)) 
    } catch {
        ## Pass exception on back
        throw "Read-OpuBase64String: $_"
    } 
    finally {
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
Export-ModuleMember -Function New-OpuMysqlConnection

Export-ModuleMember -Function Read-OpuBase64String
