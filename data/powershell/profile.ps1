#region PSDefaultParams
$PSDefaultParameterValues = @{
    'Get-ChildItem:Force'   = $True
    'Receive-Job:Keep'      = $True
    'Test-Connection:Quiet' = $True
    'Test-Connection:Count' = '1'
}
#endregion PSDefaultParams

#region Variables
if ($PSVersionTable.psedition -eq 'Core') {
    $PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Host
}

$CmdPromptUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$CmdDate = Get-Date
#endregion Variables

#region Custom Module Imports
Import-Module 'C:\Github\MessKit\MessKit.psm1' -Force
#endregion

#region Functions
Function Hosts: { Set-Location 'C:\windows\system32\drivers\etc\hosts' }
Function MessKit: { Set-Location 'C:\GitHub\MessKit' }
Function MessLab: { Set-Location 'C:\GitHub\MessLab' }
#endregion

#region IsAdmin
## Find out if the current user identity is elevated (has admin rights)
$IsAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
#endregion

#region Prompt
Function Set-CustomDirectory {
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        [Parameter()]
        $Path = $PWD.Path
    )

    $CustomDirectories = @{
        'C:\GitHub\MessLab' = 'MessLab'
        'C:\GitHub\MessKit' = 'MessKit'
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

Function Prompt {
    $Host.UI.RawUI.WindowTitle = 'PowerShell {0}' -f $PSVersionTable.PSVersion.ToString() + ' [' + (Get-Location) + ']'

    #$CmdPromptCurrentFolder = Split-Path -Path $pwd -Leaf
    $CmdPromptUser = [Security.Principal.WindowsIdentity]::GetCurrent()
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
}
#endregion
