
param(
    [Parameter(Mandatory, HelpMessage='OCID of Stack')]
    [String]$StackId,
    [Parameter(HelpMessage='Filter on (<your-regexp)')]
    [String]$FilterRegexp=$null
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

        ## Get respurce handle and see if there are any ... 
        try {
            $resourceList = Get-OCIResourcemanagerStackAssociatedResourcesList -StackId $stack_ocid -ErrorAction Stop
        }
        catch {
            throw "Get-OCIResourcemanagerStackAssociatedResourcesList: $_"
        }
        if (0 -eq $resourceList.Items.Count) {
            throw "Get-OCIResourcemanagerStackAssociatedResourcesList: Found no resources for this stack"
        }

        ## Get the reverse sorted list of Jobs, i.e. most recent first 
        try {
            $jobList = Get-OCIResourcemanagerJobsList -StackId $stack_ocid -LifecycleState Succeeded -ErrorAction Stop
        }
        catch {
            throw "Get-OCIResourcemanagerJobsList: $_"
        }

        ## Traverse list to find the latest (highest in list) apply job
        $listSize = $jobList.Count
        $count = 0
        $found = $false 
        $jobOcid = $null
        while ( ($false -eq $found) -and  ($count -lt $listSize) ) {

            ## Only interested in most recent 'Apply' job
            if ('Apply' -eq $jobList[$count].Operation) {
                $found = $true
                $jobOcid = $jobList[$count].id
            } 

            $count++
        }

        ## Check to see if Job was not found -- this should not happen
        if ($null -eq $jobOcid) {
            throw "No (Successful) Apply job found"
        }

        ## Get OutputsList
        try {
            $outputList = Get-OCIResourcemanagerJobOutputsList -JobId $jobOcid -ErrorAction Stop
        }
        catch {
            throw "Get-OCIResourcemanagerJobOutputsList: $_"
        }

        ## Return list of outputs, apply filter if requested
        if ($null -eq $FilterRegexp) {
            $outputList.Items
        }
        else {
            $outputList.Items | Where-Object {$_.OutputName -Match "${FilterRegexp}.*" }
        }
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

