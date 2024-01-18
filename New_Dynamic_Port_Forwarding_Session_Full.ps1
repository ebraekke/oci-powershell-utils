<#
TODO:Fix. 

.SYNOPSIS
Create a dynamic port forwarding sesssion with OCI Bastion service.
Generate SSH key pair to be used for session.
Create the actual proxy endpoint .

Return an object to the caller:

$bastionSessionDescription = [PSCustomObject]@{
    BastionSession = $bastionSession
    SShProcess = $sshProcess
    LocalPort = $localPort
}
        
.DESCRIPTION
Creates a dynamix port forwarding session with the OCI Bastion Service and the required SOCKS 5 proxy endpoint.
This combo will allow you to connect through the Bastion service via a local port and to your destination 
inside of teh target VCN. 
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER LocalPort
The local listeneing port for the SOCKS 5 endpoint. 

.EXAMPLE 
## Creating a dynamic port forwarding session 
#>
param(
    [Parameter(Mandatory, HelpMessage='OCID Bastion of Bastion')]
    [String]$BastionId, 
    [Parameter(HelpMessage='Use this local port, 0 means assign')]
    [Int32]$LocalPort=0
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location

function New-OpuDynamicPortForwardingSessionFull {
    param (
        [Parameter(Mandatory,HelpMessage='OCID of Bastion')]
        [String]$BastionId, 
        [Parameter(HelpMessage='Use this local port, 0 means assign')]
        [Int32]$LocalPort=0,
        [Parameter(HelpMessage='Seconds to wait before returing the session to the caller')]
        [Int32]$WaitForConnectSeconds=10
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {

        ## Validate input
        if ((5 -gt $WaitForConnectSeconds) -or (60 -lt $WaitForConnectSeconds)) {
            throw "WaitForConnectSeconds is ${WaitForConnectSeconds}: must to be between 5 and 60!"
        }
        ## Assign or verify LocalPort 
        if (0 -eq $LocalPort) {
            $LocalPort = Get-Random -Minimum 9001 -Maximum 9099
        } elseif ($LocalPort -lt 1024) {
            throw "LocalPort is ${LocalPort}: must be 1024 or greater!"
        }

        ## check that mandatory sw is installed    
        Test-OpuSshAvailable

        # Import modules
        Import-Module OCI.PSModules.Bastion
        $tmpDir = Get-TempDir
        $now = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"

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

        try {
            $bastionService = Get-OCIBastion -BastionId $BastionId  -WaitForLifecycleState Active -WaitIntervalSeconds 0 -ErrorAction Stop
        }
        catch {
            throw "Get-OCIBastion: $_"
        }    
        $maxSessionTtlInSeconds = $bastionService.MaxSessionTtlInSeconds

        
        ## Details of target
        $targetResourceDetails       = New-Object -TypeName 'Oci.bastionService.Models.CreateDynamicPortForwardingSessionTargetResourceDetails'
   
        ## Details of keyfile
        $keyDetails                  = New-Object -TypeName 'Oci.bastionService.Models.PublicKeyDetails'
        $keyDetails.PublicKeyContent = Get-Content "${keyFile}.pub"

        ## The actual session, name matches ephemeral key(s)
        $sessionDetails                       = New-Object -TypeName 'Oci.bastionService.Models.CreateSessionDetails'
        $sessionDetails.DisplayName           = -join("BastionSession-${now}-${localPort}")
        $sessionDetails.SessionTtlInSeconds   = $maxSessionTtlInSeconds
        $sessionDetails.BastionId             = $BastionId
        $sessionDetails.KeyType               = "PUB"
        $sessionDetails.TargetResourceDetails = $targetResourceDetails
        $sessionDetails.KeyDetails            = $keyDetails
    
        try {
            $bastionSession = New-OciBastionSession -CreateSessionDetails $sessionDetails -ErrorAction Stop
        }
        catch {
            throw "New-OciBastionSession: $_"
        }
    
        Out-Host -InputObject "Waiting for creation of bastion session to complete"
        try {
            $bastionSession = Get-OCIBastionSession -SessionId $bastionSession.Id -WaitForLifecycleState Active  -ErrorAction Stop 
        }
        catch {
            throw "Get-OCIBastionSession: $_"
        }

        
        ## Create ssh command argument
        $sshArgs = $bastionSession.SshMetadata["command"]

        ## First clean up any comments from Oracle(!)
        $hashPos = $sshArgs.IndexOf('#')
        if ($hashPos -gt 0) {
	        $strlen = $sshArgs.length
	        $sshArgs = $sshArgs.Remove($hashPos, $strlen-$hashPos)
        }

        ## Supply relevant parameters
        $sshArgs = $sshArgs.replace("ssh",          "-4")    ## avoid "bind: Cannot assign requested address" 
        $sshArgs = $sshArgs.replace("<privateKey>", $keyFile)
        $sshArgs = $sshArgs.replace("<localPort>",  $localPort)
        $sshArgs += " -o StrictHostKeyChecking=no"

        ## TODO: remove 
        ## Out-Host -InputObject "CONN: ssh ${sshArgs}"

        Out-Host -InputObject "Creating SSH tunnel"
        try {
            if ($IsWindows) {
                ## TODO: Change to Hidden when tested properly
                $sshProcess = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -WindowStyle Maximized -PassThru -ErrorAction Stop
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
            LocalPort = $localPort
        }

        Out-Host -InputObject "Waiting for creation of SSH tunnel to complete"
        Start-Sleep -Seconds $WaitForConnectSeconds

        $localBastionSession

    } catch {
        ## Pass exception on back
        throw "New-OpuDynamicPortForwardingSessionFull: $_"
    } finally {
        ## To Maximize possible clean ups, continue on error 
        $ErrorActionPreference = "Continue"

        ## Delete the files, they are not needed 
        $ErrorActionPreference = 'SilentlyContinue' 
        Remove-Item $keyFile -ErrorAction SilentlyContinue
        Remove-Item "${keyFile}.pub" -ErrorAction SilentlyContinue
        $ErrorActionPreference = "Continue"
    
        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}

try {
    ## check that mandatory sw is installed    
    if ($false -eq (Test-OpuSshAvailable)) {
        throw "SSH not properly installed"
    }
    
    ## Create session and process, get information in custom object -- return below
    $bastionSessionDescription = New-OpuDynamicPortForwardingSessionFull -BastionId $BastionId -LocalPort $LocalPort

    $bastionSessionDescription
}
catch {
    ## What else can we do? 
    Write-Error "Error: $_"
    return $false
}
finally {
    ## To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
    
    ## Finally, unload meodule from memory 
    Set-Location $PSScriptRoot
    Remove-Module oci-powershell-utils
    Pop-Location

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
}
