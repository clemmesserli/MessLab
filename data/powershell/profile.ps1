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

#region Set Custom Aliases
Set-Alias -Name gms -Value Get-MySecret -Description "Copy MyVault Admin Pwd to ClipBoard"
Set-Alias -Name ums -Value Unlock-MySecret -Description "Unlock MyVault using encrypted CmsMessage file"
#endregion

#region Functions
function Clear-SavedHistory {
    # src: https://stackoverflow.com/a/38807689
    [CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
    param()
    $PSReadline = ( $null -ne $(Get-Module PSReadline -ea SilentlyContinue) )
    $target = if ( $PSReadline ) { "entire command history, including from previous sessions" } else { "command history" }
    if ( -not $pscmdlet.ShouldProcess($target) ) { return }
    if ( $PSReadline ) {
        Clear-Host
        # Remove PSReadline's saved-history file.
        if ( Test-Path (Get-PSReadlineOption).HistorySavePath ) {
            # Abort, if the file for some reason cannot be removed.
            Remove-Item -ea Stop (Get-PSReadlineOption).HistorySavePath
            # To be safe, we recreate the file (empty).
            $null = New-Item -Type File -Path (Get-PSReadlineOption).HistorySavePath
        }
        # Clear PowerShell's own history
        Clear-History
        [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
    } else {
        # Without PSReadline, we only have a *session* history.
        Clear-Host
        Clear-History
    }
}
Function Get-MySecret {
    param(
        [String]$Name = "MyAdminCred"
    )
    Unlock-MySecret
	(Get-Secret $Name).getnetworkcredential().password.Trim() | Set-Clipboard
}
Function Hosts: { Set-Location 'C:\windows\system32\drivers\etc' }
Function MessKit: { Set-Location 'C:\GitHub\MessKit' }
Function MessLab: { Set-Location 'C:\GitHub\MessLab' }
Function Unlock-MySecret {
    Unlock-SecretStore -Password (ConvertTo-SecureString -AsPlainText -Force (Unprotect-CmsMessage -Path 'C:\mygithub\MyVault\Data\MyVault.cms')) -PasswordTimeout 28800
}
# Drive shortcuts
function HKLM:  { Set-Location HKLM: }
function HKCU:  { Set-Location HKCU: }
function Env:   { Set-Location Env: }
#endregion

#region IsAdmin
## Find out if the current user identity is elevated (has admin rights)
$IsAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
## Set PSSession variables for use when running under normal user creds
if (-not($IsAdmin)) {
    Unlock-MySecret
    $MyAdminCred = (Get-Secret -Name 'MyAdminCred' -Vault 'MyVault')
    $MyUserCred = (Get-Secret -Name 'MyUserCred' -Vault 'MyVault')
}
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
        } ElseIf ($PWD.Path -ne $Item) {
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
    # Write PS> for desktop PowerShell, pwsh> for PowerShell Core
    if ($isDesktop) {
        Write-Host "ps>" -NoNewLine -ForegroundColor $fgColor
    } else {
        Write-Host "pwsh>" -NoNewLine -ForegroundColor $fgColor
    }
    return " "
}
#endregion
