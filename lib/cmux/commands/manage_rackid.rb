module CMUX
  module Commands
    # Shows how the rackID(s) is allocated in CM and updates rackID(s).
    class ManageRackID
      extend Commands

      # Command properties.
      CMD   = 'manage-rackid'.freeze
      ALIAS = 'rackid'.freeze
      DESC  = 'Shows how the rackID(s) is allocated in CM and updates ' \
              'rackID(s).'.freeze

      # Regist command.
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command.
      def process
        Utils.do_if_sync(@opt[:sync])
        list    = filter_list
        details = filter_details(list[2])
        print_rackmap(list, details)
        update_rackid(details[2].tap(&:shift))
      end

      private

      ROLES     = %w[ZK JN NN HM RM DN].freeze
      LABEL     = %I[cm cl cl_disp rackid].freeze
      LABEL_DTL = %I[cm cl_disp hostname role_stypes rackid hostid].freeze

      # Filter list.
      def filter_list
        header = TABLE_HEADERS.values_at(*LABEL).concat(ROLES)
        title  = "Allocated Role(s) in rack. Select to view details:\n" \
                 "  ZK : Zookeeper\n" \
                 "  JN : Journal Node\n" \
                 "  NN : Name Node\n" \
                 "  HM : HMaster\n" \
                 "  RM : Yarn Resource Manager\n" \
                 "  DN : Data Node\n".red
        table  = build_rackmap_table(header)
        fzfopt = "#{@opt[:query]} --header='#{title}' --with-nth=1,3.."

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map!(&:split)

        [title, header, selected]
      end

      # Build CMUX table.
      def build_rackmap_table(header)
        rackmap = build_rackmap
        body    = rackmap.map { |rack, roles| rack + count_roles(roles) }.sort
        FMT.table(header: header, body: body, rjust: (4..10).to_a)
      end

      # Build rackmap.
      def build_rackmap
        rackmap = Hash.new { |k, v| k[v] = Hash.new(0) }
        CM.hosts.each do |h|
          rack = h.values_at(*LABEL)
          h[:role_stypes].map { |role| rackmap[rack][role] += 1 }
        end
        rackmap
      end

      # Count roles.
      def count_roles(roles)
        ROLES.map do |role|
          roles.select { |r, _| r.split('(').first == role }
               .map(&:last).reduce(:+) || 0
        end.map(&:to_s)
      end

      # Filter details.
      def filter_details(list)
        title  = "Select host(s) to which you want to assign rackId :\n".red
        header = TABLE_HEADERS.values_at(*LABEL_DTL)
        table  = build_dtable(list, header)
        fzfopt = "--with-nth=..-2 --header='#{title}'"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map!(&:split)

        [title, header, selected]
      end

      # Build CMUX table.
      def build_dtable(list, header)
        Utils.awaiter(message: 'Loading  ', smcup: true) do
          body = list.map do |e|
            CM.hosts.map do |h|
              [h[:cm], h[:cl], h[:rackid]].eql?(e.values_at(0, 1, 3)) || next
              h[:role_stypes] = h[:role_stypes].uniq.sort.join(',')
              h.values_at(*LABEL_DTL)
            end
          end.reduce(:+).compact
          FMT.table(header: header, body: body)
        end
      end

      # Print rackmap.
      def print_rackmap(map, details)
        title, header, body = map
        list = FMT.table(header: header, body: body, rjust: (4..10).to_a)
        puts title, list

        title, header, body = details
        body = body.unshift(header).map { |e| e[0...-1] }
        list = FMT.table(header: body.shift, body: body)
        puts "\n", title, list, "\n"
      end

      # Check whether to update RackID.
      def q_update_rackid
        msg = '> Do you want to update these rack ID (y|n)? '
        exit unless CHK.yn?(msg.cyan)

        msg    = "> Enter a new rack ID (must start with '/'): "
        rackid = Utils.qna(msg.cyan) until rackid && rackid[0] == '/'

        msg = "> Do you want to update with '#{rackid}' (y|n)? "
        exit unless CHK.yn?(msg.cyan)

        rackid
      end

      # Update rackid to the Cloudera Manager.
      def update_rackid(list)
        rackid = q_update_rackid
        maxes = list.transpose.map { |g| g.map(&:length).max }

        puts
        print_format = "%-#{maxes[2]}s %-#{maxes[4]}s\n"
        printf print_format, 'Hostname', 'Update to'
        puts "#{'-' * (maxes[2])} #{'-' * (maxes[4] + rackid.length + 8)}"

        print_format = "%-#{maxes[2]}s " \
                       "%-#{maxes[4]}s  =>  \e[31m%-#{rackid.length}s\e[m\n"

        list.each do |e|
          begin
            host = CM.hosts.find { |k| k[:cm] == e[0] && k[:hostname] == e[2] }

            if rackid == host[:rackid]
              printf print_format, host[:hostname], host[:rackid], 'DO NOTHING'
            else
              update_host_rackid(host, rackid)
              printf print_format, host[:hostname], host[:rackid], rackid
            end
          rescue StandardError => e
            print_format = "%-#{maxes[2]}s %-#{maxes[4]}s\n"
            printf print_format, host[:hostname], "[Error] #{e.message}"
          end
        end
      end

      # Update rackid of host.
      def update_host_rackid(host, rackid)
        url = "#{host[:cm_url]}/api/#{host[:cm_api_ver]}/hosts/#{host[:hostid]}"
        body = JSON.generate('rackId' => rackid)
        headers = { 'Content-Type' => 'application/json' }
        user, password = Utils.cm_config(host[:cm])
                              .values_at('user', 'password')

        API.put_req(url:      url,
                    body:     body,
                    headers:  headers,
                    user:     user,
                    password: password)
      end

      # Build command options
      def build_optss(opt)
        opt.banner(CMD, ALIAS)
        opt.separator('Options:')
        opt.sync_option
        opt.query_option
        opt.help_option
        opt.parse
      end

      # Build command options.
      def build_opts
        opt = CHK::OptParser.new
        build_optss(opt)
      end
    end
  end
end
