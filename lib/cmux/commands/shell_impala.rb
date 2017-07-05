module CMUX
  module Commands
    # Run impala shell
    class ImpalaShell
      extend Commands

      # Command properties
      CMD   = 'shell-impala'.freeze
      ALIAS = 'si'.freeze
      DESC  = 'Run impala shell.'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command.
      def process
        Utils.do_if_sync(@opt[:sync])
        hosts = select_hosts
        run_impala_shell(hosts)
      end

      private

      LABEL = %I[cm cl_disp hostname cl].freeze

      # Select cluster(s) to run 'impala-shell'
      def select_hosts
        title  = "Select cluster(s) to run impala shell:\n".red
        table  = build_host_table(CM.hosts)
        fzfopt = "-n1,2 --with-nth=..-2 #{@opt[:query]} --header='#{title}'"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # Build CMUX Table
      def build_host_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.select { |h| h[:role_stypes].include?('ID') }
                      .map { |h| h.values_at(*LABEL) }
                      .sort_by { |e| e.map(&:djust) }
        FMT.table(header: header, body: body, rjust: [2])
      end

      # Run 'impala-shell'
      def run_impala_shell(hosts)
        cmlist = Utils.cm_config
        ssh_user, ssh_opt = Utils.cmux_ssh_config

        cmds = hosts.map do |h|
          host = [LABEL, h].transpose.to_h
          cmd  = build_is_command(cmlist, host[:cm], host[:cl], host[:hostname])
          build_command(host, ssh_user, ssh_opt, cmd)
        end

        TmuxWindowSplitter.new(*cmds).process
      end

      # Build command
      def build_command(host, ssh_user, ssh_opt, cmd)
        banner = build_banner(host[:cl_disp], host[:hostname])
        %(#{banner} ssh #{ssh_opt} #{ssh_user}@#{host[:hostname]} "#{cmd}")
      end

      # Build login banner
      def build_banner(cl_disp, hostname)
        msg = "[#{cl_disp}] #{hostname}\n - Impalad"
        Utils.login_banner(msg)
      end

      # Build impala shell command
      def build_is_command(list, cm, cl, hostname)
        principal = get_principal(list, cm, cl)
        if principal
          %(kinit #{principal} && impala-shell -k -i #{hostname})
        else
          %(impala-shell -i #{hostname})
        end
      end

      # Retrieve keberos principal for this HBase cluster
      def get_principal(list, cm, cl)
        krb_enabled = CM.hadoop_kerberos_enabled?(cm, cl)
        return unless krb_enabled
        principal = list.dig(cm, 'service', 'impala', 'kerberos', 'principal')
        return principal unless principal.nil?
        msg = "#{cm}: 'service > impala > kerberos > principal'"
        raise CMUXConfigError, msg
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
