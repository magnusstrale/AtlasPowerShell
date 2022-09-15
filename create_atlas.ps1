<#

DISCLAIMER
This code is distributed as-is, with no warranties attached.
Albeit functional, this code is not considered
production-quality and should not be deployed or
run against production instances unless reviewed,
modified and hardened by an expert party.
This code works as an example under an engagement between
StoneX Group and MongoDB Professional Services, and MongoDB
has no obligation to support it.

#>

# Parameter help description
# TODO - StoneX to review and update default values
param(
    [string]$team = "GC",
    [string]$service = "pay",
    [string]$environment = "UAT",
    [string]$tier = "M10", # change to ?
    [string]$region = "EU_NORTH_1", # change to "UK_SOUTH" as default for StoneX?
    [string]$provider = "AWS", # change to "AZURE" as default for StoneX
    [string]$mdbVersion = "5.0", # Version of MongoDB to create
    [string]$role = "readWriteAnyDatabase@admin", # Default role for the created user
    [string]$atlasProfile = "default"
)

Import-Module -Name Microsoft.PowerShell.Utility

$randomObj = New-Object System.Random

function Invoke-AtlasCommand([string]$command) {
    $fullCommand = "atlas " + $command + " --output json"
    if ($atlasProfile) {
        $fullCommand += " --profile " + $atlasProfile
    }
    if ($projectId) {
        $fullCommand += " --projectId " + $projectId
    }
    Write-Host $fullCommand
    $fullCommand | Invoke-Expression | ConvertFrom-Json
}

function Invoke-SilentAtlasCommand([string]$command) {
    $fullCommand = "atlas " + $command
    if ($atlasProfile) {
        $fullCommand += " --profile " + $atlasProfile
    }
    if ($projectId) {
        $fullCommand += " --projectId " + $projectId
    }
    Write-Host $fullCommand
    $fullCommand | Invoke-Expression
}

function ClusterName() {
    "$($team)$($service)$($environment)".ToUpper()
}

function ProjectName() {
    "$($team)-$($service)-$($environment)".ToUpper()
}

function UserName() {
    "svc_$($environment)_$($team)$($service)user".ToLower()
}

function Password() {
    # Characters allowed in the password
    $chars = @(
        "abcdefghijkmnopqrstuvwxyz".ToCharArray(), 
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray(), 
        "0123456789".ToCharArray(),
        "!#%&?*._{}[]".ToCharArray())

    # How many characters from each set of characters to use
    $distribution = @(10, 10, 7, 5)

    $sets = $chars.Length
    $totalChars = 0
    ForEach ($d in $distribution) { $totalChars += $d }

    $password = ""
    while ($totalChars -gt 0) {
        $totalChars -= 1

        # Pick a random set of characters to choose from, based on still available chars in the given distribution
        while ($true) {
            $set = $randomObj.Next(0, $sets)
            if ($distribution[$set] -gt 0) {
                $distribution[$set] -= 1
                break
            }
        }

        # Pick a random character from the given set
        $password += $chars[$set] | Get-Random
    }
    $password
}

function BackupPlanFilename() {
    "BackupPlan_$($environment).json"
}

function AlertsFilename() {
    "Alerts_$($environment).json"
}

function ProviderSpecificRegionName() {
    switch ($provider.ToUpper()) {
        "AWS" {
            $region.ToLower().Replace("_", "-")
        }
        "AZURE" {
            switch ($region.ToUpper()) {
                "EUROPE_NORTH" { "northeurope" }
                "EUROPE_WEST" { "westeurope" }
                "UK_SOUTH" { "uksouth" }
                "UK_WEST" { "ukwest" }
                "FRANCE_CENTRAL" { "francecentral" }
                "FRANCE_SOUTH" { "francesouth " }
                "GERMANY_WEST_CENTRAL" { "germanywestcentral" }
                "GERMANY_NORTH" { "germanynorth" }
                "SWITZERLAND_NORTH" { "switzerlandnorth" }
                "SWITZERLAND_WEST" { "switzerlandwest " }
                "NORWAY_EAST" { "norwayeast" }
                "NORWAY_WEST" { "norwaywest " }
                "SWEDEN_CENTRAL" { "swedencentral" }
                "SWEDEN_SOUTH" { "swedensouth " }
                default {
                    Write-Host "No known mapping for Atlas region $($region) to Azure region"
                    Exit 1
                }
            }
        }
        default {
            Write-Host "Cloud provider $($provider) is not yet supported in this script."
            Exit 1
        }
    }
}

function CreateProject($projectName) {
    $result = Invoke-AtlasCommand "project create $(ProjectName) --withoutDefaultAlertSettings"
    $result.id
}

function CreateCluster($clusterName, $enableBackup) {
    $command = "cluster create $(ClusterName) --tier $($tier) --provider $($provider) --region $($region)"
    if ($enableBackup) {
        $command += " --backup"
    }
    $result = Invoke-AtlasCommand $command
    do {
        Write-Host "Waiting..."
        Start-Sleep -Seconds 30
        $result = Invoke-AtlasCommand "cluster describe $(ClusterName)"
    } while ($result.stateName -eq "CREATING")
    if ($result.stateName -ne "IDLE") {
        Write-Host "Something went wrong when creating cluster - state is ""$($result.stateName)"", expected ""IDLE"""
        Exit 1
    }
}

function CreateUser($userName, $password) {
    $result = Invoke-AtlasCommand "dbuser create --username $($userName) --password ""$($password)"" --role $($role)"
}

function CreatePrivateEndpoint() {
    $result = Invoke-AtlasCommand "privateEndpoint $($provider.ToLower()) create --region $(ProviderSpecificRegionName)"
    $endpointId = $result.id
    while ($result.status -eq "INITIATING") {
        Write-Host "Waiting..."
        Start-Sleep -Seconds 30
        $result = Invoke-AtlasCommand "privateEndpoint $($provider.ToLower()) describe $($endpointId)"
    }
    if ($result.status -ne "AVAILABLE") {
        Write-Host "Private endpoint reports status ""$($result.status)"", expected ""AVAILABLE"""
    }

    switch ($provider.ToUpper()) {
        "AWS" { $result.endpointServiceName }
        "AZURE" { $result.privateLinkServiceResourceId }
        default {
            Write-Host "Cloud provider $($provider) is not yet supported in this script."
            Exit 1        
        }
    }
}

Write-Host "Creating project $(ProjectName)"
#$projectId = CreateProject ProjectName
$projectId = "6228b4a3311b6a2c9c48132e"
Write-Host "Project $(ProjectName) created with ID $($projectId)"

Write-Host "Creating alerts based on $(AlertsFilename)"
#& "$PSScriptRoot\alerts_atlas.ps1 restore --fileName $(AlertsFilename) --publicKey qlrtbeas --privateKey 98895cc0-9894-4e21-96aa-53ca930cff94" 
Write-Host "Alerts created"

Write-Host "Creating cluster $(ClusterName) as $($tier), with $($provider) in region $($region)"
$enableBackup = -not ("M0", "M2", "M5").Contains($tier)
#CreateCluster ClusterName $enableBackup
Write-Host "Cluster created"

if ($enableBackup) {
    Write-Host "Creating backup plan based on $(BackupPlanFilename)"
    #CreateBackupPlan BackupPlanFilename
    Write-Host "Backup plan created"
}
else {
    Write-Host "Skipping backup plan stage, since selected tier $($tier) does not support this."
}

$userName = UserName
$password = Password
$env:AtlasPassword = $password
Write-Host "Creating user $($userName) with password $($password), password available in environment variable $env:AtlasPassword"
#CreateUser $userName $password
Write-Host "User created"

Write-Host "Creating private endpoint connection"
$endpoint = CreatePrivateEndpoint
Write-Host "Private endpoint created $($endpoint)"
