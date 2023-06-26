#region Install Extensions
$extensions = @(
    "ms-vscode.PowerShell"                             #PowerShell Syntax Highlighting
    "ms-vscode-remote.remote-wsl"                      #WSL Remote inside Windows VSCode
    "esbenp.prettier-vscode"                           #Prettier – Code formatter
    #"f5devcentral.vscode-f5"                           #The F5 Extension
    #"bitwisecook.irule"                                #F5 Networks iRules
    "redhat.ansible"                                   #Ansible
    "redhat.vscode-yaml"                               #YAML
    "ms-vscode-remote.remote-wsl"                      #VS Code in WSL
    "vscode-icons-team.vscode-icons"                   #Folder icons
    "hilleer.yaml-plus-json"                           #Convert YAML <-> JSON
    #"streetsidesoftware.code-spell-checker"            #Code Spell Checker
    "aaron-bond.better-comments"                       #Improve In-Line Comments
    "emilast.logfilehighlighter"                       #Improve LogFile Readability
    "oderwat.indent-rainbow"                           #Vertical indention highlighter
    "johnpapa.vscode-peacock"                          #Highlight different workspaces
    "htmlhint.vscode-htmlhint"                         #HTML syntax checker
    "zignd.html-css-class-completion"                  #CSS intellisense
    "dbaeumer.vscode-eslint"                           #Javascript/Typescripy syntax checker
    "graphql.vscode-graphql"                           #Graphql sytax highlighter
    "ms-vscode-remote.remote-ssh"                      #Remote SSH
    "grapecity.gc-excelviewer"                         #View xls/csv files in vscode
    "chrmarti.regex"                                   #Preview regex capture within vscode
    "DavidAnson.vscode-markdownlint"                   #Markdown syntax checker
    "bierner.emojisense"                               #Emoji intellisense
    "deerawan.vscode-faker"                            #Random info generator
    "andyyaldoo.vscode-json"                           #Json formatter
)

foreach ($extension in $extensions) {
    Write-Host "`nInstalling extension [$extension]" -ForegroundColor Yellow
    code --install-extension $extension
}
#endregion

#region Populate settings.json
$settingsPath = 'C:\Users\LabAdmin\AppData\Roaming\Code\User\settings.json'
$data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/vscode/settings.json'
$data | ConvertTo-Json -Depth 20 | Out-File $settingsPath -Encoding utf8
#endregion
