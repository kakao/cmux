module CMUX
  module Commands
    # List clusters
    class ListClusters
      extend Commands

      # Command properties
      CMD   = 'list-clusters'.freeze
      ALIAS = 'lc'.freeze
      DESC  = 'List clusters'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command
      def process
        query = @opt[:query] && @opt[:query].split(' ')
        return print_preview(*query.values_at(1, 4)) if @opt[:preview]
        Utils.do_if_sync(@opt[:sync])
        clusters = select_clusters(CM.clusters)
        print_list(clusters)
      end

      private

      LABEL     = %I[cm cm_ver cm_api_ver cl cl_disp cdh_ver hosts].freeze
      LABEL_PRV = %I[hostname role_stypes].freeze

      # Select cluster(s) to print
      def select_clusters(clusters)
        title  = "Press ctrl-p to open preview window.\n\n" \
                 "Select cluster(s):\n".red
        table  = build_cluster_table(clusters)
        fzfopt = "#{@opt[:query]} --header='#{title}'" \
                 " --bind 'ctrl-p:toggle-preview'" \
                 " --preview 'cmux list-clusters --preview -q {}'s" \
                 ' --preview-window right:35%:hidden'

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # build CMUX table
      def build_cluster_table(clusters)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = clusters.map { |c| c.values_at(*LABEL) }
                         .sort_by { |c| c.map(&:djust) }
        FMT.table(header: header, body: body, rjust: [1, 2, 5, 6])
      end

      # Print preview
      def print_preview(cm, cl)
        hosts  = select_preview_hosts(cm, cl)
        header = TABLE_HEADERS.values_at(*LABEL_PRV)
        body   = hosts.map do |host|
          host[:role_stypes] = host[:role_stypes].uniq.sort.join(',')
          host.values_at(*LABEL_PRV)
        end
        body.sort_by! { |e| e.map(&:djust) }
        puts FMT.table(header: header, body: body)
      end

      # Select hosts to preview
      def select_preview_hosts(cm, cl)
        CM.hosts.select { |h| h[:cm] == cm && h[:cl] == cl }
      end

      # Print cluster list.
      def print_list(clusters)
        title  = "Cluster(s):\n\n"
        header = TABLE_HEADERS.values_at(*LABEL)
        table  = FMT.table(header: header, body: clusters, rjust: [1, 2, 5, 6])
        cnt    = clusters.map { |e| e.last.to_i }.reduce(:+)
        footer = '-' * table[0].size, cnt.to_s.rjust(table[0].size)
        puts title, table, footer
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
