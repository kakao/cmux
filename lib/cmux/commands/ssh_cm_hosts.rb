module CMUX
  module Commands
    # Login via SSH to host(s) registered in these Cloudera Managers
    class SshCM
      extend Commands

      # Command properties
      CMD   = 'ssh-cm-hosts'.freeze
      ALIAS = 'ssh'.freeze
      DESC  = 'Login via SSH to host(s) registered in these Cloudera Managers.'
              .freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*)
        @opt = build_opts
      end

      # Run command
      def process
        Utils.do_if_sync(@opt[:sync])
        cm    = CM.select_cm(all: true, fzf_opt: @opt[:query])
        hosts = select_hosts(CM.hosts(cm))
        run_ssh(hosts)
      end

      private

      LABEL = %I[cm cl_disp hostname role_stypes].freeze

      # Select hosts to run SSH
      def select_hosts(hosts)
        title  = "Press ctrl-p to open preview window.\n\n" \
                 "Select host(s) to login:\n".red
        table  = build_host_table(hosts)
        fzfopt = " #{@opt[:query]} --header='#{title}'" \
                 " --bind 'ctrl-p:toggle-preview'" \
                 " --preview 'cmux list-hosts --preview 1 -q {}'" \
                 ' --preview-window right:35%:hidden'

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # Build CMUX Table
      def build_host_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.map do |host|
          host[:role_stypes] = host[:role_stypes].uniq.sort.join(',')
          host.values_at(*LABEL)
        end
        body.sort_by! { |e| e.map(&:djust) }
        FMT.table(header: header, body: body)
      end

      # Run SSH
      def run_ssh(hosts)
        ssh_user, ssh_opt = Utils.cmux_ssh_config
        cmds = hosts.map { |host| build_command(host, ssh_user, ssh_opt) }
        TmuxWindowSplitter.new(*cmds).process
      end

      # Build command
      def build_command(host, ssh_user, ssh_opt)
        h      = [LABEL, host].transpose.to_h
        msg    = "[#{h[:cl_disp]}] #{h[:hostname]}\n " \
                 "- Roles: #{h[:role_stypes]}"
        banner = Utils.login_banner(msg)
        ps1    = Utils.ps1(h[:cl_disp])
        "#{banner} ssh #{ssh_opt} #{ssh_user}@#{h[:hostname]} #{ps1}"
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
