$Stopwatch = [System.Diagnostics.Stopwatch]::new()
$Stopwatch.Start()

$labName = 'L2WIN10'
$adminUser = 'LabAdmin'
$adminPassword = 'P@ssword1'
$logFile = "C:\LabSources\$labName.txt"

if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}
Start-Transcript $logFile

# Create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -VmPath "C:\LabVMs" -DefaultVirtualizationEngine HyperV

# Create network switch that allows for internet access
$netConfig = @{
    Name             = 'External'
    HyperVProperties = @{
        SwitchType  = 'External'
        AdapterName = 'Wi-Fi'
    }
}
Add-LabVirtualNetworkDefinition @netConfig

# Create default user credential
Set-LabInstallationCredential -Username $adminUser -Password $adminPassword

# Our one and only machine with nothing on it
$machine1 = @{
    Name            = $labName
    Memory          = '12GB'
    OperatingSystem = 'Windows 10 Enterprise Evaluation'
    Network         = 'External'
}
Add-LabMachineDefinition @machine1

Install-Lab
Write-Host "Base Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green

#region Create LabSources directory
Invoke-LabCommand -ComputerName $labName -ActivityName "Create LabSources Directory" -ScriptBlock {
    New-Item -Path C:\LabSources -ItemType Directory
} -PassThru
#endregion

# Copy shared files to all VMs
Copy-LabFileItem -ComputerName $labName -Path 'C:\LabSources\SoftwarePackages\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx' -DestinationFolderPath 'C:\Tools'
Copy-LabFileItem -ComputerName $labName -Path 'C:\LabSources\SoftwarePackages\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle' -DestinationFolderPath 'C:\Tools'

# # Install Windows Terminal
# Invoke-LabCommand -ComputerName $labName -ActivityName "Install Windows Terminal" -ScriptBlock {
#     Invoke-Expression -Command "powershell Add-AppxPackage C:\tools\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx"
#     Invoke-Expression -Command "powershell Add-AppxPackage C:\tools\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle"
# } -PassThru

# #region Chocolately
# Invoke-LabCommand -ComputerName $labName -ActivityName 'Install Chocolatey' -ScriptBlock {
#     Set-ExecutionPolicy Bypass -Scope Process -Force
#     [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
#     Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
# } -PassThru

# Invoke-LabCommand -ComputerName $labName -ActivityName 'Install Choco Packages' -ScriptBlock {
#     $packages = @(
#         "firefox",
#         "git",
#         "googlechrome",
#         "microsoft-edge",
#         "notepadplusplus",
#         "postman",
#         "powershell-core",
#         "rdmfree",
#         "vscode"
#     )
#     $Total = $packages.Count
#     $Count = 0
#     $packages | ForEach-Object {
#         $Count++
#         Write-Host "Installing $_ ($Count of $Total)" -ForegroundColor Yellow
#         choco install $_ -y
#         RefreshEnv.cmd
#         # Add a randomized sleep value to reduce chance of being blocked
#         Start-Sleep -Seconds $(Get-Random -Minimum 1 -Maximum 10)
#     }
# } -PassThru
# #endregion

# #region Install a pre-downloaded application
# Copy-LabFileItem -ComputerName $labName -Path "$labSources\SoftwarePackages\BraveBrowserSetup.exe" -DestinationFolderPath "C:\Tools"
# Install-LabSoftwarePackage -ComputerName $labName -LocalPath "C:\Tools\BraveBrowserSetup.exe" -CommandLine "/Silent /Install" -PassThru
# #endregion

# #region Install Winget
# Copy-LabFileItem -ComputerName $labName -Path "C:\LabSources\SoftwarePackages\Microsoft.UI.Xaml.2.7.appx" -DestinationFolderPath "C:\Tools"
# Copy-LabFileItem -ComputerName $labName -Path "C:\LabSources\SoftwarePackages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -DestinationFolderPath "C:\Tools"
# Invoke-LabCommand -ComputerName $labName -ActivityName "Install Winget" -ScriptBlock {
#     powershell -noprofile Add-AppxPackage "C:\tools\Microsoft.UI.Xaml.2.7.appx"
#     powershell -noprofile Add-AppxPackage "C:\tools\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
# } -PassThru
# #endregion

# #region Install Winget Packages
# $password = $adminPassword | ConvertTo-SecureString -AsPlainText -Force
# $cred = New-Object pscredential($adminUser, $password)

# $session = New-PSSession -ComputerName $labName -Credential $cred
# $command = {
#     $wingetPackages = @(
#         "AutoHotkey Store Edition"
#         "KeePassWin"
#         "Microsoft PowerToys"
#         "Power Automate"
#         "Power BI Desktop"
#         "TreeSize Free"
#     )
#     $wingetPackages | Foreach-Object {
#         winget install --source msstore --accept-source-agreements --accept-package-agreements --name $_
#         Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 5)
#     }
# }
# Invoke-Command -Session $session -ScriptBlock $command
# $session | Remove-PSSession
# #endregion

# #region Enable nested virtualization
# Write-Host "Stopping VM to enable nested virtualization support"
# Stop-LabVM -ComputerName $labName -Wait
# #endregion

# #region Install Ubuntu
# Set-VMProcessor $labName -ExposeVirtualizationExtensions $true
# Write-Host "Starting VM back up..." -ForegroundColor Green
# Start-LabVM -ComputerName $labName -Wait

# Invoke-LabCommand -ComputerName $labName -ActivityName "Install WSL w/ Ubuntu" -ScriptBlock {
#     wsl --install -d Ubuntu
# } -PassThru
# #endregion

# #region Configure default VSCode settings and extensions
# Copy-LabFileItem -ComputerName $labName -Path "C:\LabSources\SoftwarePackages\vscode.ps1" -DestinationFolderPath "C:\tools\"
# Invoke-LabCommand -ComputerName $labName -ActivityName "Initialize VSCode Config" -ScriptBlock {
#     pwsh "C:\tools\vscode.ps1" -Verbose
# } -PassThru
# #endregion

# #region Configure default GIT config settings & download repos
# Copy-LabFileItem -ComputerName $labName -Path "C:\LabSources\SoftwarePackages\git.ps1" -DestinationFolderPath "C:\tools\"
# Invoke-LabCommand -ComputerName $labName -ActivityName "Initialize Git Config" -ScriptBlock {
#     pwsh "C:\tools\git.ps1" -Verbose
# } -PassThru
# #endregion

# #region Configure default profile.ps1 & download add-on modules
# Copy-LabFileItem -ComputerName $labName -Path "C:\LabSources\SoftwarePackages\powershell.ps1" -DestinationFolderPath "C:\tools\"
# Invoke-LabCommand -ComputerName $labName -ActivityName "Install Additional PowerShell Modules" -ScriptBlock {
#     pwsh "C:\tools\powershell.ps1" -Verbose
# } -PassThru
# #endregion

# #region Lauch and Close Postman to clear initial startup prompt
# Invoke-LabCommand -ComputerName $labName -ActivityName "Initialize Postman" -ScriptBlock {
#     Start-Process 'C:\Users\LabAdmin\AppData\Local\Postman\postman.exe'
#     Start-Sleep -Seconds 10
#     Stop-Process -Name Postman
# } -PassThru
# #endregion

# Write-Host "Performing final restart" -ForegroundColor Green
# Restart-LabVM -ComputerName $labName -Wait

Write-Host "Full Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
$Stopwatch.Stop()
Stop-Transcript
#Show-LabDeploymentSummary -Detailed

#Location of lab definition files will be 'C:\ProgramData\AutomatedLab'
# Remove-Lab -Name $labName #-RemoveExternalSwitches