function Remove-OpuManagedSessionFull {
    param (
        [Parameter(Mandatory,HelpMessage='Full Bastion Managed Session Description Object')]
        $BastionManagedSessionDescription
    )

    ## To Maximize possible clean ups, continue on error
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        Import-Module OCI.PSModules.Bastion
    
        ## Kill Bastion session, with Force, ignore output and error (it is the work request id)
        try {
            Remove-OCIBastionSession -SessionId $BastionSessionDescription.BastionSession.Id -Force -ErrorAction Ignore | Out-Null            
        }
        catch {
            Write-Error "Remove-OpuManagedSessionFull: $_"
        }
    }
    finally {
        ## Done, restore settings
        $ErrorActionPreference = $userErrorActionPreference
    }
}

function New-OpuManagedSessionFull {
    param (
        [Parameter(Mandatory,HelpMessage='OCID of Bastion')]
        [String]$BastionId, 
        [Parameter(Mandatory,HelpMessage='OCID of target host')]
        [String]$TargetHostId,
	[Parameter(HelpMessage='User to connect at target (opc)')]
    	[String]$OsUser="opc"
    )
    $userErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    try {
        ## check that mandatory sw is installed    
        Test-OpuSshAvailable

        Import-Module OCI.PSModules.Bastion

        $tmpDir = Get-TempDir
        $now = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"

        ## Same process as with Port forwarding
        ## Different range to be able to distingiush
        $localRandom = Get-Random -Minimum 8001 -Maximum 8099
        
        ## Generate ephemeral key pair in $tmpDir.  
        ## name: bastionkey-${now}.{localRandom}
        ##
        ## Process will fail if another key with same name exists, in that case -- TODO: decide what to do
        Out-Host -InputObject "Creating ephemeral key pair"
        $keyFile = -join("${tmpDir}/bastionkey-","${now}-${localRandom}")

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
    
        Out-Host -InputObject "Creating Managed Session to ${OsUser}@${TargetHostId}"

        try {
            $bastionService = Get-OCIBastion -BastionId $BastionId  -WaitForLifecycleState Active -WaitIntervalSeconds 0 -ErrorAction Stop
        }
        catch {
            throw "Get-OCIBastion: $_"
        }    
        $maxSessionTtlInSeconds = $bastionService.MaxSessionTtlInSeconds

        ## Details of target
        $TargetResourceDetails                                        = New-Object -TypeName 'Oci.BastionService.Models.CreateManagedSshSessionTargetResourceDetails'
        $TargetResourceDetails.TargetResourceOperatingSystemUserName  = $OsUser
        $TargetResourceDetails.TargetResourceId                       = $TargetHostId

        ## Details of keyfile
        $keyDetails                  = New-Object -TypeName 'Oci.bastionService.Models.PublicKeyDetails'
        $keyDetails.PublicKeyContent = Get-Content "${keyFile}.pub"

        ## The actual session, name matches ephemeral key(s)
        $sessionDetails                       = New-Object -TypeName 'Oci.bastionService.Models.CreateSessionDetails'
        $sessionDetails.DisplayName           = -join("BastionSession-${now}-${localRandom}")
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
            $bastionSession = Get-OCIBastionSession -SessionId $bastionSession.Id -WaitForLifecycleState Active  -ErrorAction Stop 
        }
        catch {
            throw "Get-OCIBastionSession: $_"
        }

        ## Create return Object
        $localBastionSession = [PSCustomObject]@{
            BastionSession = $bastionSession
            PrivateKey = Get-Content "${keyFile}"
            PublicKey = Get-Content "${keyFile}.pub"
        }

        $localBastionSession
    } catch {
        ## Pass exception on back
        throw "New-OpuManagedSessionFull: $_"
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


