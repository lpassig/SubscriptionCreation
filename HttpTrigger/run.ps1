using namespace System.Net

<# Prerequisites
One time Task: You must have an Owner role on an Enrollment Account to create a subscription: 
Grant access to create Azure Enterprise subscriptions to the Managed Service Identity/Service Principal (using the object ID) of the Azure Function 
See: https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/grant-access-to-create-subscription?tabs=azure-powershell%2Cazure-powershell-2
#>

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."

$Request.Body

if ($name) {
    $body = "Hello, $name. This HTTP triggered function executed successfully."
}


if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts)) {
    Connect-AzAccount -Identity
}


<#
    Create Azure Subscription for Bootstrapping 
#>

#$AzureContext = Get-AzSubscription -SubscriptionId $connection.SubscriptionID

$OfferType = "MS-AZR-0148P"
#MS-AZR-0017P für Produktivsubscriptions
#MS-AZR-0148P für Dev/Test Subscriptions 

#Anzeigen der berechtigten Accounts
$EnrollmentId = (Get-AzEnrollmentAccount).ObjectId

New-AzSubscription -OfferType $OfferType -Name $SubscriptionName -EnrollmentAccountObjectId $EnrollmentId -OwnerSignInName $OwnerUPN1,$OwnerUPN2

<#
    Move Azure Subscription to Management Group  
#>

New-AzManagementGroupSubscription -GroupName 'Contoso' -SubscriptionId '12345678-1234-1234-1234-123456789012'


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
