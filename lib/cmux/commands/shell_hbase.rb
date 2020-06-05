module CMUX
  module Commands
    # Run hbase shell
    class HBaseShell
      extend Commands

      # Command properties
      CMD   = 'shell-hbase'.freeze
      ALIAS = 'sh'.freeze
      DESC  = 'Run hbase shell'.freeze

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
        run_hbase_shell(clusters)
      end

      private

      LABEL = %I[cm cl_disp cl].freeze

      # Select cluster(s) to run 'hbase-shell'
      def select_clusters(hosts)
        title  = "Select cluster(s) to run hbase shell:\n".red
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
        FMT.table(header: header, body: body)
      end

      # Run 'hbase-shell'
      def run_hbase_shell(clusters)
        cmlist = Utils.cm_config
        ssh_user, ssh_opt = Utils.cmux_ssh_config

        cmds = clusters.map do |cluster|
          cl  = [LABEL, cluster].transpose.to_h
          cmd = build_hs_command(cmlist, cl[:cm], cl[:cl], cl[:cl_disp])
          build_command(cl, ssh_user, ssh_opt, cmd)
        end

        TmuxWindowSplitter.new(*cmds).process
      end

      # Build hbase shell command
      def build_hs_command(list, cm, cl, cl_disp)
        irbrc = "#{IRBRC} #{IRBRC_LOCAL}"
        cmd   = %(\"echo \"$(xxd -p <(cat #{irbrc} 2> /dev/null))\") +
                %(| xxd -p -r | sed 's@xCLUSTERx@#{cl_disp}@g' > ~/.irbrc;)
        principal = get_principal(list, cm, cl)
        cmd += %( kinit #{principal} &&) if principal
        cmd += %( HADOOP_USER_NAME=#{@opt[:user]}) if @opt[:user]
        cmd +  %( HBASE_SHELL_OPTS='#{ENV['HBASE_SHELL_OPTS']}' hbase shell\")
      end

      # Retrieve keberos principal for this HBase cluster
      def get_principal(list, cm, cl)
        krb_enabled = CM.hbase_kerberos_enabled?(cm, cl)
        return unless krb_enabled
        principal = list.dig(cm, 'service', 'hbase', 'kerberos', 'principal')
        return principal unless principal.nil?
        msg = "#{cm}: 'service > hbase > kerberos > principal'"
        raise CMUXConfigError, msg
      end

      # Build command
      def build_command(cluster, ssh_user, ssh_opt, cmd)
        hm      = CM.hbase_master(cluster[:cm], cluster[:cl])
        banner  = build_banner(cluster[:cl_disp], hm)
        title   = 'shell-hbase'
        command = "#{banner} ssh #{ssh_opt} #{ssh_user}@#{hm} #{cmd}"
        { command: command, title: title }
      end

      # Build login banner
      def build_banner(cl_disp, hm)
        msg = "[#{cl_disp}] #{hm}\n - HMaster (Active)"
        Utils.login_banner(msg)
      end

      # Build command options
      def build_opts
        opt    = CHK::OptParser.new
        banner = 'Usage: [HBASE_SHELL_OPTS] cmux COMMAND [OPTIONS]'
        opt.banner(CMD, ALIAS, banner)
        opt.separator('HBase shell options:')
        opt.hbase_shell_option
        opt.separator('Options:')
        opt.sync_option
        opt.query_option
        opt.hadoop_user_name_option
        opt.help_option
        opt.parse
      end
    end
  end
end
