module CMUX
  module Commands
    # Rolling restart roles
    class RollingRestartRoles < RollingRestart
      # Command properties.
      CMD   = 'rolling-restart-roles'.freeze
      ALIAS = 'rrr'.freeze
      DESC  = 'Rolling restart roles.'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Run command
      def process
        super
        role_type = select_role_type
        roles     = select_role(role_type)
        print_the_selection(role_type, roles)
        set_batch_execution_condition
        rolling_restart(role_type, roles)
      end

      private

      LABEL = %I[cm cl cl_disp serviceType roleType cdh_ver serviceName
                 cl_secured].freeze

      # Select role type to rolling restart
      def select_role_type
        cm, cl = select_cl('ROLLING RESTART ROLES').values_at(0, 1)

        title  = "ROLLING RESTART ROLES\n" \
                 "  * Cloudera Manager : #{cm}\n\n" \
                 "Select the ROLE TYPE :\n".red
        hosts  = CM.hosts(cm).select { |host| host[:cl] == cl }
        table  = build_role_type_table(hosts)
        fzfopt = "+m --with-nth=3..-4 --header='#{title}' --no-clear"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.flat_map(&:split)
      end

      # Build CMUX table
      def build_role_type_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.flat_map do |host|
          roles = select_rr_roles(host)
          roles.values.map do |role|
            [host.values_at(*LABEL), role.values_at(*LABEL)]
              .transpose.map(&:compact).flatten
          end
        end
        Utils.exit_if_empty(body, 'Empty Roles')
        body.uniq!.sort_by! { |e| e.map(&:djust) }
        FMT.table(header: header, body: body)
      end

      # Select to run rolling restart for this role type
      def select_rr_roles(host)
        host[:roles].select { |_, r| run_rr?(r[:roleType]) }
      end

      # Check to run rolling restart for this role type
      def run_rr?(role_type)
        RR_EXCEPT_ROLES.include?(role_type) ? false : true
      end

      # Select role to rolling restart
      def select_role(role_type)
        cm, cl, cl_disp, s_type, r_type, _, service = role_type

        title = "ROLLING RESTART ROLES\n" \
                "  * Cloudera Manager : #{cm}\n" \
                "  * Cluster          : [#{cl}] #{cl_disp}\n" \
                "  * Service type     : #{s_type}\n" \
                "  * Role type        : #{r_type}\n\n"

        case r_type
        when 'NAMENODE'
          title  = "#{title}Select Nameservice :\n".red
          header = ['Name Service', 'Active', '-', 'StandBy', '-']
          nn     = CM.nameservices(cm, cl, service)
                     .select { |n| n.key?(:activeFailoverController) }
          body   = nn.map do |n|
            [n[:name],
             CM.hostname_this_role_runs(cm, cl, n[:active][:roleName]),
             n[:active][:roleName],
             CM.hostname_this_role_runs(cm, cl, n[:standBy][:roleName]),
             n[:standBy][:roleName]]
          end

          raise CMUXNameServiceHAError if body.empty?

          table  = FMT.table(header: header, body: body)
          fzfopt = "+m --with-nth=1,2,4 --header='#{title}'"

          selected = Utils.fzf(list: table, opt: fzfopt)
          Utils.exit_if_empty(selected, 'No items selected')

          selected.map(&:split).flat_map do |e|
            [[r_type, e[0], e[3], e[4]], [r_type, e[0], e[1], e[2]]]
          end
        else
          title  = "#{title}Select ROLE(s) :\n".red
          header = ['Role Type', 'Role Type(short)', 'Hostname', 'Rolename']
          hosts  = CM.hosts.select { |host| host[:cm] == cm }
          body   = hosts.flat_map do |host|
            roles = host[:roles].select do |_, r_props|
              host[:cl] == cl && r_props[:roleType] == r_type
            end
            roles.map do |r, r_props|
              [r_type, r_props[:roleSType], host[:hostname], r]
            end
          end
          body.sort_by! { |e| e.map(&:djust) }

          table  = FMT.table(header: header, body: body)
          fzfopt = "--with-nth=2.. --header='#{title}'"

          selected = Utils.fzf(list: table, opt: fzfopt)
          Utils.exit_if_empty(selected, 'No items selected')
          selected.map(&:split)
        end
      rescue CMUXNameServiceError, CMUXNameServiceHAError => err
        print_the_selection(role_type, [])
        Utils.exit_with_msg("[#{cm}] #{cl}: #{err.message}".red, false)
      end

      # Print selected roles
      def print_the_selection(role_type, roles)
        cm, cl, cl_disp, s_type, r_type, cdh_ver, service, secured = role_type

        puts 'ROLLING RESTART ROLES'.red
        FMT.horizonal_splitter('-')

        print_cluster(cm, cl, cl_disp, cdh_ver, secured)
        print_service(s_type, service)
        print_hbase_manager(cm, cl, cdh_ver)
        print_role_type(r_type)
        print_roles(cm, cl, roles)

        FMT.horizonal_splitter('-')
      end

      # Perform rolling restart
      def rolling_restart(role_type, roles)
        cm, cl, r_type = role_type.values_at(0, 1, 4)
        prepare_rolling_restart_for_rs(cm, cl, r_type)

        roles.each.with_index(1) do |r, idx|
          hostname, role = r.values_at(2, 3)
          print_restart_role_msg(hostname, role)

          if continue?('Continue (y|n:stop)? ')
            before_restart_role(cm, cl, hostname, r_type, role)
            CM.restart_role(cm, cl, role, @max_wait)
            after_restart_role(cm, cl, hostname, r_type, role)
            wait_to_interval(idx, roles.length)
          else
            Utils.exit_with_msg('STOPPED'.red, true)
          end
        end
      ensure
        finish_rolling_restart(cm, cl, r_type)
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
