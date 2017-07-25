module CMUX
  module Commands
    # Login via SSH to hosts specified in file or list.
    class SshTmux
      extend Commands

      # Command properties.
      CMD   = 'ssh-tmux'.freeze
      ALIAS = 'tssh'.freeze
      DESC  = 'Login via SSH to hosts specified in file or list.'.freeze

      TITLE  = "Choose host(s) to login:\n".red.freeze
      HEADER = ['Host'].freeze

      # Regist command.
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*args)
        @args = *args
        @opt  = build_opts
      end

      # Run command.
      def process
        opt   = @args.shift
        hosts = case opt
                when '-l', '--list' then filter_list
                when '-f', '--file' then filter_file
                end
        ssh(hosts)
      end

      private

      # Filter list.
      def filter_list
        table    = FMT.table(header: HEADER, body: @args.permutation(1).to_a)
        fzfopt   = "--header='#{TITLE}'"
        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected
      end

      # Filter list.
      def filter_file
        body     = File.foreach(@args[0]).map(&:strip).permutation(1).to_a
        table    = FMT.table(header: HEADER, body: body)
        fzfopt   = "--header='#{TITLE}'"
        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected
      end

      # Run SSH.
      def ssh(hosts)
        ssh_user, ssh_opt = Utils.cmux_ssh_config
        cmds = hosts.map do |host|
          ps1     = '"PS1=\"\u@\h:\w \t> \" bash"'
          command = "ssh #{ssh_opt} #{ssh_user}@#{host} #{ps1}"
          { command: command, title: host }
        end
        TmuxWindowSplitter.new(*cmds).process
      end

      # Check arugments.
      def chk_args(opts, parser)
        raise CMUXInvalidArgumentError, @args.join(' ') if opts.empty?
        raise CMUXNoArgumentError if @args.empty?
        if opts[:file] && opts[:list]
          raise CMUXInvalidArgumentError, @args.join(' ')
        end
      rescue CMUXNoArgumentError, CMUXInvalidArgumentError => e
        puts "cmux: #{CMD}: #{e.message}\n".red
        Utils.exit_with_msg(parser, false)
      end

      # Build command options.
      def build_opts
        opt = CHK::OptParser.new
        opt.banner(CMD, ALIAS)
        opt.separator('Options:')
        opt.file_option
        opt.list_option
        opt.help_option
        opts = opt.parse
        chk_args(opts, opt.parser)
        opts
      end
    end
  end
end
