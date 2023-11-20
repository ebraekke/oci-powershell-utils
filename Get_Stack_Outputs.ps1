
param(
    [Parameter(Mandatory, HelpMessage='OCID of Stack')]
    [String]$StackId
)

## START: generic section
$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location
## END: generic section

try {

        ## Grab main handle, ensure it is in correct lifecycle state 
        try {
            $stack = Get-OCIResourcemanagerStack -StackId $stack_ocid -WaitForLifecycleState Active -WaitIntervalSeconds 0 -ErrorAction Stop
        }
        catch {
            throw "Get-OCIResourcemanagerStack: $_"
        }

        $stack
}
catch {
    ## What else can we do?
    Write-Error "Get_Stack_Outputs.ps1: $_"
    return $false
}
finally {
    ## START: generic section
    ## To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
    
    ## Finally, unload module from memory 
    Set-Location $PSScriptRoot
    Remove-Module oci-powershell-utils
    Pop-Location

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
    ## END: generic section
}

