module CMUX
  module Commands
    # Run 'hbase-table-stat'
    class HbaseTableStat
      extend Commands

      # Command properties
      CMD   = 'hbase-table-stat'.freeze
      ALIAS = 'hts'.freeze
      DESC  = 'Run hbase-table-stat.'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command
      def process
        Utils.do_if_sync(@opt[:sync])
        clusters = select_clusters(CM.hosts)
        run_hts(clusters)
      end

      private

      LABEL = %I[cm cl_disp cdh_ver cl].freeze

      # Select cluster(s) to run 'hbase-table-stat'
      def select_clusters(hosts)
        title  = "Select cluster(s) to run hbase-table-stat:\n".red
        table  = build_cluster_table(hosts)
        fzfopt = "-n1,2 --with-nth=..-2 #{@opt[:query]} --header='#{title}'"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # Build CMUX table
      def build_cluster_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.select { |h| h[:role_stypes].include?('HM(A)') }
                      .map { |h| h.values_at(*LABEL) }
                      .sort_by { |e| e.map(&:djust) }
        FMT.table(header: header, body: body, rjust: [2])
      end

      # Run 'hbase-table-stat'
      def run_hts(clusters)
        cmds = clusters.map do |cluster|
          build_command([LABEL, cluster].transpose.to_h)
        end

        TmuxWindowSplitter.new(*cmds).process
      end

      # Build command
      def build_command(cluster)
        banner = build_banner(cluster[:cl_disp], cluster[:cdh_ver])
        hduser = "HADOOP_USER_NAME=#{@opt[:user]}" if @opt[:user]
        hts = Utils.ht4cdh(tool: 'hbase-table-stat', cdh_ver: cluster[:cdh_ver])
        zk  = CM.zk_leader(cluster[:cm], cluster[:cl])
        opt = build_hts_opts(cluster[:cm], cluster[:cl])
        "#{banner} #{hduser} java -jar #{HT_HOME}/#{hts} #{zk} #{opt}"
      end

      # Build login banner
      def build_banner(cl_disp, cdh_ver)
        msg = "[hbase-table-stat] #{cl_disp} (CDH #{cdh_ver})"
        Utils.login_banner(msg)
      end

      # Build 'hbase-table-stat' options
      def build_hts_opts(cm, cl)
        krb_enabled = CM.hbase_kerberos_enabled?(cm, cl)
        opt = "--interval #{@opt[:interval]}"
        opt += Utils.gen_krb_opt_for_ht(cm) if krb_enabled
        opt
      end

      # Build command options
      def build_opts
        opt = CHK::OptParser.new
        opt.banner(CMD, ALIAS)
        opt.separator('Options:')
        opt.sync_option
        opt.query_option
        opt.interval_option
        opt.hadoop_user_name_option
        opt.help_option
        opt.parse
      end
    end
  end
end
