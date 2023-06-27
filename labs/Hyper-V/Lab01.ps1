<#
LAB01 - Pre-Configured Windows 10 Standalone Client w/ Internet
#>

$Stopwatch = [System.Diagnostics.Stopwatch]::new()
$Stopwatch.Start()

# Create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name "Lab01" -VmPath "C:\LabVMs" -DefaultVirtualizationEngine HyperV

# Define our default user credential
Set-LabInstallationCredential -Username "LabAdmin" -Password "P@ssword1"

# Create network switch that allows for internet access
Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{SwitchType = "External"; AdapterName = "Wi-Fi" }

# Define our virtual machine
Add-LabMachineDefinition -Name "L1WIN10" -Memory "6GB" -Network "External" -OperatingSystem "Windows 10 Enterprise Evaluation"

Install-Lab
Write-Host "Base ISO installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green

# Create LabSources directory
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Create LabSources Directory" -ScriptBlock {
    New-Item -Path "C:\LabSources" -ItemType Directory 
} -PassThru

# Copy shared files to all VMs
Copy-LabFileItem -ComputerName "L1WIN10" -Path "bin\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx" -DestinationFolderPath "C:\LabSources"
Copy-LabFileItem -ComputerName "L1WIN10" -Path "bin\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle" -DestinationFolderPath "C:\LabSources"

# Install Windows Terminal
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Install Windows Terminal" -ScriptBlock {
    Invoke-Expression -Command "powershell Add-AppxPackage C:\LabSources\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx"
    Invoke-Expression -Command "powershell Add-AppxPackage C:\LabSources\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle"
} -PassThru

# Install Chocolately Application
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName 'Install Chocolatey' -ScriptBlock {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} -PassThru

# Install Choco packages
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName 'Install Choco Packages' -ScriptBlock {
    $packages = @(
        "firefox",
        "git",
        "googlechrome",
        "microsoft-edge",
        "notepadplusplus",
        "postman",
        "powershell-core",
        "rdmfree",
        "vscode"
    )
    $Total = $packages.Count
    $Count = 0
    $packages | ForEach-Object {
        $Count++
        Write-Host "Installing $_ ($Count of $Total)" -ForegroundColor Yellow
        choco install $_ -y
        RefreshEnv.cmd
        # Add a randomized sleep value to reduce chance of being blocked
        Start-Sleep -Seconds $(Get-Random -Minimum 1 -Maximum 10)
    }
} -PassThru

# Install a pre-downloaded application
Copy-LabFileItem -ComputerName "L1WIN10" -Path "bin\BraveBrowserSetup.exe" -DestinationFolderPath "C:\LabSources"
Install-LabSoftwarePackage -ComputerName "L1WIN10" -LocalPath "C:\LabSources\BraveBrowserSetup.exe" -CommandLine "/Silent /Install" -PassThru

# Install Winget application
Copy-LabFileItem -ComputerName "L1WIN10" -Path "bin\Microsoft.UI.Xaml.2.7.appx" -DestinationFolderPath "C:\LabSources"
Copy-LabFileItem -ComputerName "L1WIN10" -Path "bin\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -DestinationFolderPath "C:\LabSources"
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Install Winget" -ScriptBlock {
    powershell -noprofile Add-AppxPackage "C:\LabSources\Microsoft.UI.Xaml.2.7.appx"
    powershell -noprofile Add-AppxPackage "C:\LabSources\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
} -PassThru

# Install Winget Packages
$password = "P@ssword1" | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object pscredential("LabAdmin", "$password")

$session = New-PSSession -ComputerName "L1WIN10" -Credential $cred
$command = {
    $wingetPackages = @(
        "AutoHotkey Store Edition"
        "KeePassWin"
        "Microsoft PowerToys"
        "Power Automate"
        "Power BI Desktop"
        "TreeSize Free"
    )
    $wingetPackages | Foreach-Object {
        winget install --source msstore --accept-source-agreements --accept-package-agreements --name $_
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 5)
    }
}
Invoke-Command -Session $session -ScriptBlock $command
$session | Remove-PSSession

# Enable nested virtualization
Write-Host "Stopping VM to enable nested virtualization support"
Stop-LabVM -ComputerName $labName -Wait

# Install Ubuntu
Set-VMProcessor "L1WIN10" -ExposeVirtualizationExtensions $true
Write-Host "Starting VM back up..." -ForegroundColor Green
Start-LabVM -ComputerName "L1WIN10" -Wait
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Install WSL w/ Ubuntu" -ScriptBlock {
    wsl --install -d Ubuntu
} -PassThru

# Configure default VSCode settings and extensions
Copy-LabFileItem -ComputerName "L1WIN10" -Path "scripts\vscode.ps1" -DestinationFolderPath "C:\LabSources\"
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Initialize VSCode Config" -ScriptBlock {
    pwsh "C:\LabSources\vscode.ps1" -Verbose
} -PassThru

# Configure default GIT config settings & download repos
Copy-LabFileItem -ComputerName "L1WIN10" -Path "scripts\git.ps1" -DestinationFolderPath "C:\LabSources\"
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Initialize Git Config" -ScriptBlock {
    pwsh "C:\LabSources\git.ps1" -Verbose
} -PassThru

# Configure default profile.ps1 & download add-on modules
Copy-LabFileItem -ComputerName "L1WIN10" -Path "scripts\powershell.ps1" -DestinationFolderPath "C:\LabSources\"
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Install Additional PowerShell Modules" -ScriptBlock {
    pwsh "C:\LabSources\powershell.ps1" -Verbose
} -PassThru

# Launch and Close Postman to clear initial startup prompt
Invoke-LabCommand -ComputerName "L1WIN10" -ActivityName "Initialize Postman" -ScriptBlock {
    Start-Process 'C:\Users\LabAdmin\AppData\Local\Postman\postman.exe'
    Start-Sleep -Seconds 10
    Stop-Process -Name Postman
} -PassThru

Write-Host "Performing final restart" -ForegroundColor Green
Restart-LabVM -ComputerName "L1WIN10" -Wait

Write-Host "Full Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
$Stopwatch.Stop()

Show-LabDeploymentSummary -Detailed

#Location of lab definition files will be 'C:\ProgramData\AutomatedLab'
# Remove-Lab -Name $labName #-RemoveExternalSwitches