<#
.SYNOPSIS
Get outputs from a Oracle Cloud Infrastructure (OCI) Resource Manager (RM) Stack.

.DESCRIPTION
Inspired by Pulumi, this script allows you to collect outputs from an OCI RM stack.
This is how it works. 
RM does not store outputs or exposed items at the stack level. 
To be able to simulate this I do the following: 
- Verify that the stack exists and that it is in the correct lifecycle
- Verify that the stack has resources associated with it
- Find the most recent (successfully) executed apply job by traversing the stack's job list 
- Get the outputlist from the relevant apply job 
- Apply filtering -- if requested -- and then return the list of outputs 

.PARAMETER StackId
OCID of Stack from which to pull outputs. 
 
.PARAMETER ConnectionId
OCID of connection containing the details about the database system. 

.PARAMETER FilerRegexp
A regular expression to be applied to the name in the list of outputs before returning the list.

.EXAMPLE 
## Successfully invoking script and returning all outputs
❯ .\get_Stack_Outputs.ps1 -StackId $stack_ocid

OutputName  : dbg_dasigret
OutputType  : string
OutputValue :
IsSensitive : True
Description :

OutputName  : mongo_password_ocid
OutputType  : string
OutputValue : ocid1.vaultsecret.oc1.eu-stockholm-1.amaaaaaa3gkdkiaaqgjmfhp3qbzeedrj6evy2uhwzabf3iqo3myyx4dlfnia
IsSensitive : False
Description :

OutputName  : mysql_password_ocid
OutputType  : string
OutputValue : ocid1.vaultsecret.oc1.eu-stockholm-1.amaaaaaa3gkdkiaaxky3hzgnwfqw7jjfi4diruc2oo6z6pcu43fe4r4mpgwq
IsSensitive : False
Description :

## Invoking script with a StackId that is not valid
❯ .\get_Stack_Outputs.ps1 -StackId $bad_stack_ocid
Write-Error: Get_Stack_Outputs.ps1: Get-OCIResourcemanagerStack: One or more errors occurred. (Authorization failed or requested resource not found.)

## Invoking script with a valid StackId that has no resources
❯ .\get_Stack_Outputs.ps1 -StackId $stack_ocid
Write-Error: Get_Stack_Outputs.ps1: Get-OCIResourcemanagerStackAssociatedResourcesList: Found no resources for this stack

## Invoking script with a valid StackId and request filtering on a prefix
❯ .\get_Stack_Outputs.ps1 -StackId $stack_ocid -FilterRegexp ^dbg_

OutputName  : dbg_dasigret
OutputType  : string
OutputValue :
IsSensitive : True
Description :

## Invoking script with a valid StackId and request filtering on any string
❯ .\get_Stack_Outputs.ps1 -StackId $stack_ocid -FilterRegexp pass

OutputName  : mongo_password_ocid
OutputType  : string
OutputValue : ocid1.vaultsecret.oc1.eu-stockholm-1.amaaaaaa3gkdkiaaqgjmfhp3qbzeedrj6evy2uhwzabf3iqo3myyx4dlfnia
IsSensitive : False
Description :

OutputName  : mysql_password_ocid
OutputType  : string
OutputValue : ocid1.vaultsecret.oc1.eu-stockholm-1.amaaaaaa3gkdkiaaxky3hzgnwfqw7jjfi4diruc2oo6z6pcu43fe4r4mpgwq
IsSensitive : False
Description :

#>

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
            $stack = Get-OCIResourcemanagerStack -StackId $StackId -WaitForLifecycleState Active -WaitIntervalSeconds 0 -ErrorAction Stop
        }
        catch {
            throw "Get-OCIResourcemanagerStack: $_"
        }

        ## Get respurce handle and see if there are any ... 
        try {
            $resourceList = Get-OCIResourcemanagerStackAssociatedResourcesList -StackId $StackId -ErrorAction Stop
        }
        catch {
            throw "Get-OCIResourcemanagerStackAssociatedResourcesList: $_"
        }
        if (0 -eq $resourceList.Items.Count) {
            throw "Get-OCIResourcemanagerStackAssociatedResourcesList: Found no resources for this stack"
        }

        ## Get the reverse sorted list of Jobs, i.e. most recent first 
        try {
            $jobList = Get-OCIResourcemanagerJobsList -StackId $StackId -LifecycleState Succeeded -ErrorAction Stop
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

