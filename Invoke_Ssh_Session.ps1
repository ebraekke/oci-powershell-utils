<#
This example demonstrates how to connect securely to an SSH host inside a VCN
a bastion (session) and an (accepted) ssh private key 
#>

param(
    [String]$BastionId, 
    [String]$TargetHost,
    [String]$SshKey,
    [Int32]$TargetPort=22,
    [String]$OsUser="opc"
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

## TODO: fix and expand
## $moduleDebug = $env:OPU_DEBUG
$moduleDebug = $false

if ($true -eq $moduleDebug) {
    Out-Host -InputObject "Based on 'env:OPU_DEBUG'"
    Out-Host -InputObject "Debug is on "
}

Import-Module OCI.PSModules.Bastion
## Move into dir and load from there ...
Push-Location
Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location


try {
    ## Check parameters, prefer here rather than in param definition -- at least for now()
    if ($null -eq $BastionId) {
        throw "BastionId must be provided"
    }
    if ($null -eq $TargetHost) {
        throw "TargetHost ip must be provided"
    }
    if ($null -eq $SshKey) {
        throw "SshKey must be provided"
    } 
    
    
    ## Make sure mandatory input at least is a proper file  
    if ($false -eq (Test-Path $SshKey -PathType Leaf)) {
        throw "${SshKey} is not a valid file"        
    }
    
    ## check that mandatory sw is installed    
    if ($false -eq (Test-OpuSshAvailable)) {
        throw "SSH not properly installed"
    }

    ## use ssh-keygen to print public part of key
    ## ssh-keygen on Windows does not like "~", so convert to "$HOME"
    ssh-keygen -y -f ($sshKey.Replace("~", $HOME)) | Out-Null
    if ($false -eq $?) {
        throw "$SshKey is not a valid private ssh key"
    }

    ##
    ## $localBastionSession = [PSCustomObject]@{
    ##    BastionSession = $bastionSession
    ##    SShProcess = $sshProcess
    ##    PrivateKey = $keyFile
    ##    PublicKey = "${keyFile}.pub"
    ##    LocalPort = $localPort
    ##
    ## Create session and proces, get information in custom object -- see comment above
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort

    # Extract all elements into local variables
    $bastionSession = $bastionSessionDescription.Bastionsession
    $sshProcessBastion = $bastionSessionDescription.SShProcess
    $privateKeyBastion = $bastionSessionDescription.PrivateKey
    $publicKeyBastion = $bastionSessionDescription.PublicKey
    $localPort = $bastionSessionDescription.LocalPort
 
    ## -o 'NoHostAuthenticationForLocalhost yes' ensures no verification of locally forwarded port and localhost combos 
    ## $str = "ssh -o 'NoHostAuthenticationForLocalhost yes' -p $localPort 127.0.0.1 -l $OsUser -i $sshKey" 

    if ($true -eq $moduleDebug) {
        Out-Host -InputObject  $str
        $extraArgs = '-vvv'
    } else {
        $extraArgs =""
    }
    
    ssh -o 'NoHostAuthenticationForLocalhost yes' -p $localPort 127.0.0.1 -l $OsUser -i $sshKey $extraArgs
}
catch {
    ## What else can we do? 
    Write-Error "Error: $_"
    return $false
}
finally {
    ## To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
    
    if (!($true -eq $moduleDebug)) {
        # Kill SSH process
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
