[cmdletBinding()]
param(
    [pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
    [string]$ComputerName = "L1PC101",
    [Parameter(Position = 0, HelpMessage = 'The path to a configuration data file')]
    [ValidateScript({ Test-Path -Path $_ })]
   	[string]$data = "$PSScriptRoot\labs\data\basic.json"
)

$LabSession = New-PSSession -Credential $Credential -ComputerName $ComputerName -Name MessLab

#region WindowsFeatures
# Invoke-Command -Session $LabSession -ScriptBlock {
#     dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
#     dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
# }
#endregion WindowsFeatures

#region AppxPackages
$SoftwarePackages = Get-ChildItem "$LabSources\SoftwarePackages" -Include "*.appx", "*.msixbundle" -Recurse
$SoftwarePackages | ForEach-Object -ThrottleLimit 5 -Parallel {
    Copy-Item -Path $PSItem.FullName -Destination
}
Invoke-Command -Session $LabSession -ScriptBlock {
    foreach ($pckg in $Using:SoftwarePackages) {
        powershell -noprofile Add-AppxPackage "C:\LabSources\$pckg"
    }
}
#endregion AppxPackages

#region NuGet/PSGet
Invoke-Command -Session $LabSession -ScriptBlock {
    $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    Install-PackageProvider -Name NuGet -MinimumVersion $($nugetProvider.version.tostring()) -ForceBootstrap -Force

    # Get the latest versions from the PowerShell Gallery
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PowerShellGet
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Microsoft.PowerShell.PSResourceGet
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Pester
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PSReadLine
}
#endregion NuGet/PSGet

$data = Get-Content .\data\apps.json | ConvertFrom-Json
$data = Import-PowerShellDataFile -Path $ConfigurationData -ErrorAction Stop

#region Winget
Invoke-Command -Session $LabSession -ScriptBlock {
    # Example: winget search vscode
    #winget install --source winget --accept-source-agreements --accept-package-agreements --name "Microsoft Visual Studio Code Insiders"

    #winget install --source msstore --accept-source-agreements --accept-package-agreements --name "AutoHotkey Store Edition"
    winget install --source msstore --accept-source-agreements --accept-package-agreements --name "Power Automate"
}
#endregion Winget

#region Chocolately
Invoke-Command -Session $LabSession -ScriptBlock {
    # First download and install the choco app
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Next grab some choco packages
    $packages = @(
        "git"
        "powershell-core"
        "vscode"
    )

    for ($i = 0; $i -lt $packages.count; $i++) {
        Write-Progress -Activity "Installing Choco Packages" -Status "$i% Complete:" -PercentComplete $i
        choco install $packages[$i] -y
        Start-Sleep -Milliseconds $(Get-Random -Minimum 50 -Maximum 150)
    }
}
#endregion Chocolatey

#region PSGallery
Invoke-Command -Session $LabSession -ScriptBlock {
    $modules = @(
        "Microsoft.PowerShell.SecretManagement"
        "Microsoft.PowerShell.SecretStore"
        "Pester"
        "PSReadLine"
        "PSReadlineHistory"
    )
    Foreach ($module in $modules) {
        Write-Host "Installing $module" -ForegroundColor Green
        Install-Module -Repository 'PSGallery' -Scope AllUsers -AllowClobber -SkipPublisherCheck -Force -Name $module -Verbose
    }
    Restart-Computer -Force
}
#endregion PSGallery

Start-Sleep -Seconds 45
$LabSession = New-PSSession -Credential $credential -ComputerName $ComputerName -Name MessLab

#region VSCode
Invoke-Command -Session $LabSession -ScriptBlock {
    $extensions = @(
        "esbenp.prettier-vscode"                           #Prettier – Code formatter
        "DavidAnson.vscode-markdownlint"                   #Markdown syntax checker
        "ms-vscode-remote.remote-wsl"                      #WSL Remote inside Windows VSCode
        "ms-vscode.PowerShell"                             #PowerShell Syntax Highlighting
        "vscode-icons-team.vscode-icons"                   #Folder icons
    )

    foreach ($extension in $extensions) {
        Write-Host "`nInstalling extension [$extension]" -ForegroundColor Yellow
        code --install-extension $extension
    }

    $settingsPath = 'C:\Users\LabAdmin\AppData\Roaming\Code\User\settings.json'
    $data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/vscode/settings.json'
    $data | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
}
#endregion VSCode

#region GIT
Invoke-Command -Session $LabSession -ScriptBlock {
    git config --global user.email 'clemmesserli@messlabs.com'
    git config --global user.name 'Clem Messerli'
    git config --global user.username 'cmesserli'
    git config --global url.'https://github.com/'.insteadOf 'gh:'
    git config --global url.'https://gist.github.com/'.insteadOf 'gist:'
    git config --global url.'https://bitbucket.org/'.insteadOf 'bb:'

    New-Item -Path C:\github -ItemType Directory -Force
    Set-Location 'C:\GitHub'
    git clone gh:clemmesserli/MessKit.git
}
#endregion GIT

#region PSProfile
Invoke-Command -Session $LabSession -ScriptBlock {
    #download pre-built sample from github
    $data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/powershell/profile.ps1'
    $data | Out-File 'C:\github\profile.ps1' -Encoding utf8

    #loop through common PSProfile paths and create a stub or shortcut linking back to our local file above
    $files = @(
        "$($env:onedrive)\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        "$($env:onedrive)\Documents\PowerShell\Microsoft.PowerShellISE_profile.ps1"
        "$($env:onedrive)\Documents\PowerShell\profile.ps1"
        "$($env:onedrive)\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        "$($env:onedrive)\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"
        "$($env:onedrive)\Documents\WindowsPowerShell\profile.ps1"

        "$($env:OneDriveConsumer)\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        "$($env:OneDriveConsumer)\Documents\PowerShell\Microsoft.PowerShellISE_profile.ps1"
        "$($env:OneDriveConsumer)\Documents\PowerShell\profile.ps1"
        "$($env:OneDriveConsumer)\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        "$($env:OneDriveConsumer)\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"
        "$($env:OneDriveConsumer)\Documents\WindowsPowerShell\profile.ps1"
    )
    foreach ($file in $files) {
        Set-Content -Value '. C:\github\profile.ps1' -Path "$file" -Force -ErrorAction SilentlyContinue
    }
}
#endregion PSProfile


#region SecretsMgmt
Invoke-Command -Session $LabSession -ScriptBlock {
    #Ref: https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules
    ## exported to an XML file and encrypted by Windows Data Protection (DPAPI)
    ## (Protect-CmsMessage leveraging a certificate is what I prefer as it is more portable)
    $securePasswordPath = "C:\LabSources\PSVault.xml"
    $using:credential.Password |  Export-Clixml -Path $securePasswordPath

    Register-SecretVault -Name 'PSVault' -ModuleName 'Microsoft.PowerShell.SecretStore' -DefaultVault
    $password = Import-Clixml -Path $securePasswordPath

    $storeConfiguration = @{
        Authentication  = 'Password'
        PasswordTimeout = 3600 # 1 hour
        Interaction     = 'None'
        Password        = $password
        Confirm         = $false
    }
    Set-SecretStoreConfiguration @storeConfiguration

    # Import the masterkey and unlock vault
    $password = Import-Clixml -Path $securePasswordPath
    Unlock-SecretStore -Password $password

    # Create a secret
    Set-Secret -Name "MyAuthToken" -Secret "AL+PS=Automation" -Vault "PSVault"

    # Get the secret value
    $myAuthToken = Get-Secret -Name "MyAuthToken" -AsPlainText
    Write-Output "Your Secret Is: [$myAuthToken]"
}
#endregion SecretsMgmt












#region WSL
# Enable nested virtualization
Write-Host "Stopping VM to enable nested virtualization support"
Stop-LabVM -ComputerName $ComputerName -Wait

Get-PSSession | Remove-PSSession

Set-VMProcessor $ComputerName -ExposeVirtualizationExtensions $true
Write-Host "Starting VM back up..." -ForegroundColor Green
Start-LabVM -ComputerName $ComputerName -Wait

$LabSession = New-PSSession -Credential $credential -ComputerName $ComputerName -Name MessLab
Invoke-Command -Session $LabSession -ScriptBlock {
    wsl --set-default-version 2
    wsl --install -d Ubuntu
}
#endregion



#region PowerShellUniversal
# Invoke-Command -Session $LabSession -ScriptBlock {
#     Install-PSUServer
#     Start-Process http://localhost:5000
# }
#endregion PowerShellUniversal

#region Postman
# Invoke-Command -Session $LabSession -ScriptBlock {
#     Start-Process 'C:\Users\LabAdmin\AppData\Local\Postman\postman.exe'
#     Start-Sleep -Seconds 10
#     Stop-Process -Name Postman
# }
#endregion Postman

Write-Host "Performing final restart" -ForegroundColor Green
Restart-LabVM -ComputerName $labName -Wait

Write-Host "Full Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
$Stopwatch.Stop()
Stop-Transcript
#Show-LabDeploymentSummary -Detailed