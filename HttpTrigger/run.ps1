using namespace System.Net
<#
.NOTES
## General Advice ##

!!! Be aware that this is a version 0.1 not following all Powershell best practices!!!

Function Version: ~2 
PowerShell Version: PowerShell Core 6

<# Prerequisites

1. 
One time Task: You must have an Owner role on an Enrollment Account to create a subscription: 
Grant access to create Azure Enterprise subscriptions to the Managed Service Identity/Service Principal (using the object ID) of the Azure Function 
See: https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/grant-access-to-create-subscription?tabs=azure-powershell%2Cazure-powershell-2

2. 
Management Groups need to exists! 

3. 
Microsoft Forms and Power Automate need to exist and and properly configured  

#>
#>

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

#
##
###    Variables 
##
#

# Shortname of your organization/company
[String]$OrganizationName = 'company'

# Authenticate and log into Azure 
if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts)) {
    Connect-AzAccount -Identity
}

# Check for module and install if needed
if(!(Get-Module -ListAvailable Az.Subscription)){
    Install-Module Az.Subscription -AllowPrerelease -Force
}

# List/Output all incoming variables

Write-Host "Cost Center: " $Request.Body.costcenter
Write-Host "Compliance: " $Request.Body.compliance
Write-Host "Environment: " $Request.Body.environment
Write-Host "ProjectName: " $Request.Body.projectname
Write-Host "Criticality: " $Request.Body.criticality
Write-Host "Confidentiality: " $Request.Body.confidentiality
Write-Host "MSDN: " $Request.Body.msdn
Write-Host "ExternalPartner: " $Request.Body.partner
Write-Host "Requestor: " $Request.Body.owner
Write-Host "Managedby : " $Request.Body.managedby

#
##
###    Create Azure Subscription for Bootstrapping 
##
#

[String]$ProjectName = $Request.Body.projectname.Replace(' ', '').ToLower()

If($Request.Body.environment -like "Production"){
    $Environment = "prod"
}
If($Request.Body.environment -like "Testing"){
    $Environment = "test"
}
If($Request.Body.environment -like "Development"){
    $Environment = "dev"
}
If($Request.Body.environment -like "Sandbox"){
    $Environment = "sbox"
}

# Build SubscriptionName
$SubscriptionName ="sub-$OrganizationName-$ProjectName-$Environment"

# Define Subscription Offer Type

    # MS-AZR-0017P for EA-Subscription
    # MS-AZR-0148P for Dev/Test Subscriptions (MSDN Licences needed)

If($Request.Body.msdn -like "No"){
    $OfferType = "MS-AZR-0017P"
}
else{
    $OfferType = "MS-AZR-0148P"
}

# Get Object ID of the Managed Service Identity/Service Principal  
$EnrollmentId = (Get-AzEnrollmentAccount).ObjectId

# Create Subscription 
$NewSubscription = New-AzSubscription -OfferType $OfferType -Name $SubscriptionName -EnrollmentAccountObjectId $EnrollmentId -OwnerSignInName $Request.Body.owner

# Wait for the subscription to be created 
Start-Sleep -Seconds 10

#Log Subscription Details
Write-Output "New subscription:" $NewSubscription | ConvertTo-Json | Write-Output

#
##
###    Move Azure Subscription to Management Group
##
#

# Get created subscription  

$consistent = $false
    $loops = 0

    while (-not $consistent) {
        $subscription = $null
        try {
            $Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
        }
        catch {
            $subscription = $null
            if ($loops -eq 30) {
                throw "Took too long for subscription to become consistent."
            }
            Write-Output "Loop: $loops"
            Start-Sleep -Seconds 1
        }
        if ($null -ne $subscription) {
            $consistent = $true
        }
        $loops++
    }

# Move subscription to correlating Management Group for further bootstrapping (either using Enterprise Scale or Azure Bluepint)
New-AzManagementGroupSubscription -GroupName $Environment -SubscriptionId $Subscription.Id

# Wait for the subscription to be moved 
Start-Sleep -Seconds 10

#
##
###    Define subscription tags
##
#

# Define Naming for Tags
$company_costcenter = "$OrganizationName"+"_costcenter"
$company_managedby = "$OrganizationName"+"_managedby"
$company_complianceLevel = "$OrganizationName"+"_complianceLevel"
$company_project_app_name =  "$OrganizationName"+"_project_app_name"
$company_subscription_requestor = "$OrganizationName"+"subscription_requestor"
$company_environment = "$OrganizationName"+"_environment"
$company_criticality = "$OrganizationName"+"_criticality"
$company_confidentiality = "$OrganizationName"+"_confidentiality"
$company_reviewdate = "$OrganizationName"+"_reviewdate"
$company_maintenancewindow =  "$OrganizationName"+"_maintenancewindow"
$company_external_partner = "$OrganizationName"+"_external_partner"

# Define Tag Table 
If($Request.Body.partner -like ""){
$tags = @{
    "$company_costcenter"=$Request.Body.costcenter;
    "$company_managedby"=$Request.Body.managedby;
    "$company_complianceLevel"=$Request.Body.compliance;
    "$company_project_app_name"=$Request.Body.projectname;
    "$company_subscription_requestor"=$Request.Body.owner
    "$company_environment"=$Request.Body.environment;
    "$company_criticality"=$Request.Body.criticality;
    "$company_confidentiality"=$Request.Body.confidentiality;
    "$company_reviewdate"="TBD";
    "$company_maintenancewindow"="TBD";
    }
}
else{
$tags = @{
    "$company_costcenter"=$Request.Body.costcenter;
    "$company_managedby"=$Request.Body.managedby;
    "$company_complianceLevel"=$Request.Body.compliance;
    "$company_project_app_name"=$Request.Body.projectname;
    "$company_subscription_requestor"=$Request.Body.owner
    "$company_environment"=$Request.Body.environment;
    "$company_criticality"=$Request.Body.criticality;
    "$company_confidentiality"=$Request.Body.confidentiality;
    "$company_reviewdate"="TBD";
    "$company_maintenancewindow"="TBD";
    "$company_external_partner"=$Request.Body.partner;
    }    
}

#
##
###    Assign initial subscription tags
##
#

$subid = $subscription.Id
# Assign Tags
New-AzTag -ResourceId "/subscriptions/$subid" -Tag $tags

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
