#region PSDefaultParams
$PSDefaultParameterValues = @{
    'Get-ChildItem:Force'   = $True
    'Receive-Job:Keep'      = $True
    'Test-Connection:Quiet' = $True
    'Test-Connection:Count' = '1'
}
#endregion PSDefaultParams

#region Variables
#$ Setup some session-based environment variables
$env:PSCP = 'C:\PortableApps\PortableApps\PuTTYPortable\App\putty\pscp.exe'
if ($PSVersionTable.psedition -eq 'Core') { $PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Host }

##### Trim $env:psmodulepath to only those I know have modules needed
# $psModulePath = @(
#     'C:\Program Files\PowerShell\Modules'
#     'C:\program files\powershell\7\Modules'
#     'C:\Program Files\WindowsPowerShell\Modules'
#     'C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
#     'C:\github'
# )
# $env:psmodulepath = ($psModulePath -join ';')

$CmdPromptUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$CmdDate = Get-Date
#endregion Variables

#region Custom Module Imports
Import-Module 'C:\Github\MessBuild\MessBuild.psm1' -Force
#endregion

#region Functions
Function F5Ansible: { Set-Location 'C:\Github\f5-ansible' }
Function F5Data: { Set-Location 'C:\Github\f5-data' }
Function F5Pester: { Set-Location 'C:\Github\f5-pester' }
Function F5Pwsh: { Set-Location 'C:\Github\f5-pwsh' }
Function F5Terraform: { Set-Location 'C:\Github\f5-terraform' }
Function MessBuild: { Set-Location 'C:\GitHub\MessBuild' }
Function MessKit: { Set-Location 'C:\GitHub\MessKit' }
Function Hosts: { Set-Location 'C:\windows\system32\drivers\etc\hosts' }
#endregion

#region IsAdmin
## Find out if the current user identity is elevated (has admin rights)
$IsAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
#endregion

#region Prompt
Function Set-CustomDirectory {
    <#
	.SYNOPSIS
		Set custom prompt
	.DESCRIPTION
		Set custom prompt to shorten path in terminal based on a simple hashtable lookup
	#>
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        [Parameter()]
        $Path = $PWD.Path
    )

    Process {
        $CustomDirectories = @{
            'C:\GitHub\f5-ansible'   = 'F5Ansible'
            'C:\GitHub\f5-data'      = 'F5Data'
            'C:\GitHub\f5-pester'    = 'F5Pester'
            'C:\GitHub\f5-pwsh'      = 'F5Pwsh'
            'C:\GitHub\f5-terraform' = 'F5Terraform'
            'C:\GitHub\MessBuild'    = 'MessBuild'
            'C:\GitHub\MessKit'      = 'MessKit'
        }

        Foreach ($Item in $Path) {
            $Match = ($CustomDirectories.GetEnumerator().name |
                Where-Object { $Item -eq "$_" -or $Item -like "$_*" } |
                Select-Object @{n = 'Directory'; e = { $_ } }, @{n = 'Length'; e = { $_.length } } |
                Sort-Object Length -Descending |
                Select-Object -First 1).directory

            If ($Match) {
                [String]($Item -replace [regex]::Escape($Match), $CustomDirectories[$Match])
            } ElseIf ($PWD.Pathh -ne $Item) {
                $Item
            } Else {
                $PWD.Path
            }
        }
    }
    End { }
}

Function Prompt {
    $Host.UI.RawUI.WindowTitle = 'PowerShell {0}' -f $PSVersionTable.PSVersion.ToString() + ' [' + (Get-Location) + ']'

    #$CmdPromptCurrentFolder = Split-Path -Path $pwd -Leaf
    $CmdPromptUser = [Security.Principal.WindowsIdentity]::GetCurrent();
    $CmdDate = Get-Date -Format 'dddd hh:mm:ss tt'

    #region History
    $LastCommand = Get-History -Count 1
    if ($lastCommand) { $RunTime = ($lastCommand.EndExecutionTime - $lastCommand.StartExecutionTime).TotalSeconds }
    if ($RunTime -ge 60) {
        $ts = [timespan]::fromseconds($RunTime)
        $min, $sec = ($ts.ToString('mm\:ss')).Split(':')
        $ElapsedTime = -join ($min, ' min ', $sec, ' sec')
    } else {
        $ElapsedTime = [math]::Round(($RunTime), 2)
        $ElapsedTime = -join (($ElapsedTime.ToString()), ' sec')
    }
    #endregion History

    # Decorate CMD prompt
    if ($IsAdmin) {
        $fgColor = 'Yellow'
    } else {
        $fgColor = 'Green'
    }
    Write-Host "[$($CmdPromptUser.Name.tolower())] [$(Set-CustomDirectory)] " -ForegroundColor $fgColor -NoNewline
    Write-Host "[$(Get-Date $CmdDate -Format 'dddd hh:mm:ss tt')]" -ForegroundColor $fgColor

    #return ' '
}
#endregion
