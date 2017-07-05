module CMUX
  # CMUX utilities
  module Utils
    class << self
      # Recursive hash
      def new_rec_hash
        Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
      end

      # Create temporary file
      def cr_tempfile(args)
        args.map do
          tf = Tempfile.new('cmux')
          tf.path.tap { tf.close! }
        end
      end

      # tput smcup
      def tput_smcup
        @smcup = true
        system 'tput smcup;tput clear'
      end

      # tput rmcup
      def tput_rmcup
        return unless @smcup
        @smcup = false
        system 'tput rmcup'
      end

      # Return a column size of console
      def console_col_size
        IO.console.winsize[1]
      end

      # Load data from the YAML file
      def load_yaml(args = {})
        file = File.read(args[:file] || CMUX_YAML)
        yaml = YAML.load(file)
        args[:key] ? yaml[args[:key]] : yaml
      rescue Psych::SyntaxError
        message = "Make sure you've written #{file} in YAML Simple Mapping." \
                  ' Please check README.'
        raise message.red
      end

      # Load CMUX configuration
      def cmux_ssh_config
        load_yaml(file: CMUX_YAML, key: 'ssh').values_at('user', 'opt')
      end

      # Load CMUX 'tws' mode
      def cmux_tws_mode
        load_yaml(file: CMUX_YAML, key: 'tws_mode')
      end

      # Load Cloudera Manager configurations
      def cm_config(cm = nil)
        cm_list = load_yaml(file: CM_LIST)
        cm_list.key?(cm) ? cm_list.select { |k, _| k == cm }[cm] : cm_list
      rescue Errno::ENOENT
        raise CMUXCMListError, "No such file #{CM_LIST}"
      end

      # Run fzf
      def fzf(args = {})
        @smcup = true
        opt = '-m --reverse --inline-info -x --tiebreak=begin --header-lines=2'
        cmd = %(fzf #{opt} #{args[:opt]})
        io  = IO.popen(cmd, 'r+')
        args[:list].each { |e| io.puts e }
        io.close_write
        io.readlines.map(&:chomp)
      end

      # Run command.
      def run_cmd_capture3(cmd)
        out, err, status = Open3.capture3(cmd)
        return out.chomp if err.to_s.empty?
        yield err, status
      end

      # Get the value of this version in this map
      def version_map(map, version)
        map.lazy.find do |k, _|
          Gem::Version.new(version) >= Gem::Version.new(k)
        end.last
      end

      # Open URL in default web browser
      def open_url(url)
        if RbConfig::CONFIG['host_os'] =~ /darwin/
          system %(open "#{url}")
        elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
          system %(xdg-open "#{url}")
        else
          puts 'Not Supported OS!'.red
        end
      end

      # Make SSH login banner
      def login_banner(msg)
        if `which boxes`.chomp.empty?
          %(#{C_B};echo "#{msg}";#{C_0};echo;)
        else
          %(#{C_B};echo "#{msg}" | #{BOXES};#{C_0};echo;)
        end
      end

      # Setup bash custom prompt
      def ps1(title)
        '"PS1=\"[\[\033[01;32m\]' +
          title +
          '\[\033[0m\]] \u@\h:\w \t> \" bash"'
      end

      # Exit with message
      def exit_with_msg(*args)
        tput_rmcup
        Formatter.puts_str(*args)
        exit
      end

      # Exit if object is empty
      def exit_if_empty(obj, msg = 'Empty Record')
        exit_with_msg(msg.red, false) if obj.nil? || obj.empty?
      end

      # Q&A
      def qna(*args)
        Formatter.print_str(*args)
        ans = $stdin.gets.chomp
        return ans
      rescue Interrupt
        puts
        exit
      end

      # Countdown
      def countdown(interval)
        t = Time.new(0)
        interval.downto(0) do |sec|
          print "\b\b\b\b\b\b\b\b" + (t + sec).strftime('%H:%M:%S').red
          sleep 1
        end
        puts
      end

      # Wait for this thread to finish
      def awaiter(args = {})
        args[:smcup] && tput_smcup
        thr = if args[:msg]
                Thread.new do
                  (1..4).cycle.each do |i|
                    print "\r"
                    print "#{FMT.cur_dt} " if args[:time]
                    print "#{args[:msg].red}\b#{SPIN[i % 4].red}"
                    sleep 1
                  end
                end
              end
        yield
      ensure
        thr && thr.kill
        puts if args[:newline]
      end

      # Run sync command if you submit
      def do_if_sync(sync)
        do_sync = -> { Commands::Sync.new('sync').process }
        sync && do_sync.call
        do_sync.call unless File.exist?(CMUX_DATA)
      end

      # Convert CMUX alias to CMUX command
      def alias2cmd(cmd_alias)
        Commands::CMDS.find { |_, v| v[:alias] == cmd_alias }.first
      end

      # Convert to CMUX command, If it is a CMUX alias.
      def to_cmux_cmd(cmd)
        print_cmux_help if cmd.nil?
        return cmd if Checker.cmux_cmd?(cmd)
        return alias2cmd(cmd) if Checker.cmux_alias?(cmd)
        raise CMUXCommandError, cmd
      end

      # CMUX help
      def print_cmux_help
        puts "Usage: cmux COMMAND [OPTIONS]\n\n"
        puts 'Commands:'
        print_cmux_cmds
        puts "\nSee 'cmux COMMAND -h' or 'cmux COMMAND --help'" \
             ' to read about a specific subcommand.'
        exit
      end

      # Print CMUX commands
      def print_cmux_cmds
        cmds = Commands::CMDS.map do |k, v|
          [' ' * 4, k, v[:alias] || ' ', v[:desc] || ' ']
        end.sort
        puts Formatter.table(body: cmds)
      end

      # Print string to fit the column size of pane.
      def print_str_to_fit_pane(str)
        str = str.wrap(console_col_size - 26, "\n" + ' ' * 26)
        Formatter.puts_str(str, true)
      end

      # Converts to an absolute pathname
      def to_absolute_path(file, dir_str)
        Pathname.new(file).absolute? ? file : File.expand_path(file, dir_str)
      end

      # Check that 'krb5.conf' is difined in cm.list and exist.
      def chk_krb_config(cm, cm_config, svc_type)
        msg = "'krb5.conf' is not defined in #{CM_LIST} for '#{cm}:#{svc_type}'"
        krb5conf = cm_config.dig('service', svc_type, 'kerberos', 'krb5.conf')
        raise CMUXKerberosError, msg if krb5conf.nil?

        msg = "#{krb5conf} is not exist."
        krb5conf = to_absolute_path(krb5conf, CONF_HOME)
        return krb5conf if File.exist?(krb5conf)
        raise CMUXKerberosError, msg
      end

      # Check that 'keytab' is difined in cm.list and exist.
      def chk_keytab(cm, cm_config, svc_type)
        msg = "'keytab' is not defined in #{CM_LIST} for '#{cm}:#{svc_type}'"
        keytab = cm_config.dig('service', svc_type, 'kerberos', 'keytab')
        raise CMUXKerberosError, msg if keytab.nil?

        msg = "#{keytab} is not exist."
        keytab = to_absolute_path(keytab, CONF_HOME)
        return keytab if File.exist?(keytab)
        raise CMUXKerberosError, msg
      end

      # Check that 'principal' is difined in cm.list.
      def chk_principal(cm, cm_config, svc_type)
        msg = "'principal' is not defined in #{CM_LIST} for '#{cm}:#{svc_type}'"
        principal = cm_config.dig('service', svc_type, 'kerberos', 'principal')
        return principal unless principal.nil?
        raise CMUXKerberosError, msg
      end

      # Check kerberos options.
      def chk_krb_opt(cm, svc_type)
        cm_config = load_yaml(file: CM_LIST, key: cm)
        krb5conf  = chk_krb_config(cm, cm_config, svc_type)
        keytab    = chk_keytab(cm, cm_config, svc_type)
        principal = chk_principal(cm, cm_config, svc_type)
        [krb5conf, keytab, principal]
      end
    end
  end
end

require_relative 'utils/api_caller'
require_relative 'utils/checker'
require_relative 'utils/cm'
require_relative 'utils/hbase_region_inspector'
require_relative 'utils/hbase_tools'
require_relative 'utils/errors'
require_relative 'utils/formatter'
require_relative 'utils/opt_parser'
