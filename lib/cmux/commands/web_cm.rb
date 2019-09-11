module CMUX
  module Commands
    # Open the Cloudera Manager Web Console(s) as the default browser
    class WebCM
      extend Commands

      # Command properties
      CMD   = 'web-cm'.freeze
      ALIAS = 'webcm'.freeze
      DESC  = 'Open the Cloudera Manager Web Console(s) as the default browser'
              .freeze

      # Regist command.
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command
      def process
        Utils.do_if_sync(@opt[:sync])
        urls = select_urls(CM.hosts)
        open_urls(urls)
      end

      private

      LABEL = %I[cm cl_disp serviceType roleType hostname level url].freeze

      # Select URL to open
      def select_urls(hosts)
        title  = "Select to open the Cloudera Manager Console:\n".red
        table  = build_url_table(hosts)
        fzfopt = "--with-nth=..-2 --header='#{title}' #{@opt[:query]}"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # Build CMUX table
      def build_url_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.reject { |h| h[:cl_disp] == "\u00A0" }
                      .flat_map { |host| build_urls(host) }
                      .uniq.sort_by { |e| e.map(&:djust) }
        FMT.table(header: header, body: body)
      end

      # Build URLs
      def build_urls(host)
        [cm_url(host), cl_url(host), host_url(host)] + svc_role_urls(host)
      end

      # CM URL
      def cm_url(host)
        [host[:cm], '-', '-', '-', host[:cm], '[CM]', host[:cm_url]]
      end

      # Cluster URL
      def cl_url(host)
        cl_url = "#{host[:cm_url]}/cmf/clusterRedirect/#{host[:cl]}"
        [host[:cm], host[:cl_disp], '-', '-', '-', '[Cluster]', cl_url]
      end

      # Host URL
      def host_url(host)
        [host[:cm], host[:cl_disp], '-', '-', host[:hostname], '[Host]',
         host[:host_url]]
      end

      # Service & Role URLs
      def svc_role_urls(host)
        host[:roles].values.pmap do |r_props|
          [
            [host[:cm], host[:cl_disp], r_props[:serviceType],
             '-', '-', '[Service]', r_props[:serviceUrl]],
            [host[:cm], host[:cl_disp], r_props[:serviceType],
             r_props[:roleType], host[:hostname], '[Role]', r_props[:roleUrl]]
          ]
        end.flatten(1)
      end

      # Open Cloudera Manager Web Console(s)
      def open_urls(list)
        list.each do |e|
          lvl, url = e.values_at(-2, -1)
          printf "%-20s%s\n", lvl.red, url.red
          Utils.open_url(url)
        end
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
