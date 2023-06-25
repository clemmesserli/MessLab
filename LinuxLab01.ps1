New-LabDefinition -Name 'LNXLAB01' -VmPath 'C:\LabVMs' -DefaultVirtualizationEngine HyperV
Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{SwitchType='External';AdapterName='Wi-Fi'}
Add-LabMachineDefinition -Name 'LNXLAB01' -Memory '8GB' -Network 'External' -OperatingSystem 'Ubuntu 22.04.2 LTS "Jammy Jellyfish"'
Install-Lab
Show-LabDeploymentSummary -Detailed

# Need to manually launch machine via Hyper-V to complete installer for now
# Once base image is installed and machine restarted, continue with the following

<#
sudo apt update
sudo apt install ssh
sudo apt install git
sudo apt install ansible-core

ssh-keygen.exe -t ed25519 -C "labadmin"
# accept defaults and set your password

ls ~/.ssh
cat id_ed25519.pub  # copy this to Github SSH Keys to allow ansible-pull to authenticate


git config --global user.email "clemmesserli@gmail.com"
git config --global user.name "clemmesserli"

mkdir ~/github
cd ~/github
git clone git@github.com:clemmesserli/ansible_desktop.git

nano README.md  # make a simple change

git status # should now indicate a change has been made

git commit -a -m 'Updated README with URI'

git push origin main


sudo ansible-pull -i localhost,lnxlab01 -U https://github.com/clemmesserli/ansible_desktop.git
#>

Enter-PSSession -HostName LNXLAB01 -UserName 'LabAdmin' -Password 'P@ssword1'
