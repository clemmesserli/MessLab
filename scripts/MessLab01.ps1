[cmdletBinding()]
param(
    [pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
    [string]$ComputerName = "L1PC10"
)

$LabSession = New-PSSession -Credential $Credential -ComputerName $ComputerName -Name MessLab

#region Install Windows Terminal
Invoke-Command -Session $LabSession -ScriptBlock {
    powershell -noprofile Add-AppxPackage "C:\LabSources\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx"
    powershell -noprofile Add-AppxPackage "C:\LabSources\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle"
}
#endregion

#region Chocolately
Invoke-Command -Session $LabSession -ScriptBlock {
    # First download and install the choco app
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Next grab some choco packages
    $packages = @(
        #"firefox"
        "git"
        "googlechrome"
        #"microsoft-edge"
        #"notepadplusplus"
        "postman"
        "powershell-core"
        "vscode"
    )

    for ($i = 0; $i -le $packages.count; $i++) {
        Write-Progress -Activity "Installing Choco Packages" -Status "$i% Complete:" -PercentComplete $i
        choco install $packages[$i] -y
        Start-Sleep -Milliseconds $(Get-Random -Minimum 50 -Maximum 150)
    }
}
#endregion Chocolatey

#region Install Winget
Invoke-Command -Session $LabSession -ScriptBlock {
    # First download and install the winget app and any dependencies
    powershell -noprofile Add-AppxPackage "C:\LabSources\Microsoft.UI.Xaml.2.8.appx"
    powershell -noprofile Add-AppxPackage "C:\LabSources\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

    # Next we'll install a few more apps using Winget instead of Choco
    winget install --source msstore --accept-source-agreements --accept-package-agreements --name "AutoHotkey Store Edition"
    winget install --source msstore --accept-source-agreements --accept-package-agreements --name "Power Automate"
    #winget install --source msstore --accept-source-agreements --accept-package-agreements --name "Power BI Desktop"
    #winget install --source msstore --accept-source-agreements --accept-package-agreements --name "TreeSize Free"

    winget install --source winget --accept-source-agreements --accept-package-agreements --name "Microsoft Visual Studio Code Insiders"
}
#endregion

#region Configure default profile.ps1 & download add-on modules
Invoke-Command -Session $LabSession -ScriptBlock {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Update-Module PowerShellGet -Force

    #region Initialize PSProfile
    $data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/powershell/profile.ps1'
    $data | Out-File 'C:\github\profile.ps1' -Encoding utf8

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
        try {
            Set-Content -Value '. C:\github\profile.ps1' -Path "$file" -Force -ErrorAction Stop
        } catch {
            Write-Error "$($file) does not exist"
        }
    }
    #endregion
}

Invoke-Command -Session $LabSession -ScriptBlock {
    #region Install Modules
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
    #endregion
}



<#

    #region Setup and Configure Secrets Vault
    #Ref: https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules
    #exported to an XML file and encrypted by Windows Data Protection (DPAPI)
    $securePasswordPath = "C:\LabSources\PSVault.xml"
    $credential.Password |  Export-Clixml -Path $securePasswordPath

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
    Write-Output "Your Secret Is: [$myAuthToken]" -ForegroundColor Green
    #endregion

    #region Install PowerShell Universal Server (http://localhost:5000)
    Install-PSUServer
    Start-Process http://localhost:5000
    #endregion

#>
#endregion

#region Configure default VSCode settings and extensions
Invoke-Command -Session $LabSession -ScriptBlock {
    $settingsPath = 'C:\Users\LabAdmin\AppData\Roaming\Code\User\settings.json'
    $data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/vscode/settings.json'
    $data | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8

    # $extensions = @(
    #     #"aaron-bond.better-comments"                       #Improve In-Line Comments
    #     #"andyyaldoo.vscode-json"                           #Json formatter
    #     #"bierner.emojisense"                               #Emoji intellisense
    #     #"bitwisecook.irule"                                #F5 Networks iRules
    #     #"chrmarti.regex"                                   #Preview regex capture within vscode
    #     #"deerawan.vscode-faker"                            #Random info generator
    #     #"emilast.logfilehighlighter"                       #Improve LogFile Readability
    #     "esbenp.prettier-vscode"                           #Prettier – Code formatter
    #     "DavidAnson.vscode-markdownlint"                   #Markdown syntax checker
    #     #"dbaeumer.vscode-eslint"                           #Javascript/Typescripy syntax checker
    #     #"f5devcentral.vscode-f5"                           #The F5 Extension
    #     #"grapecity.gc-excelviewer"                         #View xls/csv files in vscode
    #     #"graphql.vscode-graphql"                           #Graphql sytax highlighter
    #     #"hilleer.yaml-plus-json"                           #Convert YAML <-> JSON
    #     #"htmlhint.vscode-htmlhint"                         #HTML syntax checker
    #     #"johnpapa.vscode-peacock"                          #Highlight different workspaces
    #     #"ms-vscode-remote.remote-ssh"                      #Remote SSH
    #     "ms-vscode-remote.remote-wsl"                      #WSL Remote inside Windows VSCode
    #     "ms-vscode.PowerShell"                             #PowerShell Syntax Highlighting
    #     #"oderwat.indent-rainbow"                           #Vertical indention highlighter
    #     #"redhat.ansible"                                   #Ansible
    #     #"redhat.vscode-yaml"                               #YAML
    #     #"streetsidesoftware.code-spell-checker"            #Code Spell Checker
    #     "vscode-icons-team.vscode-icons"                   #Folder icons
    #     #"zignd.html-css-class-completion"                  #CSS intellisense
    # )

    # #Start-Process "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension", "esbenp.prettier-vscode", "--force" -Wait
    #code --install-extension "esbenp.prettier-vscode"


    # foreach ($extension in $extensions) {
    #     Write-Host "`nInstalling extension [$extension]" -ForegroundColor Yellow
    #     pwsh code --install-extension $extension "ms-vscode.PowerShell"
    # }
}
#endregion

#region Configure default GIT config settings & download repos
Invoke-Command -Session $LabSession -ScriptBlock {
    git config --global user.email 'clemmesserli@messlabs.com'
    git config --global user.name 'Clem Messerli'
    git config --global user.username 'cmesserli'
    git config --global url.'https://github.com/'.insteadOf 'gh:'
    git config --global url.'https://gist.github.com/'.insteadOf 'gist:'
    git config --global url.'https://bitbucket.org/'.insteadOf 'bb:'

    #region Create Local folder and clone repos
    New-Item -Path C:\github -ItemType Directory -Force
    Set-Location 'C:\GitHub'
    git clone gh:clemmesserli/MessKit.git
}
#endregion



# #region Lauch and Close Postman to clear initial startup prompt
# Invoke-LabCommand -ComputerName $labName -ActivityName "Initialize Postman" -ScriptBlock {
#     Start-Process 'C:\Users\LabAdmin\AppData\Local\Postman\postman.exe'
#     Start-Sleep -Seconds 10
#     Stop-Process -Name Postman
# } -PassThru
# #endregion

# Write-Host "Performing final restart" -ForegroundColor Green
# Restart-LabVM -ComputerName $labName -Wait


#region Install Ubuntu on WSL
## Enable nested virtualization
# Write-Host "Stopping VM to enable nested virtualization support"
# Stop-LabVM -ComputerName $ComputerName -Wait

# Set-VMProcessor $ComputerName -ExposeVirtualizationExtensions $true
# Write-Host "Starting VM back up..." -ForegroundColor Green
# Start-LabVM -ComputerName $ComputerName -Wait

# Get-PSSession | Remove-PSSession

# $LabSession = New-PSSession -Credential $credential -ComputerName $ComputerName -Name MessLab
# Invoke-Command -Session $LabSession -ScriptBlock {
#     wsl --install -d Ubuntu
# }
#endregion


Write-Host "Full Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
$Stopwatch.Stop()
Stop-Transcript
#Show-LabDeploymentSummary -Detailed

#Location of lab definition files will be 'C:\ProgramData\AutomatedLab'
# Remove-Lab -Name $labName #-RemoveExternalSwitches