#region Set default values for Git
# Examples:
# git config --global --unset user.name
# git config --global --remove-section user

git config --global color.ui 'auto'
git config --global color.branch.current 'yellow bold'
git config --global color.branch.local 'green bold'
git config --global color.branch.remote 'cyan bold'
git config --global color.diff.meta 'yellow bold'
git config --global color.diff.frag 'magenta bold'
git config --global color.diff.old 'red bold'
git config --global color.diff.new 'green bold'
git config --global color.diff.whitespace 'red reverse'
git config --global color.status.added 'green bold'
git config --global color.status.changed 'yellow bold'
git config --global color.status.untracked 'red bold'

git config --global core.editor 'code --wait'

git config --global init.defaultBranch 'main'

git config --global fetch.prune 'true'

#git config --global github.user 'clemmesserli'
#git config --global github.token 'token'

git config --global status.short 'true'

git config --global url.'https://github.com/'.insteadOf 'gh:'
git config --global url.'https://gist.github.com/'.insteadOf 'gist:'
git config --global url.'https://bitbucket.org/'.insteadOf 'bb:'

git config --global user.email 'clemmesserli@gmail.com'
git config --global user.name 'Clem Messerli'
git config --global user.username 'cmesserli'

git config --global web.browser 'google-chrome'
#endregion

#region Create Local folder and clone repos
New-Item -Path C:\github -ItemType Directory -Force
Set-Location 'C:\GitHub'
git clone gh:clemmesserli/MessKit.git
#endregion