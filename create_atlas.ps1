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


param(
    [Parameter(Mandatory)] [string]$team,
    [Parameter(Mandatory)] [string]$service,
    [Parameter(Mandatory)] [string]$environment,
    [Parameter(Mandatory)] [string]$publicKey,
    [Parameter(Mandatory)] [string]$privateKey,
    [ValidateSet("M0", "M2", "M5", "M10", "M20", "M30", "M40", "M50", "M60", "M80", "M140", "M200", "M300", "M400", "M700", IgnoreCase=$false)]
    [string]$tier = "M10",                          # Size of cluster to create
    [string]$region = "UK_SOUTH",                   # Atlas region where to create cluster. Note that the name differs from cloud provider names!
    [ValidateSet("AZURE", "AWS", IgnoreCase=$false)]
    [string]$provider = "AZURE",                    # Cloud provider to use, note that GCP is not supported
    [ValidateSet(8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096)]
    [int]$diskSizeGB,                               # Requested size of disk
    [ValidateSet("4.2", "4.4", "5.0", "6.0")]
    [string]$mdbVersion = "5.0",                    # Version of MongoDB to create
    [string]$role = "readWriteAnyDatabase@admin",   # Default role for the created user
    [string]$atlasProfile = "default"
    #[bool]$debug = $false                           # If true, will display the atlas CLI commands that are executed
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
    if ($debug) {
        Write-Host $fullCommand
    }
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
    if ($debug) {
        Write-Host $fullCommand
    }
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

function AlertsFilename() {
    "Alerts_$($environment).json"
}

function BackupPlanFilename() {
    "BackupPlan_$($environment).json"
}

function AuditLogConfigFilename() {
    "AuditLogConfig_$($environment).json"
}

function CreateAlerts($fileName) {
    & "$PSScriptRoot\alerts_atlas.ps1" restore -fileName $($fileName) -publicKey $($publicKey) -privateKey $($privateKey) -atlasProfile $($atlasProfile) -projectId $($projectId)
}

function UpdateBackupPlan($fileName) {
    & "$PSScriptRoot\backupplan_atlas.ps1" restore $(ClusterName) -fileName $($fileName) -atlasProfile $($atlasProfile) -projectId $($projectId)
}

function CreateAuditLogFilters($fileName) {
    & "$PSScriptRoot\auditlog_atlas.ps1" restore -fileName $($fileName) -publicKey $($publicKey) -privateKey $($privateKey) -atlasProfile $($atlasProfile) -projectId $($projectId)
}

function ProviderSpecificRegionName() {
    switch ($provider) {
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
    }
}

function CreateProject($projectName) {
    $result = Invoke-AtlasCommand "project create $(ProjectName) --withoutDefaultAlertSettings"
    $result.id
}

function MapAzureTierToDefaultDiskSize($tier) {
    switch($tier) {
        "M0" { 8 }
        "M2" { 8 }
        "M5" { 8 }
        "M10" { 8 }
        "M20" { 16 }
        "M30" { 32 }
        "M40" { 64 }
        "M50" { 128 }
        "M60" { 128 }
        "M80" { 256 }
        "M140" { 256 }
        "M200" { 256 }
        "M300" { 512 }
        "M400" { 512 }
        "M700" { 1024 }
    }
}

function CreateCluster($clusterName, $enableBackup) {
    $command = "cluster create $(ClusterName) --tier $($tier) --provider $($provider) --region $($region)"
    if ($diskSizeGB) {
        $command += " --diskSizeGB $($diskSizeGB)"
    }
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

    switch ($provider) {
        "AWS" { $result.endpointServiceName }
        "AZURE" { $result.privateLinkServiceResourceId }
    }
}

# Up-front validation of required files here, check that alerts, audit config and backup plan files exist
if (-not (Test-Path $(AuditLogConfigFilename))) {
    Write-Host "File $(AuditLogConfigFilename) is missing. Cannot configure audit logs."
    Exit 1
}
if (-not (Test-Path $(BackupPlanFilename))) {
    Write-Host "File $(BackupPlanFilename) is missing. Cannot configure backup plan."
    Exit 1
}
if (-not (Test-Path $(AlertsFilename))) {
    Write-Host "File $(AlertsFilename) is missing. Cannot configure alerts."
    Exit 1
}

Write-Host "Creating project $(ProjectName)"
$projectId = CreateProject ProjectName
Write-Host "Project $(ProjectName) created with ID $($projectId)"

$alertsFilename = AlertsFilename
Write-Host "Creating alerts from $($alertsFilename)"
CreateAlerts $alertsFilename
Write-Host "Alerts created"

Write-Host "Creating cluster $(ClusterName) as $($tier), with $($provider) in region $($region)"
if (($provider -eq "AZURE") -and -not $diskSizeGB) {
    # Azure requires this parameter to be set, sice the default value of 2GB is invalid for Azure clusters
    $diskSizeGB = MapAzureTierToDefaultDiskSize $tier
}
$enableBackup = -not ("M0", "M2", "M5").Contains($tier)
CreateCluster ClusterName $enableBackup
Write-Host "Cluster created"

if ($enableBackup) {
    Write-Host "Updating backup plan based on $(BackupPlanFilename)"
    UpdateBackupPlan $(BackupPlanFilename)
    Write-Host "Backup plan updated"
}
else {
    Write-Host "Skipping backup plan stage, since selected tier $($tier) does not support this."
}

$userName = UserName
$password = Password
$env:AtlasPassword = $password
Write-Host "Creating user $($userName) with password $($password), password available in environment variable `$env:AtlasPassword"
CreateUser $userName $password
Write-Host "User created"

Write-Host "Creating private endpoint connection"
$endpoint = CreatePrivateEndpoint
Write-Host "Private endpoint created $($endpoint)"

$auditLogFilename = AuditLogConfigFilename
Write-Host "Creating audit log filters from $($auditLogFilename)"
CreateAuditLogFilters $auditLogFilename
Write-Host "Audit log filters created"
