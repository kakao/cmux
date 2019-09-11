module CMUX
  module Commands
    # List hosts
    class ListHosts
      extend Commands

      # Command properties
      CMD   = 'list-hosts'.freeze
      ALIAS = 'lh'.freeze
      DESC  = 'List hosts'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command
      def process
        Utils.do_if_sync(@opt[:sync])
        query = @opt[:query] && @opt[:query].split(' ')
        return print_preview(*query.values_at(1, 3)) if @opt[:preview]
        hosts = select_hosts(CM.hosts)
        print_list(hosts)
      end

      private

      LABEL     = %I[cm cl_disp hostname ipaddress role_stypes rackid].freeze
      LABEL_PRV = %I[serviceType roleType roleHealth roleMOwners].freeze

      # Select host(s) to print
      def select_hosts(hosts)
        title  = "Press ctrl-p to open preview window.\n\n" \
                 "Select Host(s):\n".red
        table  = build_host_table(hosts)
        fzfopt = "#{@opt[:query]} --header='#{title}'" \
                 " --bind 'ctrl-p:toggle-preview'" \
                 " --preview 'cmux list-hosts --preview -q {}'" \
                 ' --preview-window right:35%:hidden'

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # Build CMUX table
      def build_host_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.map do |host|
          host[:role_stypes] = host[:role_stypes].uniq.sort.join(',')
          host.values_at(*LABEL)
        end
        body.sort_by! { |e| e.map(&:djust) }
        FMT.table(header: header, body: body)
      end

      # Print selected list
      def print_list(hosts)
        title  = "Hosts(s):\n".red
        header = TABLE_HEADERS.values_at(*LABEL)
        table  = FMT.table(header: header, body: hosts.map(&:clone))
        puts title, table
      end

      # Print preview
      def print_preview(cm, hostname)
        host = CM.hosts.find { |h| h[:cm] == cm && h[:hostname] == hostname }
        preview_host(host)
        preview_cm(host)
        preview_cl(host)
        preview_roles(host)
      end

      # Print the details of the host
      def preview_host(host)
        puts host[:hostname].red
        puts "  Status   : #{CM.colorize_status(host[:host_health])}"
        puts "  RackID   : #{host[:rackid]}"
      end

      # Print the details of the Cloudera Manager
      def preview_cm(host)
        puts "\n* CM"
        puts "  Host     : #{host[:cm]}"
        puts "  CM Ver   : #{host[:cm_ver]}"
      end

      # Print the details of the Cluster
      def preview_cl(host)
        puts "\n* Cluster"
        puts "  Name     : #{host[:cl]}"
        puts "  Disp     : #{host[:cl_disp]}"
        puts "  CDH Ver  : #{host[:cdh_ver]}"
      end

      # Print the details of roles
      def preview_roles(host)
        puts " \n* Roles "
        return if host[:roles].empty?

        header = TABLE_HEADERS.values_at(*LABEL_PRV)
        body = host[:roles].map do |_, r_props|
          r_props[:roleHealth] = CM.colorize_status(r_props[:roleHealth])
          r_props.values_at(*LABEL_PRV)
        end
        table = FMT.table(header: header, body: body, strip_ansi: false)
        table.each { |e| puts '  ' + e }
      end

      # Check command options
      def chk_opts(opt)
        opts = opt.parse
        if opts[:preview] && !opts[:query]
          raise CMUXInvalidArgumentError, '-p, --preview'
        end
        opts
      rescue CMUXInvalidArgumentError => e
        puts "cmux: #{CMD}: #{e.message}\n".red
        Utils.exit_with_msg(opt.parser, false)
      end

      # Build command options
      def build_opts
        opt = CHK::OptParser.new
        opt.banner(CMD, ALIAS)
        opt.separator('Options:')
        opt.sync_option
        opt.query_option
        opt.help_option
        opt.preview_option
        chk_opts(opt)
      end
    end
  end
end
