# miq_sprint_statistics

## Setup
- On the github UI, go to your settings page, select "Personal access tokens", Generate a new token, give it a name, no scopes are required, save, copy the token id
- Clone the repo
- Edit closed_issues.rb, paste your token ID change the milestone ID if necessary
```bundle install```

## Usage
```
$ bundle exec ruby closed_issues.rb

Milestone Statistics for: Sprint 42 Ending June 20, 2016
AUTHOR,ASSIGNEE,LABELS
--------------------------------------------------
bdunne,chessbyte,providers/ansible_tower refactoring ui
```
