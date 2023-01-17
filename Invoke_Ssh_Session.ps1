<#
This example demonstrates how to connect securely to an SSH host inside a VCN
a bastion (session) and an (accepted) ssh private key 
#>

param(
    [Parameter(Mandatory, HelpMessage='OCID Bastion')]
    [String]$BastionId, 
    [Parameter(Mandatory,HelpMessage='IP address of target host')]   
    [String]$TargetHost,
    [Parameter(Mandatory, HelpMessage='SSH Key file for auth')]
    [String]$SshKey,
    [Parameter(HelpMessage='Port at Traget host')]
    [Int32]$TargetPort=22,
    [Parameter(HelpMessage='User to connect at target (opc)')]
    [String]$OsUser="opc"
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Import-Module OCI.PSModules.Bastion

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location

try {
    ## check that mandatory sw is installed    
    if ($false -eq (Test-OpuSshAvailable)) {
        throw "SSH not properly installed"
    }
    
    ## Make sure mandatory input at least is a proper file  
    if ($false -eq (Test-Path $SshKey -PathType Leaf)) {
        throw "${SshKey} is not a valid file"        
    }
    
    ## use ssh-keygen to print public part of key
    ## ssh-keygen on Windows does not like "~", so convert to "$HOME"
    ssh-keygen -y -f ($sshKey.Replace("~", $HOME)) | Out-Null
    if ($false -eq $?) {
        throw "$SshKey is not a valid private ssh key"
    }

    ## Create session and proces, get information in custom object -- see comment above
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort

    ## Extract all elements into local variables
    $bastionSession = $bastionSessionDescription.Bastionsession
    $sshProcessBastion = $bastionSessionDescription.SShProcess
    $privateKeyBastion = $bastionSessionDescription.PrivateKey
    $publicKeyBastion = $bastionSessionDescription.PublicKey
    $localPort = $bastionSessionDescription.LocalPort
     
    ## NOTE 1: 'localhost' and not '127.0.0.1'
    ## Behaviour with both ssh and putty is unreliable when not using 'localhost'.
    ## NOTE2: -o 'NoHostAuthenticationForLocalhost yes' 
    ## Ensures no verification of locally forwarded port and localhost combos. 
    ssh -o 'NoHostAuthenticationForLocalhost yes' -p $localPort localhost -l $OsUser -i $SshKey
}
catch {
    ## What else can we do? 
    Write-Error "Error: $_"
    return $false
}
finally {
    ## To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
    
    if ($true -eq $true) {
        ## Kill SSH process
        Stop-Process -InputObject $sshProcessBastion

        ## Delete ephemeral key pair returned in session obj
        if ($true -eq $true) {
            Remove-Item $privateKeyBastion
            Remove-item $publicKeyBastion    
        }

        # Kill Bastion session, with Force, ignore output (it is the work request id)
        Remove-OCIBastionSession -SessionId $bastionSession.id -Force | Out-Null
    }

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
}
