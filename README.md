# CMUX

CMUX is a set of commands for managing CDH clusters using [Cloudera Manager REST API](http://cloudera.github.io/cm_api).

### Table of contents
* [Limitations and Restrictions](#limitations-and-restrictions)
* [Prerequisites](#prerequisites)
* [How to Install](#how-to-install)
* [How to Upgrade](#how-to-upgrade)
* [Command List](#command-list)
* [How to add or extend commands](#how-to-add-or-extend-commands)
* [Command completion](#command-completion)
* [License](#license)

## Limitations and Restrictions

CMUX is only tested on:
* MAC OS X 10.10(Yosemite) or later
* CentOS 6.6, 7.1, 7.2

Some commands require SSH connection to the managed servers.

## Prerequisites

* [`fzf 0.16.6`](https://github.com/junegunn/fzf)
* [`wget 1.12`](https://www.gnu.org/software/wget)
* [`ruby 2.0`](https://www.ruby-lang.org) or later
* [`tmux 2.1`](https://tmux.github.io) or later
* [`boxes`](http://boxes.thomasjensen.com)(optional)


## How to Install

### Step 1. Run the installation script.

Clone this repository and run install script and follow the instructions.

```
git clone https://github.com/kakao/cmux.git
sh cmux/install/install.sh
```

### Step 2. Write Cloudera Manager Server list on `cm.yaml`.

Write down the list of your Cloudera Manager servers in YAML format and save as `config/cm.yaml`.

##### Sample 1. Simple configuration.
```yaml
# Hostname of Cloudera Manager (FQDN)
cm1.kakao.cmux:
  # Description of this Cloudera Manager
  description: "My Cloudera Manager 2"
  # Cloudera Manager user with "Full Administrator" role
  user: admin
  password: admin
  # Cloudera Manager port
  port: 7180
  # Whether or not to use https protocol
  use_ssl: false
```

##### Sample 2. Full configuration.
```yaml
# Hostname of Cloudera Manager (FQDN)
cm2.kakao.cmux:
  # Description of this Cloudera Manager
  description: "My Cloudera Manager1"
  # Cloudera Manager user with "Full Administrator" role
  user: admin
  password: admin
  # Cloudera Manager port
  port: 7180
  # Whether or not to use https protocol
  use_ssl: false
  # Add the following section if you have services with Kerberos authentication
  service:
    hbase:
      kerberos:
        krb5.conf: ~/cmux/config/cm1_krb5.conf
        keytab:    ~/cmux/config/cm1-hbase.keytab
        principal: hbase  # principal primary
    impala:
      kerberos:
        krb5.conf: ~/cmux/config/cm1_krb5.conf
        keytab:    ~/cmux/config/cm1-impala.keytab
        principal: impala # princiapl primary
```

## After the installation

Reload your shell configuration file and you should be able to see [the list of commands](#command-list) by running `cmux`.

## How to Upgrade

`git pull` and run `install/upgrade.sh`.

## Command List

### `cmux`

: CMUX command list

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Commands:
     example                   exam       Example command
     hbase-region-inspector    hri        Run hbase-region-inspector.
     hbase-table-stat          hts        Run hbase-table-stat.
  ...
     web-cm                 webcm    Open the Cloudera Manager Web Console as the default browser.
  ...

  See 'cmux COMMAND -h' or 'cmux COMMAND --help' to read about a specific subcommand.
  ```

### `hbase-region-inspector`, `hri`

: Run [hbase-region-inspector](https://github.com/kakao/hbase-region-inspector).

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_hri.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      hbase-region-inspector, hri

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -i, --interval N                 Interval (default: 10)
      -h, --help                       Show this message
  ```

### `hbase-table-stat`, `hts`

: Run [hbase-table-stat](https://github.com/kakao/hbase-tools).

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_hts.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      hbase-table-stat, hts

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -i, --interval N                 Interval (default: 10)
      -u, --user HADOOP_USER_NAME      Run this command with specified HADOOP_USER_NAME
      -h, --help                       Show this message
  ```

### `list-clusters`, `lc`

: List clusters

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_list-clusters.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      list-clusters, lc

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -h, --help                       Show this message
      -p, --preview                    (Internal option) Preview mode
  ```

* Press `ctrl-p` to open preview window.

### `list-hosts`, `lh`

: List hosts.

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_list-hosts.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      list-hosts, lh

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -h, --help                       Show this message
      -p, --preview                    (Internal option) Preview mode
  ```

* Press `ctrl-p` to open preview window.

### `manage-cloudera-scm-agent`, `scmagent`

: Run clouder-scm-agent in parallel.

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_manage-cludera-scm-agent.gif" width=100%>

  ```
  cmux COMMAND SCMAGENT_OPTION [OPTIONS]

  Command:
      cloudera-scm-agent, scmagent

  Scmagent options:
      clean_restart     clean_start     condrestart
      hard_restart      hard_stop       restart
      start             status          stop

  Options:
      -s, --sync                       Run with synccm
      -h, --help                       Show this message
      -i, --serial-interval N          Run with interval(sec) in serially. (default: Run in parallel)
  ```

### `manage-rackid`, `rackid`

: Shows how the rackID(s) is allocated in CM and updates rackID(s).

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_rackid.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      manage-rackid, rackid

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -h, --help                       Show this message
  ```

### `rolling-restart-hosts`, `rrh`

: Rolling restart hosts. See Details for [Rolling Restart Hosts](https://github.com/kakao/cmux/wiki/The-steps-to-Rolling-Restart-Hosts)

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      rolling-restart-hosts, rrh

  Options:
      -s, --sync                       Run with synccm
      -h, --help                       Show this message
  ```

> If you want to rolling restart NAMENODE, at least one Nameservice configured by High Availability.

### `rolling-restart-roles`, `rrr`

: Rolling restart roles. See Details for [Rolling Restart Roles](https://github.com/kakao/cmux/wiki/The-steps-to-Rolling-Restart-Roles)

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      rolling-restart-roles, rrr

  Options:
      -s, --sync                       Run with synccm
      -h, --help                       Show this message
  ```

> If you want to rolling restart NAMENODE, at least one Nameservice configured by High Availability.

### `shell-hbase`, `sh`

: Run hbase shell.

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_shell-hbase.gif" width=100%>

* __Usage__

  ```
  [HBASE_SHELL_OPTS] cmux COMMAND [OPTIONS]

  Command:
      shell-hbase, sh

  HBase shell options:
      Extra options passed to the hbase shell.
      e.g. HBASE_SHELL_OPTS=-Xmx2g

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -u, --user HADOOP_USER_NAME      Run this command with specified HADOOP_USER_NAME
      -h, --help                       Show this message
  ```

### `shell-impala`, `si`

: Run Impala shell.

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      shell-impala, si

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -h, --help                       Show this message
  ```

### `ssh-cm-hosts`, `ssh`

: Login via SSH to hosts registered in these Cloudera Managers.

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_ssh-cm-hosts.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      ssh-cm-hosts, ssh

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -h, --help                       Show this message
  ```

* Press `ctrl-p` to open preview window.

### `ssh-tmux`, `tssh`

: Login via SSH to hosts specified in file or list.

*--file option*

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_tssh_file.gif" width=100%>

*--list option*

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_tssh_list.gif" width=100%>

* __Usage__

  ```
  Usage: cmux COMMAND [OPTIONS]

  Command:
      ssh_tmux, tssh

  Options: select only 1
      -f, --file filename              File name where host list is stored
      -l, --list host[ host ...]]      Space separated host list
      -h, --help                       Show this message
  ```

### `sync`

: CM API Synchronizer

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_sync.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      sync,

  Options:
      -h, --help                       Show this message
  ```

### `tmux-window-splitter`, `tws`

: Split tmux window and execute each command in each pane.

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_tmux-window-splitter.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND SHELL_COMMAND [OPTIONS]

  Command:
      tmux-window-splitter, tws

  Shell commands:
      shell_command[ shell_command[ ...]]
      One or more shell commands. Each command is separated by a space and commands
      which contain spaces must be quoted

  Options:
      -h, --help                       Show this message
  ```

### `web-cm`, `webcm`

: Open the Cloudera Manager Web Console as the default browser.

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_web-cm.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      web-cm, webcm

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -h, --help                       Show this message
  ```

### `web-service`, `websvc`
: Open the Service Web Console as the default browser. Only supports the default port.

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_web-service.gif" width=100%>

* __Usage__

  ```
  cmux COMMAND [OPTIONS]

  Command:
      web-service, websvc

  Options:
      -s, --sync                       Run with synccm
      -q, --query query_string         Run fzf with given query
      -h, --help                       Show this message
  ```

* Supported services:
  * NAMENODE
  * MASTER
  * REGIONSERVER
  * RESOURCEMANAGER
  * JOBHISTORY
  * SOLR_SERVER
  * KUDU_MASTER
  * HUE_SERVER
  * OOZIE_SERVER


## How to add or extend commands

Write command class file like `$CMUX_HOME/ext/example.rb` and store into `$CMUX_HOME/ext`.

See details [CMUX Extension](https://github.com/kakao/cmux/wiki/CMUX-Extension).


## Command completion

Supported __only bash completion__ using [fzf](https://github.com/junegunn/fzf).

<img src="https://api-metakage-4misc.kakao.com/dn/hadoopeng/cmux/cmux_bash_completion.gif" width=100%>

cf. An example of the [Command List](#command-list) uses [fzf-tmux](https://github.com/junegunn/fzf/blob/master/bin/fzf-tmux).

# License
This software is licensed under the [Apache 2 license](LICENSE), quoted below.

Copyright 2017 Kakao Corp. <http://www.kakaocorp.com>

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this project except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
