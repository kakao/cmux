module CMUX
  module Utils
    # Cloudera Manager
    module CM
      class << self
        # Select Cloudera Manager
        def select_cm(args = {})
          title  = "#{args[:title]}Select Cloudera Manager:\n".red
          header = ['', 'Cloudera Manager', 'Description']
          body   = Utils.cm_config.map.with_index do |(k, v), i|
            [(i + 1).to_s, k, v['description'] || ' ']
          end
          args[:all] && body.unshift(['0', 'All', ''])

          table  = FMT.table(header: header, body: body, rjust: [0])
          fzfopt = "+m --tiebreak=begin --header-lines=2 --header='#{title}'"
          fzfopt += " --no-clear #{args[:fzf_opt]}"

          selected = Utils.fzf(list: table, opt: fzfopt)
          Utils.exit_if_empty(selected, 'No items selected')
          selected.map { |e| e.split(' ')[1] }.shift
        end

        # All clusters
        def clusters(cms = nil)
          label = %I[cm cm_ver cm_url cm_api_ver cl cl_disp cdh_ver]
          CM.hosts(cms).group_by { |h| h.slice(*label) }
            .map { |h, v| h.merge(hosts: v.count.to_s) }
        end

        # All hosts
        def hosts(cms = nil)
          cmux_data ||= Marshal.load(File.read(CMUX_DATA))
          cmux_data.key?(cms) && cmux_data.select! { |k, _| k == cms }
          cmux_data.flat_map do |cm, cm_props|
            cm_gem_ver = Gem::Version.new(cm_props[:version])
            clusters   = cm_props[:cl].select { |_, v| v.key?(:hosts) }
            clusters.flat_map do |cl, cl_props|
              cl_props[:hosts].map do |h, h_props|
                {
                  cm:            cm,
                  cm_ver:        cm_props[:version],
                  cm_api_ver:    Utils.version_map(CM_API_MAP, cm_gem_ver),
                  cm_url:        cm_props[:cmUrl],
                  cl:            cl,
                  cl_disp:       cl_props[:displayName],
                  cdh_ver:       cl_props[:version],
                  hostid:        h,
                  hostname:      h_props[:hostname],
                  ipaddress:     h_props[:ipAddress],
                  rackid:        h_props[:rackId],
                  host_health:   h_props[:hostHealth],
                  host_url:      h_props[:hostUrl],
                  role_stypes:   h_props[:roleSTypes] || ['-'],
                  roles:         h_props[:roles] || {},
                  role_health:   h_props[:roleSHealth] || []
                }
              end
            end
          end
        end

        # Retrieves a specific CM REST resource.
        def get_cm_rest_resource(cm, resource, props = nil)
          user, password = get_user_pass(cm)
          host = yield
          url  = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}#{resource}"
          API.get_req(url: url, user: user, password: password, props: props,
                      sym_name: true)
        rescue CMUXConfigError
          raise
        rescue StandardError => e
          raise CMAPIError, e.message
        end

        # Retrieves the Cloudera Manager settings.
        def get_cm_config(cm)
          resource = '/cm/config?view=full'
          get_cm_rest_resource(cm, resource, :items) do
            CM.hosts.find { |h| h[:cm] == cm }
          end
        end

        # Retrieves the configuration of a specific service.
        def get_service_config(cm, cl, service_name)
          resource = "/clusters/#{cl}/services/#{service_name}/config?view=full"
          get_cm_rest_resource(cm, resource, :items) do
            CM.hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          end
        end

        # Retrieves the configuration of a specific role.
        def get_role_config(cm, cl, service_name, role_name)
          resource = "/clusters/#{cl}/services/#{service_name}" \
                     "/roles/#{role_name}/config?view=full"
          get_cm_rest_resource(cm, resource, :items) do
            CM.hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          end
        end

        # Retrieves user and password of the Cloudera Manager from cm.yaml.
        def get_user_pass(cm)
          res = Utils.cm_config(cm).values_at('user', 'password')
          if res.include?(nil)
            raise CMUXConfigError, "#{cm}: 'user' and 'password'"
          end
          res
        end

        # Finds the host to which the roles are assigned.
        def find_host_with_any_role(cm, cl, *roles)
          CM.hosts.find do |host|
            host[:cm] == cm && host[:cl] == cl &&
              (host[:role_stypes] & roles).any?
          end
        end

        # Finds the Active NameNode of a specific cluster.
        def find_nn_active(cm, cl)
          find_host_with_any_role(cm, cl, 'NN(A)')
        end

        # Finds the Zookeeper Leader of a specific cluster.
        def find_zk_leader(cm, cl)
          find_host_with_any_role(cm, cl, 'ZK(L)', 'ZK(S)')
        end

        # The Zookeeper Leader of a specific cluster.
        def zk_leader(cm, cl)
          find_zk_leader(cm, cl)[:hostname]
        end

        # Retrieves zookeeper client port.
        def zk_port(cm, cl, zk)
          role_name, props = CM.role_of_role_type(zk, 'ZOOKEEPER', 'SERVER')
          service_name     = props[:serviceName]
          role_config = get_role_config(cm, cl, service_name, role_name)
          port = role_config.find { |config| config[:name] == 'clientPort' }
          port[:value] || port[:default]
        end

        # Finds the Active HMaster of a specific cluster.
        def find_hm_active(cm, cl)
          find_host_with_any_role(cm, cl, 'HM(A)')
        end

        # The Active HMaster of a specific cluster.
        def hm_active(cm, cl)
          find_hm_active(cm, cl)[:hostname]
        end

        # Retrieves SECURITY_REALM of the Cloudera Manager.
        def security_realm(cm)
          realm = get_cm_config(cm).find do |config|
            config[:name] == 'SECURITY_REALM'
          end
          realm[:value] || realm[:default]
        end

        # Returns a role details for a specific role type running on this host.
        def role_of_role_type(cmhost, service_type, role_type)
          cmhost[:roles].find do |_, v|
            v[:serviceType] == service_type && v[:roleType] == role_type
          end
        end

        # Returns a service name for a specific role type running on this host.
        def service_name_of_role_type(cmhost, service_type, role_type)
          role = role_of_role_type(cmhost, service_type, role_type)
          role[1][:serviceName]
        end

        # Checks that kerberos authentication is enabled.
        def kerberos_enabled?(cm, cl, config_name)
          service_name = yield
          service_config = get_service_config(cm, cl, service_name)
          service_config.find do |config|
            config[:name] == config_name && config[:value] == 'kerberos'
          end
        end

        # Checks that the kerberos authentication for hbase is enabled.
        def hbase_kerberos_enabled?(cm, cl)
          hm_active    = find_hm_active(cm, cl)
          service_type = 'HBASE'
          role_type    = 'MASTER'
          config_name  = 'hbase_security_authentication'
          kerberos_enabled?(cm, cl, config_name) do
            service_name_of_role_type(hm_active, service_type, role_type)
          end
        end

        # Checks that the kerberos authentication for hadoop is enabled.
        def hadoop_kerberos_enabled?(cm, cl)
          nn_active    = find_nn_active(cm, cl)
          service_type = 'HDFS'
          role_type    = 'NAMENODE'
          config_name  = 'hadoop_security_authentication'
          kerberos_enabled?(cm, cl, config_name) do
            service_name_of_role_type(nn_active, service_type, role_type)
          end
        end

        # The HA status of the role
        def ha_status(cm, cl, role)
          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          service, role_type = role.split('-').values_at(0, 1)
          host = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url  = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                 "/clusters/#{cl}/services/#{service}/roles/#{role}"

          res = API.get_req(url:      url,
                            user:     user,
                            password: password,
                            sym_name: true)

          ha_type = role_type == 'SERVER' ? :zooKeeperServerMode : :haStatus
          res[ha_type]
        rescue StandardError => e
          raise CMAPIError, e.message
        end

        # Check the HA status of the role
        def check_ha_status(cm, cl, role)
          status = nil
          msg    = 'Wait for HA status to become active'

          (1..4).cycle.each do |i|
            status = ha_status(cm, cl, role)
            print "\r#{FMT.cur_dt} "
            print "#{msg.ljust(msg.length).red} #{SPIN[i % 4]}"
            break unless status.nil?
            sleep 1
          end
          puts "\b "
          FMT.puts_str("  └── #{'OK'.green} #{status}", true)
        end

        # Change the maintenance mode status of the role
        def change_maintenance_mode_status_role(cm, cl, role, flag)
          msg = flag ? 'Enter maintenance mode' : 'Exit maintenance mode'
          FMT.puts_str(msg.red, true)

          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          service = role.split('-')[0]
          cmd     = flag ? 'enterMaintenanceMode' : 'exitMaintenanceMode'
          host    = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url     = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                    "/clusters/#{cl}/services/#{service}/roles/#{role}" \
                    "/commands/#{cmd}"
          headers = { 'Content-Type' => 'application/json' }

          API.post_req(url:      url,
                       user:     user,
                       password: password,
                       headers:  headers)

          begin
            owner = maintenance_owners(cm, cl, role)
            sleep 1
          end until flag == owner.include?('ROLE')

          msg = '└── Maintenance owners: ' + owner.sort.to_s.green
          FMT.puts_str(msg, true)
        rescue StandardError => e
          raise CMAPIError, e.message
        end

        # Put the role into maintenace mode
        def enter_maintenance_mode_role(cm, cl, role)
          change_maintenance_mode_status_role(cm, cl, role, true)
        end

        # Take the role out of maintenace mode
        def exit_maintenance_mode_role(cm, cl, role)
          change_maintenance_mode_status_role(cm, cl, role, false)
        end

        # The maintenance owners of the role
        def maintenance_owners(cm, cl, role)
          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          service = role.split('-')[0]
          host    = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url     = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                    "/clusters/#{cl}/services/#{service}/roles/#{role}"

          API.get_req(url:      url,
                      user:     user,
                      password: password,
                      sym_name: true)[:maintenanceOwners]
        rescue StandardError => e
          raise CMAPIError, e.message
        end

        # The role state
        def role_state(cm, cl, role)
          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          service = role.split('-')[0]
          host    = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url     = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                    "/clusters/#{cl}/services/#{service}/roles/#{role}"

          API.get_req(url:      url,
                      user:     user,
                      password: password,
                      sym_name: true)[:roleState]
        rescue StandardError => e
          raise CMAPIError, e.message
        end

        # Change the role state
        def change_role_state(cm, cl, role, cmd, max_wait)
          msg, state =
            case cmd
            when 'start'   then ["#{cmd.capitalize.red} #{role}", 'STARTED']
            when 'stop'    then ["#{cmd.capitalize.red} #{role}", 'STOPPED']
            when 'restart' then ["#{cmd.capitalize.red} #{role}", 'STARTED']
            end

          FMT.puts_str(msg, true)

          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          service = role.split('-')[0]
          host    = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url     = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                    "/clusters/#{cl}/services/#{service}/roleCommands/#{cmd}"
          headers = { 'Content-Type' => 'application/json' }
          body    = JSON.generate('items' => [role])

          API.post_req(url:      url,
                       user:     user,
                       password: password,
                       body:     body,
                       headers:  headers)

          start_time = Time.now
          (1..4).cycle.each do |i|
            current_state = role_state(cm, cl, role)
            print "\r#{FMT.cur_dt} "
            print "#{current_state.capitalize.ljust(8).red} #{SPIN[i % 4].red}"
            state == current_state && break
            if (Time.now.to_i - start_time.to_i) > max_wait.to_i
              raise CMUXMaxWaitTimeError, max_wait.to_s
            end
            sleep 1
          end
          puts "\b "
        end

        # Restart the role instance
        def restart_role(cm, cl, role, max_wait)
          change_role_state(cm, cl, role, 'restart', max_wait)
        end

        # Stop the role instance
        def stop_role(cm, cl, role, max_wait)
          change_role_state(cm, cl, role, 'stop', max_wait)
        end

        # Start the role instance
        def start_role(cm, cl, role, max_wait)
          change_role_state(cm, cl, role, 'start', max_wait)
        end

        # The Nameservices of the HDFS service
        def nameservices(cm, cl, service)
          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          host = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url  = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                 "/clusters/#{cl}/services/#{service}/nameservices"

          API.get_req(url:      url,
                      user:     user,
                      password: password,
                      sym_name: true)[:items]
        rescue StandardError => e
          raise CMUXNameServiceError if e.message.include?('404 Not Found')
          raise CMAPIError, e.message
        end

        # The Nameservices that are assigned the NameNode
        def nameservices_assigned_nn(cm, cl, role)
          service = role.split('-')[0]
          nns = nameservices(cm, cl, service).map do |n|
            [n[:name], n.dig(:active, :roleName), n.dig(:standBy, :roleName)]
          end
          nns.select { |n| n.include?(role) }.map { |e| e[0] }
        end

        # The two NameNodes in the HA pair for the HDFS Nameservice
        def ha_paired_nn(cm, cl, service, nameservice)
          nn = nameservices(cm, cl, service).find do |n|
            n[:name] == nameservice
          end
          raise CMUXNameServiceHAError if nn.nil?
          [nn.dig(:standBy, :roleName), nn.dig(:active, :roleName)]
        end

        # Failing over NameNode
        def failover_nn(cm, cl, role, nameservice)
          service = role.split('-')[0]

          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          case ha_status(cm, cl, role)
          when 'ACTIVE'
            standby = ha_paired_nn(cm, cl, service, nameservice)[0]
            hostname_a = hostname_this_role_runs(cm, cl, role)
            hostname_s = hostname_this_role_runs(cm, cl, standby)

            msg = 'Failing over NameNode'.red
            FMT.puts_str(msg, true)
            msg = "[#{hostname_a}] #{role} (ACTIVE)"
            FMT.puts_str(msg, true)
            msg = "  => [#{hostname_s}] #{standby} (STANDBY)"
            FMT.puts_str(msg, true)

            host = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
            url  = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                   "/clusters/#{cl}/services/#{service}/commands/hdfsFailover"
            headers = { 'Content-Type' => 'application/json' }
            body    = JSON.generate('items' => [role, standby])

            API.post_req(url:      url,
                         user:     user,
                         password: password,
                         body:     body,
                         headers:  headers)

            msg = 'Wait to complete'
            (1..4).cycle.each do |i|
              print "\r#{FMT.cur_dt} "
              print "#{msg.ljust(msg.length).red} #{SPIN[i % 4]}"
              ha_status(cm, cl, role) == 'STANDBY' && break
              sleep 1
            end
            puts "\b[OK]".green

            msg = "#{hostname_a} is now a STANDBY NameNode"
            FMT.puts_str("  └── #{msg}", true)
          else
            msg = "#{'Skip Failover'.red}: This is NOT a ACTIVE NameNode."
            FMT.puts_str(msg, true)
          end
        end

        # Roll the edits of an HDFS Nameservice
        def hdfs_role_edits(cm, cl, role)
          msg = 'Roll the edits of an HDFS Nameservice'.red
          FMT.puts_str(msg.red, true)

          service = role.split('-')[0]
          cmlist  = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')

          host = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url  = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}" \
                 "/clusters/#{cl}/services/#{service}/commands/hdfsRollEdits"
          headers = { 'Content-Type' => 'application/json' }

          nameservices(cm, cl, service).map do |n|
            body = JSON.generate('nameservice' => n[:name])
            cmd_id = API.post_req(url:      url,
                                  user:     user,
                                  password: password,
                                  body:     body,
                                  sym_name: true,
                                  headers:  headers)[:id]

            msg = 'Wait to complete'
            (1..4).cycle.each do |i|
              print "\r#{FMT.cur_dt}   "
              print "#{msg.ljust(msg.length).red} #{SPIN[i % 4]}"
              command_status(cm, cl, cmd_id)[:success] && break
              sleep 1
            end
            print "\r#{FMT.cur_dt}   "
            puts "#{msg.ljust(msg.length).red} #{'[OK]'.green}"
          end
        rescue StandardError => e
          raise CMAPIError, e.message
        end

        # A detailed information on an asynchronous command
        def command_status(cm, cl, cmd_id)
          cmlist = Utils.cm_config(cm)
          user, password = cmlist.values_at('user', 'password')
          host = hosts.find { |h| h[:cm] == cm && h[:cl] == cl }
          url  = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}/commands/#{cmd_id}"
          API.get_req(url:      url,
                      user:     user,
                      password: password,
                      sym_name: true)
        rescue StandardError => e
          raise CMAPIError, e.message
        end

        # The hostname where this role runs
        def hostname_this_role_runs(cm, cl, role)
          selected = hosts.select { |host| host[:cm] == cm && host[:cl] == cl }
          selected.map do |host|
            host[:roles].keys.map do |r|
              host[:hostname] if role == r
            end
          end.flatten.compact.first
        end

        # Colorize status string
        def colorize_status(status)
          case status
          when 'GOOD'       then status.green
          when 'CONCERNING' then status.yellow
          else status.red
          end
        end
      end
    end
  end
end
