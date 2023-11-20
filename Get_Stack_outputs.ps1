

$resourceList = Get-OCIResourcemanagerStackAssociatedResourcesList -StackId $stack_ocid

## Count == 0 means that no resources have been created 
if (0 -eq $resourceList.Items.Count) {
    out-Host -InputObject "Empty"
}

## Get reverse sorted list, most recent first 
$jobList = Get-OCIResourcemanagerJobsList -StackId $stack_ocid

$listSize = $jobList.Count

## Traverse list to find latest (highest in list, apply job)

$count = 0
$found = $false 
$jobOcid = $null
while ( ($false -eq $found) -and  ($count -lt $listSize) ) {

    ## Only interested in most recent 'Apply' jobs that 'Succeded'
    if ( ('Apply' -eq $jobList[$count].Operation) -and ('Succeeded' -eq $jobList[$count].LifecycleState) ) {
        $found = $true
        $jobOcid = $jobList[$count].id
    } 

    $count++
}

## jobOcid now has job with latest outputs ... if it is not $null

## Can be returned to caller "as is" 
$outputList = Get-OCIResourcemanagerJobOutputsList -JobId $jobOcid


/*
$jobList[0]

Id                     : ocid1.ormjob.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaaeurqovl3erinwvxyz6mdwjrumcbmdpim4zyu6j2ibx7a
StackId                : ocid1.ormstack.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaahidjqgkpeahajmqoc6kdnqnpydafj3q4vtqghgm54c5a
CompartmentId          : ocid1.compartment.oc1..aaaaaaaaczweti6jsgswmtxm6hgfs6mdakb3asdsguuixnj47zd7frgln2jq
DisplayName            : apply-job-20231120110124
Operation              : Apply
JobOperationDetails    : Oci.ResourcemanagerService.Models.ApplyJobOperationDetailsSummary
ApplyJobPlanResolution : Oci.ResourcemanagerService.Models.ApplyJobPlanResolution
ResolvedPlanJobId      : ocid1.ormjob.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaa6wvsobr4sawm7gys7ircbg7irtq4xbffx3gf3cj4n47q
TimeCreated            : 20.11.2023 10:01:28
TimeFinished           : 20.11.2023 10:05:27
LifecycleState         : Succeeded
FreeformTags           : {}
DefinedTags            : {[billing, System.Collections.Generic.Dictionary`2[System.String,System.Object]]}

*/

/*
$outputList

OutputName  : conn_ocid
OutputType  : string
OutputValue : ocid1.databasetoolsconnection.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaavzvyqb7iwtsw7oudcmkkz26e4twy3abn3fkyhwf3eewq
IsSensitive : False
Description :

*/

