# AtlasPowerShell
Powershell scripts for administering various MongoDB Atlas settings.

## Prerequisites

The following prerequisites needs to be fulfilled for these scripts to run correctly:

- Atlas CLI should be installed. At least version 1.1.7. It can be downloaded from here https://www.mongodb.com/docs/atlas/cli/stable/install-atlas-cli/
- Windows Powershell version 5.1 or later **or** Powershell Core 7.0 or later. The version of Powershell can be checked with the command "$PSVersionTable.PSVersion" from a Powershell command prompt.
- Windows Powershell ISE is the recommended environment for running these scripts since it will give you parameter completion etc.
- A set of Atlas API keys that gives you access to the desired Atlas environment. In order to run the create_atlas.ps1 script you need a set of organization level keys that has the group creator role in the organization, otherwise the script will not be able to create a new project.

All scripts should be placed in the same folder.

## General notes

Even if Windows as an operating system usually does not care about exact casing for file names, this does not apply when running Powershell. All file names, both scripts as well as config / json files needs to use the exact casing as described in this document.

The parameters to the scripts can be displayed by running the Get-Help commandlet in Powershell. For example to describe the parameters for the alerts_atlas.ps1 script:

    Get-Help .\alerts_atlas.ps1

This will show you the following:

    alerts_atlas.ps1 [[-action] &lt;string&gt;] [[-fileName] &lt;string&gt;] [[-publicKey] &lt;string&gt;] [[-privateKey] &lt;string&gt;] [[-atlasProfile] &lt;string&gt;] [[-projectName] &lt;string&gt;] [[-projectId] &lt;string&gt;]

The information about parameters are described in this document, but Get-Help may still be convenient to use.

The script descriptions in this document are showing that the parameter names are required, which is the recommended usage, but as implied by the description from Get-Help above, the actual names are optional and in that case the position of the value determines which parameter is defined by that value. For example, these two commands are equivalent:

    .\alerts_atlas.ps1 backup Alerts_uat.json -atlasProfile Demo

    .\alerts_atlas.ps1 -action backup -fileName Alerts_uat.json -atlasProfile Demo

## Downloading backup snapshots with backup_atlas.ps1

Create a snapshot and download it to the machine where this script is executed.

**Synopsis**

.\backup_atlas.ps1 -clusterName &lt;string&gt; -description &lt;string&gt; [-atlasProfile &lt;string&gt;] [-projectName &lt;string&gt;] [-projectId &lt;string&gt;]

| Parameter     | Description
| ---------     | ----------- 
| -clusterName  | Name of the cluster to backup. (mandatory)
| -description  | Description for the snapshot that gets created. (mandatory)
| -atlasProfile | The profile to use for for Atlas CLI commands. (default is default Atlas CLI profile)
| -projectId    | The ID of the project that contains the cluster to backup. Overrides information in profile. (default is value from Atlas CLI profile)
| -projectName  | The name of the project that contains the cluster to backup. Overrides value for -profileId if both given.

## Manage project alerts with alerts_atlas.ps1

Create a backup or restore project alert settings for a project. The information is stored in a JSON file and can be manipulated with a text editor, but it is recommended to define the desired set of alerts with the Atlas UI and simply create a backup with this script.

**Synopsis**
.\alerts_atlas.ps1 [-action &lt;string&gt;] [-fileName &lt;string&gt;] [-publicKey &lt;string&gt;] [-privateKey &lt;string&gt;] [-atlasProfile &lt;string&gt;] [-projectName &lt;string&gt;] [-projectId &lt;string&gt;]

| Parameter     | Description
| ---------     | ----------- 
| -action       | The action to perform. Can be backup or restore. (default backup)
| -fileName     | Name of file to use. If action is backup, the file is created. If action is restore the configuration is read from this file (default alerts.json)
| -publicKey    | The public part of the API key used to access Atlas. Only required when action is restore. 
| -privateKey   | The private part of the API key used to access Atlas. Only required when action is restore.
| -atlasProfile | The profile to use for for Atlas CLI commands. (default is default Atlas CLI profile)
| -projectId    | The ID of the project to use. Overrides information in profile. (default is value from Atlas CLI profile)
| -projectName  | The name of the project to use. Overrides value for -profileId if both given.

## Manage backup policy with backupplan_atlas.ps1

Create a backup of backup plan settings or restore backup plan settings for a cluster. The information is stored in a JSON file and can be manipulated with a text editor, but it is recommended to define the desired backup plan with the Atlas UI and simply create a backup with this script.

**Synopsis**

.\backupplan.ps1 -action &lt;string&gt; -clusterName &lt;string&gt; [-fileName &lt;string&gt;] [-atlasProfile &lt;string&gt;] [-projectName &lt;string&gt;] [-projectId &lt;string&gt;]

| Parameter     | Description
| ---------     | ----------- 
| -action       | The action to perform. Can be backup or restore. (default backup)
| -clusterName  | Name of cluster to use. If action is backup, the existing backup plan for that cluster is saved. If action is restore the backup plan for that cluster is modified according to the configuration file.
| -fileName     | Name of file to use. If action is backup, the file is created. If action is restore the configuration is read from this file (default BackupPlan.json)
| -atlasProfile | The profile to use for for Atlas CLI commands. (default is default Atlas CLI profile)
| -projectId    | The ID of the project to use. Overrides information in profile. (default is value from Atlas CLI profile)
| -projectName  | The name of the project to use. Overrides value for -profileId if both given.

## Manage audit log configuration with auditlog_atlas.ps1

Create a backup or restore the audit log settings for an Atlas project. The information is stored in a JSON file and can be manipulated with a text editor, but it is recommended to define the desired backup plan with the Atlas UI and simply create a backup with this script.

**Synopsis**

auditlog_atlas.ps1 [-action] &lt;string&gt; [-fileName] &lt;string&gt; [-publicKey] &lt;string&gt; [-privateKey] &lt;string&gt; [-atlasProfile &lt;string&gt;] [-projectName &lt;string&gt;] [-projectId &lt;string&gt;]

| Parameter     | Description
| ---------     | ----------- 
| -action       | The action to perform. Can be backup or restore. (default backup)
| -fileName     | Name of file to use. If action is backup, the file is created. If action is restore the configuration is read from this file (default BackupPlan.json)
| -atlasProfile | The profile to use for for Atlas CLI commands. (default is default Atlas CLI profile)
| -projectId    | The ID of the project to use. Overrides information in profile. (default is value from Atlas CLI profile)
| -projectName  | The name of the project to use. Overrides value for -profileId if both given.

## Create Atlas setup for a team / application / environment

First ensure you have the necessary config files for the intended environment. You need:
- Alerts_[environment].json
- BackupPlan_[environment].json
- AuditLogConfig_[environment].json

### Create Alerts.json

Run the script alerts_atlas.ps1 with the backup option and output to a file with the correct name based on the environment. For example to create an alerts config file from project GC-PAY-PROD to be used as a template for setting up Atlas in UAT environment (note that alerts are defined on projects), run the following command:

    .\alerts_atlas.ps1 backup -projectName GC-PAY-PROD -fileName Alerts_UAT.json

### Create BackupPlan.json

Run the script backupplan_atlas.ps1 with the backup option and output to a file with the correct name based on the environment. For example to create a backup plan config file from project GCPAYPROD, cluster GC-PAY-PROD (note that backup plan is defined on cluster) to be used as a template for setting up Atlas in UAT environment, run the following command:

    .\backupplan_atlas.ps1 backup -projectName GC-PAY-PROD -clusterName GCPAYPROD -fileName BackupPlan_UAT.json

### Create AuditLogConfig.json

Run the script auditlog_atlas.ps1 with the backup option and output to a file with the correct name based on the environment. Accessing the audit log configuration requires the script to use the API keys.

For example to create an audit log config file from project GCPAYPROD (note that auditing configuration is defined on projects) to be used as a template for setting up Atlas in UAT environment, run the following command:

    .\auditlog_atlas.ps1 backup -projectName GC-PAY-PROD -fileName AuditLogConfig_UAT.json -publicKey ljewcykn -privateKey b4806a90-76d0-41d9-a5ff-22cb58d7e14f

### Create Atlas setup

The script create_atlas.ps1 will create an entire Atlas environment for you, based on parameters on the command line as well as configuration files with associated data. The process will set up the following:
- A new project
- Alerts in that project according to config file
- A cluster, configured as a three-node replica set
- A backup plan according to config file
- A database user
- A private endpoint (manual configuration will be needed post-setup in your cloud provider)
- Audit log according to config file

**Synopsis**

.\create_atlas.ps1 -team &lt;string&gt; -service &lt;string&gt; -environment &lt;string&gt; -publicKey &lt;string&gt; -privateKey &lt;string&gt; [-tier &lt;string&gt;] [-region &lt;string&gt;] [-provider &lt;string&gt;] [-diskSizeGB &lt;int&gt;] [-mdbVersion &lt;string&gt;] [-role &lt;string&gt;] [-atlasProfile &lt;string&gt;]

| Parameter     | Description
| ---------     | ----------- 
| -team         | Name of the team that owns this setup (mandatory)
| -serivce      | Name of the service/application that will use this setup (mandatory)
| -environment  | Name of the environment where to create this setup (mandatory)
| -publicKey    | The public part of the API key used to access Atlas (mandatory)
| -privateKey   | The private part of the API key used to access Atlas (mandatory)
| -tier         | The size of the Atlas cluster to create (default M10)
| -region       | The region where to create the Atlas cluster. Values depends on your cloud provider. (default UK_SOUTH)
| -provider     | The cloud provider to use for your cluster. Valid values are AWS or AZURE. (default AZURE)
| -diskSizeGB   | The amount of disk spce to allocate for your cluster. Should rarely need to be used. (default depends on tier)
| -mdbVersion   | Version of MongoDB to run on your cluster. Valid values are 4.2, 4.4, 5.0 and 6.0. (default 5.0)
| -role         | Role that the database user is assigned to. (default readWriteAnyDatabase@admin)
| -atlasProfile | The profile to use for for Atlas CLI commands.

The -team, -service and -environment parameters will be used for naming various artifacts in the setup process. Assuming we have the following command line:

    .\create_atlas.ps1 -team GC -service APP -environment UAT -publicKey ljewcykn -privateKey b4806a90-76d0-41d9-a5ff-22cb58d7e14f

- Project name will be GC-APP-UAT
- Cluster name will be GCAPPUAT
- Database user name will be svc_uat_gcapp

The -environment name will also be used to determine which configuration files to use for creating alerts, configuring backup plan and setting audit log configuration. Again using the example above with -environment UAT, the following configuration files will be used:

| Type                  | File name
| ----                  | ---------
| Alerts                | Alerts_UAT.json
| Backup plan           | BackupPlan_UAT.json
| Audit configuration   | AuditLogConfig_UAT.log

**Note that the file names are case sensitive**

### Usage Examples

Creates a new setup in AZURE, region UK_SOUTH with a M10 cluster for UAT environment. Profile information in the Atlas CLI profile Demo will be used. Note! Ensure that the API keys registered in the selected profile matches the API keys given on the command line.

    .\create_atlas.ps1 -team GC -service APP -environment UAT -publicKey ljewcykn -privateKey b4806a90-76d0-41d9-a5ff-22cb58d7e14f -atlasProfile Demo

Creates a new setup in AWS, region EU_NORTH_1 with a M30 cluster for prod environment. Profile information in the Atlas CLI profile Production will be used

    .\create_atlas.ps1 -team GC -service APP -environment UAT -publicKey abacggfd -privateKey b4806a90-9999-41d9-a5ff-22cb9872124f -atlasProfile Production -provider AWS -region EU_NORTH_1 -tier M30