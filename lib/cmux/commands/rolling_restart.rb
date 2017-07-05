module CMUX
  module Commands
    # Rolling Restart
    class RollingRestart
      extend Commands

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command
      def process
        Utils.do_if_sync(@opt[:sync])
      end

      LABEL = %I[cm cl cl_disp cdh_ver hosts].freeze

      # Check to continue
      def continue?(message)
        @interactive ? CHK.yn?(message.cyan, true) : true
      end

      # Select cluster to rolling restart
      def select_cl(title)
        cm = CM.select_cm(title: "#{title}\n\n")

        title  = "#{title}\n\nSelect Cluster (only 1):\n".red
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = CM.clusters(cm).map { |c| c.values_at(*LABEL) }
                   .sort_by { |c| c.map(&:djust) }
        table  = FMT.table(header: header, body: body, rjust: [3, 4])
        fzfopt = "+m --header='#{title}' --no-clear"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.flat_map(&:split)
      end

      # Check the host where RegionServer runs
      def include_rs?(hosts)
        hosts.values.map { |e| e[:role_stype] }
             .uniq.join(',').split(',').include?('RS')
      end

      # Print cluster
      def print_cluster(cm, cl, cl_disp, cdh_ver)
        print_format = " * %-16s : %s\n"
        printf print_format, 'Cloudera Manager', cm
        printf print_format, 'Cluster', "[#{cl}] #{cl_disp}"

        print_format = "   %16s : %s\n"
        printf print_format, '    CDH Version', cdh_ver
      end

      # Print service
      def print_service(service_type, service)
        print_format = " * %-16s : %s\n"
        printf print_format, 'Service', "[#{service_type}] #{service}"
      end

      # Print 'hbase-manager'
      def print_hbase_manager(cm, cl, cdh_ver)
        zk = CM.zk_leader(cm, cl)
        hbase_manager = Utils.ht4cdh(tool: 'hbase-manager', cdh_ver: cdh_ver)

        print_format = "   %16s : %s\n"
        printf print_format, '     Zookeeper  ', zk
        printf print_format, '     hbase-tool ', hbase_manager
      end

      # Print role type
      def print_role_type(role_type)
        print_format = " * %-16s : %s\n"
        printf print_format, 'Role Type', role_type
      end

      # Print roles
      def print_roles(cm, cl, roles)
        return if roles && roles.empty?

        print_format = " * %-16s\n"
        printf print_format, 'Roles'
        print_format = "%+7s %s\n"

        roles.each.with_index(1) do |r, idx|
          role_type, hostname, role = r.values_at(0, 2, 3)
          tree   = roles.length == idx ? '└──' : '├──'
          status = CM.ha_status(cm, cl, role) if CHK_RTYPES.include?(role_type)
          printf print_format, tree, "[#{hostname}] #{role} #{status}"
        end
      end

      # Print hosts
      def print_hosts(hosts)
        printf " * %-16s\n", 'Hosts'

        hosts.map do |host, h_props|
          printf "   %s\n", host
          h_props[:roles].values.map.with_index(1) do |r_props, idx|
            tree = h_props[:roles].length == idx ? '└──' : '├──'
            printf "%+8s %-20s %-20s\n",
                   tree, r_props[:roleType], r_props[:roleHAStatus]
          end
        end
      end

      # Set how to run rolling restart
      def set_batch_execution_condition
        q_rolling_restart
        set_batch_interval
        set_max_wait_time
        set_interactive_mode
      end

      # Check whether to run rolling restart
      def q_rolling_restart
        q = 'Are you sure you want to ROLLING RESTART on the above ' \
            'roles (y|n)? '
        Utils.exit_with_msg('STOPPED'.red, true) unless CHK.yn?(q.cyan, true)
      end

      # Set seconds to sleep betwenn batches
      def set_batch_interval
        q = 'Set SECONDS TO SLEEP between batches (>= 0 secs): '
        until @interval && @interval.to_i >= 0
          @interval = Utils.qna(q.cyan, true)
        end
      end

      # Set the max wait time for 'RESTART' command
      def set_max_wait_time
        q = 'Set the MAX WAIT TIME after executing the RESTART command ' \
            '(>= 180 secs): '
        until @max_wait && @max_wait.to_i > 179
          @max_wait = Utils.qna(q.cyan, true)
        end
      end

      # Check whether to proceed with interactive mode
      def set_interactive_mode
        q = 'Do you want to proceed with INTERACTIVE MODE (y|n)? '
        @interactive = CHK.yn?(q.cyan, true)
        @hm_opts     = '--move-async'
        @hm_opts.concat(' --force-proceed') unless @interactive
      end

      # Prepare to rolling restart for RegionServer
      def prepare_rolling_restart_for_rs(cm, cl, role_type)
        return unless role_type == 'REGIONSERVER'
        Utils.turn_off_auto_balancer(cm, cl)
        @exp_file = %(/tmp/#{cm}_#{cl}_#{Time.new.strftime('%Y%m%d%H%M%S')}.exp)
        Utils.export_rs(cm, cl, @exp_file)
      end

      # Print 'restart' message of the host
      def print_restart_host_msg(hostname)
        msg = "#{'Restart'.red} all roles on #{hostname.yellow}"
        FMT.puts_str(msg, true)
      end

      # Print 'restart' message of the role
      def print_restart_role_msg(hostname, role)
        msg = 'Restart '.red + "[#{hostname}] #{role}".yellow
        FMT.puts_str(msg, true)
      end

      # Print 'stop' message of the role
      def print_stop_role_msg(hostname, role)
        msg = 'Stop '.red + "[#{hostname}] #{role}".yellow
        FMT.puts_str(msg, true)
      end

      # Print 'start' message of the role
      def print_start_role_msg(hostname, role)
        msg = 'Start '.red + "[#{hostname}] #{role}".yellow
        FMT.puts_str(msg, true)
      end

      # Prepare to restart role
      def before_restart_role(cm, cl, hostname, role_type, role)
        CM.enter_maintenance_mode_role(cm, cl, role)

        case role_type
        when 'REGIONSERVER'
          Utils.empty_rs(cm, cl, hostname, @exp_file, @hm_opts)
        when 'NAMENODE'
          nns = CM.nameservices_assigned_nn(cm, cl, role)
          nns.each { |nn| CM.failover_nn(cm, cl, role, nn) }
        end
      end

      # Finalize the restart operation
      def after_restart_role(cm, cl, hostname, role_type, role)
        case role_type
        when 'REGIONSERVER'
          Utils.import_rs(cm, cl, hostname, @exp_file, @hm_opts)
        when 'JOURNALNODE'
          CM.hdfs_role_edits(cm, cl, role)
        when *CHK_RTYPES
          CM.check_ha_status(cm, cl, role)
        end
        CM.exit_maintenance_mode_role(cm, cl, role)
      end

      # Wait to interval
      def wait_to_interval(idx, obj_length)
        return if idx == obj_length
        msg = "Waiting up #{@interval} secondes to next batch: "
        FMT.print_str(msg, true)
        print format '%8s', ' '
        Utils.countdown(@interval.to_i)
      end

      # Finish rolling restart
      def finish_rolling_restart(cm, cl, role_type)
        if role_type == 'REGIONSERVER'
          q = 'Do you want to turn on auto balancer (y|n)? '
          Utils.turn_on_auto_balancer(cm, cl) if CHK.yn?(q.cyan, true)
        end

        FMT.puts_str('Finish'.red, true)
      end
    end
  end
end
