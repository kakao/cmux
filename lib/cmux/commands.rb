module CMUX
  # Regist new command
  module Commands
    # CMUX commands
    CMDS = CMUX::Utils.new_rec_hash

    # Regist command to CMUX
    def reg_cmd(args = {})
      CMDS[args[:cmd]].merge!(class: self,
                              alias: args[:alias],
                              desc:  args[:desc])
    end
  end
end

require_relative 'commands/rolling_restart'
require_relative 'commands/rolling_restart_hosts'
require_relative 'commands/rolling_restart_roles'
require_relative 'commands/hbase_region_inspector'
require_relative 'commands/hbase_table_stat'
require_relative 'commands/list_clusters'
require_relative 'commands/list_hosts'
require_relative 'commands/manage_cloudera_scm_agent'
require_relative 'commands/manage_rackid'
require_relative 'commands/shell_hbase'
require_relative 'commands/shell_impala'
require_relative 'commands/ssh_cm_hosts'
require_relative 'commands/sync'
require_relative 'commands/tmux_window_splitter'
require_relative 'commands/web_cm'
require_relative 'commands/web_service'
