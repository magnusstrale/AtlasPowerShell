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
    [bool]$skipSampleData = $true,
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

function Invoke-SetupAtlasCommand([string]$command) {
    $fullCommand = "atlas " + $command
    if ($atlasProfile) {
        $fullCommand += " --profile " + $atlasProfile
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
    "svc_$($environment)_$($team)$($service)".ToLower()
}

function Password()
{
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
    ForEach($d in $distribution) { $totalChars += $d }

    $password = ""
    while ($totalChars -gt 0) {
        $totalChars -= 1

        # Pick a random set of characters to choose from, based on still available chars in the given distribution
        while ($true)
        {
            $set = $randomObj.Next(0, $sets)
            if ($distribution[$set] -gt 0)
            {
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

function CreateProject($projectName) {
    $result = Invoke-AtlasCommand "project create $(ProjectName) --withoutDefaultAlertSettings"
    $result.id
}

function CreateCluster($clusterName, $userName, $password) {
    $command = "setup --clusterName $(ClusterName) --tier $($tier) --provider $($provider) --region $($region) --username $($userName) --password ""$($password)"" --force"
    if ($skipSampleData) {
        $command += " --skipSampleData"
    }
    Invoke-SetupAtlasCommand $command
}

Write-Host "Creating project $(ProjectName)"
#$projectId = CreateProject ProjectName
$projectId = "6228b4a3311b6a2c9c48132e"
Write-Host "Project $(ProjectName) created with ID $($projectId)"

Write-Host "Creating cluster $(ClusterName) as $($tier), with $($provider) in region $($region)"
$userName = UserName
$password = Password
CreateCluster ClusterName $userName $password
Write-Host "Cluster created"

Write-Host "Creating backup plan based on $(BackupPlanFilename)"
#CreateBackupPlan BackupPlanFilename
Write-Host "Backup plan created"

Write-Host "Creating alerts based on $(AlertsFilename)"
#& "$PSScriptRoot\alerts_atlas.ps1 restore --fileName $(AlertsFilename) --publicKey qlrtbeas --privateKey 98895cc0-9894-4e21-96aa-53ca930cff94" 
Write-Host "Alerts created"

Write-Host "Creating private endpoint connection"
#CreatePrivateEndpoint
Write-Host "Private endpoint created"