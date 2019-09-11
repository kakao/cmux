module CMUX
  module Commands
    # Open Service Web Console as the default browser
    class WebService
      extend Commands

      # Command properties
      CMD   = 'web-service'.freeze
      ALIAS = 'websvc'.freeze
      DESC  = 'Open Service Web Console as the default browser'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command
      def process
        Utils.do_if_sync(@opt[:sync])
        role_types = select_role_types
        open_urls(role_types)
      end

      private

      LABEL = %I[cm cl_disp serviceType roleType roleHAStatus hostname].freeze

      # Filter list
      def select_role_types
        title  = "Select the Role Type(s):\n".red
        table  = build_role_type_table(CM.hosts)
        fzfopt = "--header='#{title}' #{@opt[:query]}"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # Build CMUX table
      def build_role_type_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.flat_map do |host|
          roles = select_cmux_support_role_types(host[:roles])
          roles.map do |_, role|
            [host.values_at(*LABEL), role.values_at(*LABEL)]
              .transpose.map(&:compact).flatten
          end
        end
        body.sort_by! { |e| e.map(&:djust) }
        FMT.table(header: header, body: body)
      end

      # Select supported role types
      def select_cmux_support_role_types(roles)
        roles.select { |_, r| ROLE_PORT.keys.map.include?(r[:roleType]) }
      end

      # Open Service Web Console
      def open_urls(role_types)
        role_types.each do |role_type|
          r   = [LABEL, role_type].transpose.to_h
          url = build_url(r)
          puts "[#{r[:cm]}] #{r[:cl_disp]} #{r[:serviceType]} #{r[:roleType]}" \
               "(#{r[:roleHAStatus]})".red
          puts "  => #{url}"
          Utils.open_url(url)
        end
      end

      # Build URLs
      def build_url(role_type)
        "http://#{role_type[:hostname]}:#{ROLE_PORT[role_type[:roleType]]}"
      end

      # Build command options
      def build_opts
        opt = CHK::OptParser.new
        opt.banner(CMD, ALIAS)
        opt.separator('Options:')
        opt.sync_option
        opt.query_option
        opt.help_option
        opt.parse
      end
    end
  end
end
