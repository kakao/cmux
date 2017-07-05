module CMUX
  module Commands
    # CM API Synchronizer
    class Sync
      extend Commands

      # Command properties
      CMD   = 'sync'.freeze
      ALIAS = ''.freeze
      DESC  = 'CM API Synchronizer.'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt        = build_opts
        @cmlist     = Utils.cm_config
        @cmux_data  = Utils.new_rec_hash
        @hosts      = Utils.new_rec_hash
        @roles      = Utils.new_rec_hash
        @services   = Utils.new_rec_hash
      end

      # Run command
      def process
        Utils.awaiter(message: 'Fetching CM API resources  ') do
          @cmlist.pmap do |cm, cm_props|
            user     = cm_props['user']
            password = cm_props['password']
            port     = cm_props['port'] || 7180
            use_ssl  = cm_props['use_ssl'] || false
            base_url = "#{cm}:#{port}"
            base_url.prepend(use_ssl ? 'https://' : 'http://')
            run_sync(cm, base_url, user, password)
          end
          hosts_not_registed_in_any_clusters
          write_to_file
        end
      end

      private

      # Run sync
      def run_sync(cm, base_url, user, password)
        cm_ver(cm, base_url, user, password)
        api_base_url = "#{base_url}/api/#{cm_api_ver(cm)}"
        psync(cm, api_base_url, user, password)
        services(cm, api_base_url, user, password)
        roles(cm, api_base_url, user, password)
        cl_hosts(cm, api_base_url, user, password)
      end

      # Write CMUX data to file
      def write_to_file
        File.open(CMUX_DATA, 'w') do |file|
          file.write Marshal.dump(@cmux_data)
        end
      end

      # The version of Cloudera Manager
      def cm_ver(cm, base_url, user, password)
        url = "#{base_url}/api/v9/cm/version"
        res = API.get_req(url: url, user: user, password: password,
                          sym_name: true)
        @cmux_data[cm].merge!(version: res[:version], cmUrl: base_url)
      rescue StandardError => e
        raise CMAPIError, "#{cm}: #{e.message}", e.backtrace
      end

      # Parallel Sync
      def psync(cm, api_base_url, user, password)
        %w[clusters hosts cms_roles].pmap do |func|
          send func, cm, api_base_url, user, password
        end
      end

      # Clusters
      def clusters(cm, api_base_url, user, password)
        url      = "#{api_base_url}/clusters"
        clusters = API.get_req(url: url, user: user, password: password,
                               props: :items, sym_name: true)
        clusters.map { |cluster| merge_clusters(cm, cluster) }
      rescue StandardError => e
        raise CMAPIError, "#{cm}: #{e.message}", e.backtrace
      end

      # Merge clusters to CMUX data
      def merge_clusters(cm, cl)
        @cmux_data.dig(cm, :cl, cl[:name]).merge!(
          displayName:  cl[:displayName],
          version:      cl[:fullVersion]
        )
      end

      # Hosts
      def hosts(cm, api_base_url, user, password)
        url   = "#{api_base_url}/hosts?view=full"
        hosts = API.get_req(url: url, user: user, password: password,
                            props: :items, sym_name: true)
        hosts.map { |host| build_host_data(cm, host) }
      rescue StandardError => e
        raise CMAPIError, "#{cm}: #{e.message}", e.backtrace
      end

      # Build host data
      def build_host_data(cm, host)
        @hosts.dig(cm, :hosts, host[:hostId]).merge!(
          hostname:     host[:hostname],
          ipAddress:    host[:ipAddress],
          hostUrl:      host[:hostUrl],
          rackId:       host[:rackId],
          hostHealth:   host[:healthSummary]
        )
      end

      # Roles of the Cloudera Management Services
      def cms_roles(cm, api_base_url, user, password)
        url      = "#{api_base_url}/cm/service/roles"
        roles    = API.get_req(url: url, user: user, password: password,
                               props: :items, sym_name: true)
        base_url = api_base_url.split('/').first
        roles.map { |role| build_cms_roles_data(cm, base_url, role) }
      rescue StandardError => e
        raise CMAPIError, "#{cm}: #{e.message}", e.backtrace
      end

      # Build CMS roles
      def build_cms_roles_data(cm, base_url, role)
        @roles.dig(cm, :roles, role[:hostRef][:hostId], role[:name]).merge!(
          roleType:     role[:type],
          roleSType:    ROLE_TYPES[role[:type]],
          roleUrl:      role[:roleUrl],
          roleHealth:   role[:healthSummary],
          serviceName:  role[:serviceRef][:serviceName],
          roleMOwners:  role[:maintenanceOwners].join(','),
          serviceType:  'MGMT',
          serviceUrl:   "#{base_url}/cmf/serviceRedirect/mgmt"
        )
      end

      # Services registered in the clusters
      def services(cm, api_base_url, user, password)
        @cmux_data.dig(cm, :cl).keys.pmap do |cl|
          url      = "#{api_base_url}/clusters/#{cl}/services"
          services = API.get_req(url: url, user: user, password: password,
                                 props: :items, sym_name: true)
          services.map { |service| build_service_data(cm, cl, service) }
        end
      rescue StandardError => e
        raise CMAPIError, "#{cm}: #{e.message}", e.backtrace
      end

      # Build service data
      def build_service_data(cm, cl, service)
        @services.dig(cm, :cl, cl, :services, service[:name]).merge!(
          type:       service[:type],
          serviceUrl: service[:serviceUrl]
        )
      end

      # Roles of a given service
      def roles(cm, api_base_url, user, password)
        @services.dig(cm, :cl).pmap do |cl, cl_props|
          cl_props[:services].pmap do |service, service_props|
            url   = "#{api_base_url}/clusters/#{cl}/services/#{service}/roles"
            roles = API.get_req(url: url, user: user, password: password,
                                props: :items, sym_name: true)
            roles.map { |role| build_role_data(cm, service_props, role) }
          end
        end
      rescue StandardError => e
        raise CMAPIError, "#{cm}: #{e.message}", e.backtrace
      end

      # Build role data
      def build_role_data(cm, service, role)
        @roles.dig(cm, :roles, role.dig(:hostRef, :hostId), role[:name]).merge!(
          roleType:     role[:type],
          roleUrl:      role[:roleUrl],
          roleSType:    role_stype(role),
          roleHealth:   role[:healthSummary],
          roleHAStatus: role_ha_status(role),
          roleMOwners:  role[:maintenanceOwners].join(','),
          serviceName:  role[:serviceRef][:serviceName],
          serviceType:  service[:type],
          serviceUrl:   service[:serviceUrl]
        )
      end

      # Build short role type
      def role_stype(role)
        case role[:type]
        when 'SERVER'   then role_stype_zk(role)
        when *HA_RTYPES then role_stype_ha(role)
        else ROLE_TYPES[role[:type]] || role[:type]
        end
      end

      # Build sort role type for HA_RTYPES
      def role_stype_ha(role)
        case role[:haStatus]
        when 'ACTIVE'  then "#{ROLE_TYPES[role[:type]]}(A)"
        when 'STANDBY' then "#{ROLE_TYPES[role[:type]]}(S)"
        else "#{ROLE_TYPES[role[:type]]}(-)"
        end
      end

      # BUilf short role type for zookeeper
      def role_stype_zk(role)
        case role[:zooKeeperServerMode]
        when 'REPLICATED_LEADER'   then "#{ROLE_TYPES[role[:type]]}(L)"
        when 'REPLICATED_FOLLOWER' then "#{ROLE_TYPES[role[:type]]}(F)"
        when 'STANDALONE'          then "#{ROLE_TYPES[role[:type]]}(S)"
        else "#{ROLE_TYPES[role[:type]]}(-)"
        end
      end

      # Build roleHAStatus
      def role_ha_status(role)
        role[:haStatus] || role[:zooKeeperServerMode] || '-'
      end

      # Hosts associated with the cluster
      def cl_hosts(cm, api_base_url, user, password)
        @cmux_data.dig(cm, :cl).keys.pmap do |cl|
          url      = "#{api_base_url}/clusters/#{cl}/hosts"
          cl_hosts = API.get_req(url: url, user: user, password: password,
                                 props: :items, sym_name: true)
          cl_hosts.flat_map(&:values).map do |host|
            merge_to_cmux(cm, cl, host)
          end
        end
      rescue StandardError => e
        raise CMAPIError, "#{cm}: #{e.message}", e.backtrace
      end

      # Merge data to CMUX
      def merge_to_cmux(cm, cl, host)
        merge_host_to_cmux(cm, cl, host)
        merge_roles_to_cmux(cm, cl, host)
        delete_temp_host(cm, host)
      end

      # Merge host data to CMUX
      def merge_host_to_cmux(cm, cl, host)
        @cmux_data.dig(cm, :cl, cl, :hosts)[host] = @hosts.dig(cm, :hosts, host)
      end

      # Merge role data to CMUX
      def merge_roles_to_cmux(cm, cl, host)
        role_stypes, role_health, role_m_owners = pull_role_data(cm, host)

        @cmux_data.dig(cm, :cl, cl, :hosts, host).merge!(
          roles:       @roles.dig(cm, :roles, host),
          roleSTypes:  role_stypes,
          roleSHealth: role_health,
          roleMOwners: role_m_owners
        )
      end

      # Pull role data
      def pull_role_data(cm, host)
        label = %I[roleSType roleHealth roleMOwners]
        @roles.dig(cm, :roles, host).values.map do |h|
          h.values_at(*label)
        end.transpose
      end

      # Delete host data from temporary hash(@hosts)
      def delete_temp_host(cm, host)
        @hosts.dig(cm, :hosts).delete(host)
        @hosts.delete(cm) if @hosts.dig(cm, :hosts).empty?
      end

      # Host are not registed in any clusters
      def hosts_not_registed_in_any_clusters
        @hosts.pmap do |cm, _|
          @cmux_data.dig(cm, :cl, "\u00A0").merge!(
            displayName: "\u00A0",
            version:     "\u00A0",
            hosts:       @hosts.dig(cm, :hosts)
          )
        end
      end

      # The last version of the Cloudera Manager
      def cm_api_ver(cm)
        Utils.version_map(CM_API_MAP, @cmux_data[cm][:version])
      end

      # Build command options
      def build_opts
        opt = CHK::OptParser.new
        opt.banner(CMD, ALIAS)
        opt.separator('Options:')
        opt.help_option
        opt.parse
      end
    end
  end
end
