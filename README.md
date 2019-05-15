# sprint_statistics

These rb files were created to capture statistics for use during sprint reviews and to collect information for creating changelogs for individual repositories.  prs_per_repo.rb and closed_issues.rb generate csv files with the output.  

## Setup
- On the github UI, go to your settings page, select "Personal access tokens", Generate a new token, give it a name, no scopes are required, save, copy the token id
- Clone the repo
- Edit closed_issues.rb or prs_per_repo.rb, paste your token ID & change the milestone ID if necessary
```bundle install```

(If you're only interested in the prs_per_repo on a couple repos, you can add an additional section in the config.yaml for included_repos and change the ```repos_to_track``` method inside of merged_prs_per_sprint.rb to only use those repos.)

## Usage
```
$ bundle exec ruby closed_issues.rb

Milestone Statistics for: Sprint 42 Ending June 20, 2016
NUMBER,AUTHOR,ASSIGNEE,LABELS
--------------------------------------------------
12345,bdunne,chessbyte,providers/ansible_tower refactoring ui
```

```
$ bundle exec ruby prs_per_repo.rb
...
Collecting pull_requests for: ManageIQ/manageiq-automation_engine
  Closed/Unmerged: ["https://github.com/ManageIQ/manageiq-automation_engine/pull/57", "https://github.com/ManageIQ/manageiq-automation_engine/pull/53", "https://github.com/ManageIQ/manageiq-automation_engine/pull/27"]
  Closed/Merged: ["https://github.com/ManageIQ/manageiq-automation_engine/pull/61"]
  Closed/Merged Labels: {"bug"=>1, "euwe/backported"=>1, "fine/backported"=>1}
Collecting pull_requests for: ManageIQ/manageiq-content
  ERROR: https://github.com/ManageIQ/manageiq-content/pull/138 is missing a Milestone!!!
  Closed/Unmerged: []
  Closed/Merged: ["https://github.com/ManageIQ/manageiq-content/pull/169", "https://github.com/ManageIQ/manageiq-content/pull/168", "https://github.com/ManageIQ/manageiq-content/pull/167", "https://github.com/ManageIQ/manageiq-content/pull/166", "https://github.com/ManageIQ/manageiq-content/pull/162", "https://github.com/ManageIQ/manageiq-content/pull/138"]
  Closed/Merged Labels: {"enhancement"=>2, "fine/backported"=>3, "bug"=>2, "test"=>1, "documentation"=>1, "services"=>1, "euwe/backported"=>1}
Collecting pull_requests for: ManageIQ/manageiq-design
  Closed/Unmerged: []
  Closed/Merged: []
  Closed/Merged Labels: {}
...

$ cat prs_per_repo.csv
Pull Requests from: 2017-08-08 00:00:00 UTC to: 2017-08-22 00:00:00 UTC.  repo,#opened,#merged,closed_bug,closed_enhancement,closed_developer,closed_documentation,closed_performance,closed_refactoring,closed_technical debt,closed_test,#remaining_open
Ansible/ansible_tower_client_ruby,1,1,1,1,0,0,0,0,0,0,2
ManageIQ/FireBreath,0,0,0,0,0,0,0,0,0,0,0
ManageIQ/WinRM,1,0,0,0,0,0,0,0,0,0,1
ManageIQ/actionwebservice,1,0,0,0,0,0,0,0,0,0,1
ManageIQ/active_bugzilla,0,0,0,0,0,0,0,0,0,0,1
ManageIQ/activerecord-id_regions,0,0,0,0,0,0,0,0,0,0,0
...
```
