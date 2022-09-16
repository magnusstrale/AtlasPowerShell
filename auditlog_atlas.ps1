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
param(
    [ValidateSet("backup", "restore")]
    [string]$action = "backup",
    [string]$fileName = "AuditLogConfig.json",
    [Parameter(Mandatory)] [string]$publicKey,
    [Parameter(Mandatory)] [string]$privateKey,
    [string]$atlasProfile = "default",
    [string]$projectName,
    [string]$projectId
)

Import-Module -Name Microsoft.PowerShell.Utility

function Invoke-AtlasCommand([string]$command) {
    $fullCommand = "atlas " + $command + " --output json"
    if ($atlasProfile) {
        $fullCommand += " --profile " + $atlasProfile
    }
    if ($projectId) {
        $fullCommand += " --projectId " + $projectId
    }
    $fullCommand | Invoke-Expression | ConvertFrom-Json
}

function FindProjectIdFor($projectName) {
    $result = Invoke-AtlasCommand "project list"
    $projects = $result.results
    foreach ($project in $projects) {
        if ($project.name.ToLower() -eq $projectName.ToLower()) {
            return $project.id
        }
    }
    Write-Host "Cannot find a project with name ""$($projectName)"""
    Exit 1
}

function GetProjectId() {
    if ($projectId) {
        $projectId
    }
    else {
        $result = Invoke-AtlasCommand ("config describe " + $atlasProfile)
        $result.project_id
    }
}

function BackupAuditConfiguration($fileName) {
    if (Test-Path $fileName) {
        Write-Host "File $($fileName) already exists. Give a different backup file name with parameter -fileName <name of backup file>"
        Exit 1
    }

    $baseUrl = "https://cloud.mongodb.com/api/atlas/v1.0/groups/$(GetProjectId)/auditLog"
    $securePassword = ConvertTo-SecureString $privateKey -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($publicKey, $securePassword)
    
    $result = Invoke-WebRequest `
        -Method Get `
        -Credential $cred `
        -Headers @{"accept" = "application/json" } `
        -ContentType "application/json" `
        -Uri $baseUrl | Select-Object -ExpandProperty Content | ConvertFrom-Json

    $result | ConvertTo-Json -Depth 10 | Set-Content -Path $fileName
}

function RestoreAuditConfiguration($config) {

    $baseUrl = "https://cloud.mongodb.com/api/atlas/v1.0/groups/$(GetProjectId)/auditLog"
    $securePassword = ConvertTo-SecureString $privateKey -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($publicKey, $securePassword)

    $result = Invoke-WebRequest `
        -Method Post `
        -Credential $cred `
        -Headers @{"accept" = "application/json" } `
        -ContentType "application/json" `
        -Body $config `
        -Uri $baseUrl | Select-Object -ExpandProperty Content | ConvertFrom-Json
}

if ($projectName) {
    $projectId = FindProjectIdFor $projectName
}

Switch ($action) {
    "backup" {
        BackupAuditConfiguration $fileName
    }
    "restore" {
        $config = Get-Content -Raw $fileName
        RestoreAuditConfiguration $config
    }
}

