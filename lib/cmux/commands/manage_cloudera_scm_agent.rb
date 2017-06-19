module CMUX
  module Commands
    # Run clouder-scm-agent in parallel.
    class ManageClouderaScmAgent
      extend Commands

      # Command properties.
      CMD   = 'manage-cloudera-scm-agent'.freeze
      ALIAS = 'scmagent'.freeze
      DESC  = 'Run clouder-scm-agent in parallel.'.freeze

      # Regist command.
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*args)
        @args = *args
        @opt  = build_opts
      end

      # Run command.
      def process
        Utils.do_if_sync(@opt[:sync])
        cm    = CM.select_cm(all: true)
        hosts = select_hosts(CM.hosts(cm))
        res   = run_scmagent(hosts, @args.shift)
        print_result(res)
      end

      private

      LABEL = %I[cm cl_disp role_stypes hostname].freeze

      # Select host(s) to run cloudera-scm-agent.
      def select_hosts(hosts)
        title  = "Select host(s) to run cloudera-scm-agent:\n".red
        table  = build_host_table(hosts)
        fzfopt = "--header='#{title}'"

        selected = Utils.fzf(list: table, opt: fzfopt)
        Utils.exit_if_empty(selected, 'No items selected')
        selected.map(&:split)
      end

      # Build CMUX table.
      def build_host_table(hosts)
        header = TABLE_HEADERS.values_at(*LABEL)
        body   = hosts.map do |host|
          host[:role_stypes] = host[:role_stypes].uniq.sort.join(',')
          host.values_at(*LABEL)
        end
        body.sort_by! { |e| e.map(&:djust) }
        FMT.table(header: header, body: body)
      end

      # Run `cloudera-scm-agent` commands.
      def run_scmagent(hosts, cmd_opt)
        ssh_user, ssh_opt = Utils.cmux_ssh_config
        ssh_opt = "#{ssh_opt} -T -o LogLevel=QUIET"

        Utils.awaiter(message: 'Processing  ') do
          hosts.pmap do |host|
            h      = [LABEL, host].transpose.to_h
            banner = "[#{h[:cm]}] #{h[:cl_disp]} - #{h[:hostname]}"
            cmd    = build_command(cmd_opt)
            [banner, `ssh #{ssh_opt} #{ssh_user}@#{h[:hostname]} "#{cmd}"`]
          end.to_h
        end
      end

      # Build command.
      def build_command(cmd_opt)
        %[echo \"$(xxd -p #{SCMAGENT_SH})\" | xxd -p -r] +
          %( > /tmp/cmux_scmagent.sh; sh /tmp/cmux_scmagent.sh #{cmd_opt})
      end

      # Print result.
      def print_result(res)
        max_key_length = res.keys.map(&:length).max
        res.sort_by { |host, _| host.djust }.each do |host, log|
          log.split("\n").each do |line|
            if line.strip =~ /^Active:/
              print_result_rhel7(host, line, max_key_length)
            elsif line.strip =~ /^cloudera-scm-agent /
              print_result_others(host, line, max_key_length)
            end
          end
        end
      end

      # Print result for RHEL-comapatible 7.
      def print_result_rhel7(host, log_line, max_col_length)
        if log_line.split(' ')[1] == 'active'
          printf "%-#{max_col_length}s  %4s\n", host, "[#{'OK'.green}]"
        else
          printf "%-#{max_col_length}s  %4s\n", host, "[#{'X'.red}]"
          puts "  #{log_line.split(': ')[1]}".red
        end
      end

      # Print result for other Linux distributions.
      def print_result_others(host, log_line, max_col_length)
        if log_line =~ /is running.../
          printf "%-#{max_col_length}s  %4s\n", host, "[#{'OK'.green}]"
        else
          printf "%-#{max_col_length}s  %4s\n", host, "[#{'X'.red}]"
          puts "  #{log_line}".red
        end
      end

      # Check arugments.
      def chk_args(parser)
        raise CMUXNoArgumentError if @args.empty?
        unless SCMAGENT_ARGS.include?(@args[0])
          raise CMUXInvalidArgumentError, @args[0]
        end
      rescue StandardError => e
        puts "cmux: #{CMD}: #{e.message}\n".red
        Utils.exit_with_msg(parser, false)
      end

      # Build command options.
      def build_opts
        opt    = CHK::OptParser.new
        banner = 'Usage: cmux COMMAND SCMAGENT_COMMANDS [OPTIONS]'
        opt.banner(CMD, ALIAS, banner)
        opt.separator('Scmagent commands:')
        opt.scmagent
        opt.separator('Options:')
        opt.sync_option
        opt.help_option
        chk_args(opt.parser)
        opt.parse
      end
    end
  end
end
