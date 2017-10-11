module CMUX
  module Commands
    # Rolling restart roles of hosts
    class RollingRestartHosts < RollingRestart
      # Command properties
      CMD   = 'rolling-restart-hosts'.freeze
      ALIAS = 'rrh'.freeze
      DESC  = 'Rolling restart roles of hosts.'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Run command
      def process
        super
        cluster = select_cl('ROLLING RESTART HOSTS')
        hosts   = select_hosts(cluster)
        print_the_selection(cluster, hosts)
        set_batch_execution_condition
        rolling_restart(cluster, hosts)
      end

      private

      LABEL = %I[hostname role_stypes].freeze

      # Select hosts to rolling restart
      def select_hosts(cluster)
        cm, cl, cl_disp = cluster.values_at(0..2)

        title  = "ROLLING RESTART HOSTS\n" \
                 "  * Cloudera Manager : #{cm}\n" \
                 "  * Cluster          : [#{cl}] #{cl_disp}\n\n" \
                 "Select Hosts(s):\n".red
        hosts  = CM.hosts(cm).select { |host| host[:cl] == cl }
        table  = build_host_table(hosts)
        fzfopt = "--header='#{title}'"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        attach_roles(selected, hosts)
      rescue CMUXNameServiceError, CMUXNameServiceHAError => err
        print_the_selection(cluster, hosts)
        Utils.exit_with_msg("[#{cm}] #{cl}: #{err.message}".red, false)
      end

      # Build CMUX table
      def build_host_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.map do |host|
          host[:role_stypes] = host[:role_stypes].uniq.sort.join(',')
          host[:roles]       = sort_roles(host[:roles])
          host.values_at(*LABEL)
        end
        body.sort_by! { |e| e.map(&:djust) }
        FMT.table(header: header, body: body)
      end

      # Attach roles to list
      def attach_roles(list, hosts)
        list.flat_map do |e|
          hostname, role_stype = e.split(' ')
          hosts.select { |h| h[:hostname] == hostname }
               .map do |h|
                 [hostname, { role_stype: role_stype,
                              roles:      sort_roles(h[:roles]) }]
               end
        end.to_h
      end

      # Sort roles by a priority
      def sort_roles(roles)
        roles.sort_by do |_, r_props|
          case r_props[:roleType]
          when 'DATANODE' then 99
          when 'REGIONSERVER' then 89
          when 'NODEMANAGER', 'IMPALAD' then 79
          else 0
          end
        end.to_h
      end

      # Print selected hosts
      def print_the_selection(cluster, hosts)
        cm, cl, cl_disp, cdh_ver = cluster.values_at(0..-2)

        puts 'ROLLING RESTART ROLES'.red
        FMT.horizonal_splitter('-')

        print_cluster(cm, cl, cl_disp, cdh_ver)
        print_hbase_manager(cm, cl, cdh_ver) if include_rs?(hosts)
        print_hosts(hosts)

        FMT.horizonal_splitter('-')
      end

      # Perform rolling restart
      def rolling_restart(clusters, hosts)
        cm, cl = clusters.values_at(0, 1)
        role_type = 'REGIONSERVER' if include_rs?(hosts)
        prepare_rolling_restart_for_rs(cm, cl, role_type)
        run_rolling_restart(hosts, cm, cl)
        finish_rolling_restart(cm, cl, role_type)
      end

      # Run rolling restart
      def run_rolling_restart(hosts, cm, cl)
        hosts.each.with_index(1) do |(host, props), idx|
          print_restart_host_msg(host)
          if continue?('Continue (y|n:stop)? ')
            stop_roles(cm, cl, host, props[:roles])
            start_roles(cm, cl, host, props[:roles])
            wait_to_interval(idx, hosts.length)
          else
            Utils.exit_with_msg('STOPPED'.red, true)
          end
        end
      end

      # Stop roles
      def stop_roles(cm, cl, hostname, roles)
        roles.each do |role, props|
          if RR_EXCEPT_ROLES.include?(props[:roleType])
            FMT.puts_str("#{'Skip'.red} [#{hostname}] #{role}", true)
          else
            print_stop_role_msg(hostname, role)
            before_restart_role(cm, cl, hostname, props[:roleType], role)
            CM.stop_role(cm, cl, role, @max_wait)
          end
        end
      end

      # Start roles
      def start_roles(cm, cl, hostname, roles)
        roles.to_a.reverse.to_h.each do |role, props|
          if RR_EXCEPT_ROLES.include?(props[:roleType])
            FMT.puts_str("#{'Skip'.red} [#{hostname}] #{role}", true)
          else
            print_start_role_msg(hostname, role)
            CM.start_role(cm, cl, role, @max_wait)
            after_restart_role(cm, cl, hostname, props[:roleType], role)
          end
        end
      end

      # Build command options
      def build_opts
        opt = CHK::OptParser.new
        opt.banner(CMD, ALIAS)
        opt.separator('Options:')
        opt.sync_option
        opt.help_option
        opt.parse
      end
    end
  end
end
