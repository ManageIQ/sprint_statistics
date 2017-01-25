# sprint_statistics

## Setup
- On the github UI, go to your settings page, select "Personal access tokens", Generate a new token, give it a name, no scopes are required, save, copy the token id
- Clone the repo
- Edit closed_issues.rb or closed_prs_per_repo.rb, paste your token ID & change the milestone ID if necessary
```bundle install```

## Usage
```
$ bundle exec ruby closed_issues.rb

Milestone Statistics for: Sprint 42 Ending June 20, 2016
NUMBER,AUTHOR,ASSIGNEE,LABELS
--------------------------------------------------
12345,bdunne,chessbyte,providers/ansible_tower refactoring ui
```

```
$ bundle exec ruby closed_prs_per_repo.rb
...
Collecting pull_requests closed for: ManageIQ/virtfs-xfs
Collecting pull_requests closed for: ManageIQ/win32-service
Collecting pull_requests closed for: ManageIQ/wrapanapi
Collecting pull_requests closed for: ManageIQ/ziya
Pull Requests closed from: 2017-01-09 00:00:00 UTC to: 2017-01-23 00:00:00 UTC
Ansible/ansible_tower_client_ruby: 10
ManageIQ/FireBreath: 0
ManageIQ/WinRM: 0
ManageIQ/actionwebservice: 0
ManageIQ/active_bugzilla: 0
ManageIQ/activerecord-sqlserver-adapter: 0
ManageIQ/awesome_spawn: 1
ManageIQ/azure-armrest: 2
...
```
