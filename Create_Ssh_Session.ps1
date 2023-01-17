<#
This example demonstrates how to connect securely to an SSH host inside a VCN
a bastion (session) and an (accepted) ssh private key 
#>

param(
    [String]$BastionId, 
    [String]$TargetHost,
    [String]$SshKey,
    [Int32]$Port=22,
    [String]$OsUser="opc"
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

function Test-Executable {
    param(
        [String]$ExeName, 
        [String]$ExeArguments
    )

    if ($null -eq $ExeName) {
        Throw "ExeName must be provided"
    }
    if ($null -eq $ExeArguments) {
        Throw "ExeArguments must be provided"
    }

    try {
        # run process 
        Start-Process -FilePath $ExeName -ArgumentList $ExeArguments -WindowStyle Hidden 
    }
    catch {
        throw "$ExeName executable not found"
    }
}

# main()
try {

    # Check parameters
    if ($null -eq $BastionId) {
        Throw "BastionId must be provided"
    }
    if ($null -eq $TargetHost) {
        Throw "TargetHost ip must be provided"
    }
    if ($null -eq $SshKey) {
        Throw "SshKey must be provided"
    } elseif ($False -eq (Test-Path $SshKey -PathType Leaf)) {
        Throw "$SshKey is not a file"        
    }
    if ($false -eq (Test-Path $PSScriptRoot/tmp)) {
        Throw "Directory $PSScriptRoot/tmp does not exist"        
    }
        
    # Check dependencies
    Test-Executable -ExeName "ssh"          -ExeArguments "--help"
    Test-Executable -ExeName "ssh-keygen"   -ExeArguments "--help"

    # use ssh-keygen to print public part of key
    # ssh-keygen on Windows does not like "~", so convert to "$HOME"
    ssh-keygen -y -e -f ($sshKey.Replace("~", $HOME)) | Out-Null
    if ($false -eq $?) {
        throw "$SshKey is not a valid private ssh key"
    }

    # Import the modules
    Import-Module OCI.PSModules.Bastion

    # Range 2223 to 2299
    $LocalPort = Get-Random -Minimum 2223 -Maximum 2299

    # Generate ephemeral key pair in ./tmp dir.  
    # name: bastionkey-yyyy_dd_MM_HH_mm_ss-$LocalPort
    #
    # Process will fail if another key with same name exists, in that case -- do not delete key file(s) on exit
    $DeleteKeyOnExit = $false
    $KeyFile = -join("$PSScriptRoot/tmp/bastionkey-",(Get-Date -Format "yyyy_MM_dd_HH_mm_ss"),"-$LocalPort")
    ssh-keygen -t rsa -b 2048 -f $KeyFile -q -N '' 
    $DeleteKeyOnExit = $true

    # Move into dir and execute there ...
    Push-Location
    Set-Location $PSScriptRoot
    $BastionSession=./Create_Bastion_SSH_Port_Forwarding_Session.ps1 -BastionId $BastionId -TargetHost $TargetHost -PublicKeyFile (-join($KeyFile, ".pub")) -Port $Port
    Pop-Location

    # Create ssh command argument string with relevant parameters
    $SshArgs = $BastionSession.SshMetadata["command"]
    $SshArgs = $SshArgs.replace("ssh",          "") 
    $SshArgs = $SshArgs.replace("<privateKey>", $KeyFile)
    $SshArgs = $sshArgs.replace("<localPort>",  $LocalPort)

    # for debug, comment out for now
    # Out-Host -InputObject "CONN : ssh $sshArgs"
    $SshProcess = Start-Process -FilePath "ssh" -ArgumentList $SshArgs -WindowStyle Hidden -PassThru

    ## -o "NoHostAuthenticationForLocalhost yes" ensures no verification of locally forwarded port and localhost combos 
    ## NOTE: use 'localhost' and not '127.0.0.1' as thsi is required both with putty and with ssh 
    ssh -o "NoHostAuthenticationForLocalhost yes" -p $LocalPort localhost -l $OsUser -i $SshKey 
}
finally {

    # To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"

    # Kill SSH process
    Stop-Process -InputObject $SshProcess

    # Delete ephemeral key pair if all went well
    if ($true -eq $DeleteKeyOnExit) {
        Remove-Item $KeyFile
        Remove-item (-join($KeyFile, ".pub"))    
    } 
    
    # Kill Bastion session, with Force, ignore output (it is the work request id)
    Remove-OCIBastionSession -SessionId $BastionSession.id -Force | Out-Null

    # Done, restore settings
    $ErrorActionPreference = $UserErrorActionPreference
}
