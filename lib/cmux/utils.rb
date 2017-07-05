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

      # Get the value of this version in this map
      def version_map(map, version)
        map.lazy.find do |k, _|
          Gem::Version.new(version) >= Gem::Version.new(k)
        end.last
      end

      # The 'hbase-region-inspector' for this CDH version
      def hri4cdh(cdh_ver)
        hri_ver = version_map(CDH_HRI_VER_MAP, cdh_ver)
        pattern = 'hbase-region-inspector'
        tools = Dir.entries(HRI_HOME).select { |e| e.match(/^#{pattern}/) }
        hri_ver == 'cdh4' ? tools.last : tools.first
      end

      # The 'hbase-tools' for this CHD version
      def ht4cdh(args = {})
        ht_ver  = version_map(CDH_HT_VER_MAP, args[:cdh_ver])
        pattern = "#{args[:tool]}-#{ht_ver}"
        Dir.entries(HT_HOME).find { |e| e.match(/^#{pattern}/) }
      end

      # Generate kerberos options for hbase-tools.
      def gen_krb_opt_for_ht(cm)
        krb5conf, keytab, principal = chk_krb_opt(cm, 'hbase')
        " --principal=#{principal} --keytab=#{keytab} --krbconf=#{krb5conf}"
      end

      # Make hbase-region-inspector configuration files.
      def gen_krb_opt_for_hri(cm, zk)
        krb5conf, keytab, principal = chk_krb_opt(cm, 'hbase')

        rand_name       = SecureRandom.hex
        jass_conf       = %(/tmp/#{rand_name}-jass.conf)
        properties      = %(/tmp/#{rand_name}.properties)
        default_realm   = CM.security_realm(cm)
        hbase_principal = %(#{principal}/_HOST@#{default_realm})

        make_jass_conf(jass_conf, keytab, principal)
        make_properties(properties, zk, hbase_principal, krb5conf, jass_conf)
        properties
      end

      # Make hbase-region-inspector JAAS login configuration file.
      def make_jass_conf(file_name, keytab, principal)
        str = %(Client {\n) +
              %(  com.sun.security.auth.module.Krb5LoginModule required\n) +
              %(  useTicketCache=false\n) +
              %(  useKeyTab=true\n) +
              %(  keyTab="#{keytab}"\n) +
              %(  principal="#{principal}";\n};)
        File.open(file_name, 'w') { |file| file.write str }
      end

      # Make hbase-region-inspector properties file.
      def make_properties(*args)
        file_name, zk, hbase_principal, krb5conf, jass_conf = args
        str = %(hbase.zookeeper.quorum = #{zk}\n) +
              %(hbase.zookeeper.property.clientPort = 2181\n) +
              %(hadoop.security.authentication = kerberos\n) +
              %(hbase.security.authentication = kerberos\n) +
              %(hbase.master.kerberos.principal = #{hbase_principal}\n) +
              %(hbase.regionserver.kerberos.principal = #{hbase_principal}\n) +
              %(java.security.krb5.conf = #{krb5conf}\n) +
              %(java.security.auth.login.config = #{jass_conf}\n)
        File.open(file_name, 'w') { |file| file.write str }
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
        thr = if args[:message]
                Thread.new do
                  print args[:message].red
                  (1..4).cycle.each do |i|
                    print "\b#{SPIN[i % 4].red}"
                    sleep 0.5
                  end
                end
              end
        yield
      ensure
        thr && thr.kill
        puts
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

      # Converts to an absolute pathname
      def to_absolute_path(file, dir_str)
        Pathname.new(file).absolute? ? file : File.expand_path(file, dir_str)
      end

      # Check kerberos options
      def chk_krb_opt(cm, svc_type)
        conf = load_yaml(file: CM_LIST, key: cm)

        krb5conf = conf.dig('service', svc_type, 'kerberos', 'krb5.conf')
        msg = "'krb5.conf' is not defined in #{CM_LIST} for '#{cm}:#{svc_type}'"
        raise CMUXKerberosError, msg if krb5conf.nil?
        msg = "#{krb5conf} is not exist."
        krb5conf = to_absolute_path(krb5conf, CONF_HOME)
        raise CMUXKerberosError, msg unless File.exist?(krb5conf)

        keytab = conf.dig('service', svc_type, 'kerberos', 'keytab')
        msg = "'keytab' is not defined in #{CM_LIST} for '#{cm}:#{svc_type}'"
        raise CMUXKerberosError, msg if keytab.nil?
        msg = "#{keytab} is not exist."
        keytab = to_absolute_path(keytab, CONF_HOME)
        raise CMUXKerberosError, msg unless File.exist?(keytab)

        principal = conf.dig('service', svc_type, 'kerberos', 'principal')
        msg = "'principal' is not defined in #{CM_LIST} for '#{cm}:#{svc_type}'"
        raise CMUXKerberosError, msg if principal.nil?

        [krb5conf, keytab, principal]
      end

      # [hbase-manager] Change the auto balancer status
      def set_auto_balancer(cm, cl, onoff)
        zk_info     = CM.find_zk_leader(cm, cl)
        zk          = zk_info[:hostname]
        cdh_ver     = zk_info[:cdh_ver]
        hm          = ht4cdh(tool: 'hbase-manager', cdh_ver: cdh_ver)
        krb_enabled = CM.hbase_kerberos_enabled?(cm, cl)
        opt         = gen_krb_opt_for_ht(cm) if krb_enabled
        cmd         = "java -jar #{HT_HOME}/#{hm}" \
                      " assign #{zk} balancer #{onoff} #{opt}" \
                      ' | tail -1'

        msg = onoff ? 'Enabling auto balancer' : 'Disabling auto balancer'
        Formatter.puts_str(msg.red, true)

        msg = cmd.wrap(console_col_size - 26, "\n" + ' ' * 26)
        Formatter.puts_str("  └── #{msg}", true)

        out, err, = Open3.capture3(cmd)
        raise CMUXHBaseToolBalancerError, "\n#{err}" unless err.to_s.empty?
        Formatter.puts_str("  └── #{out.chomp.green}", true)
      end

      # [hbase-manager] Turn off the auto balancer
      def turn_off_auto_balancer(cm, cl)
        set_auto_balancer(cm, cl, false)
      end

      # [hbase-manager] Turn on the auto balancer
      def turn_on_auto_balancer(cm, cl)
        set_auto_balancer(cm, cl, true)
      end

      # [hbase-manager] Export assignment of all Regions to a file
      def export_rs(cm, cl, exp_file)
        msg = 'Export assignment of all Regions'.red
        Formatter.puts_str(msg.red, true)

        zk_info     = CM.find_zk_leader(cm, cl)
        zk          = zk_info[:hostname]
        cdh_ver     = zk_info[:cdh_ver]
        hm          = ht4cdh(tool: 'hbase-manager', cdh_ver: cdh_ver)
        krb_enabled = CM.hbase_kerberos_enabled?(cm, cl)
        opt         = gen_krb_opt_for_ht(cm) if krb_enabled
        cmd         = "java -jar #{HT_HOME}/#{hm} assign #{zk} export" \
                      " #{exp_file} #{opt}"

        msg = cmd.wrap(console_col_size - 26, "\n" + ' ' * 26)
        Formatter.puts_str("  └── #{msg}", true)

        _, err, = Open3.capture3(cmd)
        raise CMUXHBaseToolExportRSError, "\n#{err}" unless err.to_s.empty?
      end

      # [hbase-manager] Import assignment of regions from the file
      def import_rs(cm, cl, hostname, exp_file, opts)
        msg = 'Import assignment of Regions'.red
        Formatter.puts_str(msg, true)

        msg = "No such file: #{exp_file}"
        raise CMUXHBaseToolImportRSError, msg unless File.exist?(exp_file)

        res = File.readlines(exp_file).find do |l|
          l.split(',').first.split('.').first == hostname.split('.').first
        end

        if res

          rs          = res.split('/').first
          zk_info     = CM.find_zk_leader(cm, cl)
          zk          = zk_info[:hostname]
          cdh_ver     = zk_info[:cdh_ver]
          hm          = ht4cdh(tool: 'hbase-manager', cdh_ver: cdh_ver)
          krb_enabled = CM.hbase_kerberos_enabled?(cm, cl)
          opt = opts
          opt += gen_krb_opt_for_ht(cm) if krb_enabled
          cmd = "java -jar #{HT_HOME}/#{hm} assign #{zk}" \
                " import #{exp_file} --rs=#{rs} #{opt}"

          msg = cmd.wrap(console_col_size - 26, "\n" + ' ' * 26)
          Formatter.puts_str("  └── #{msg}", true)

          res = system cmd
          raise CMUXHBaseToolImportRSError, "[#{hostname}] #{rs}" unless res
        else
          msg = "  └── #{'Do nothing.'.green} " \
                'This RegionServer is already empty.'
          Formatter.puts_str(msg, true)
        end
      end

      # [hbase-manager] Move all Regions to other RegionServers
      def empty_rs(cm, cl, hostname, exp_file, opts)
        msg = 'Move all Regions other RegionServers.'.red
        Formatter.puts_str(msg, true)

        msg = "No such file: #{exp_file}"
        raise CMUXHBaseToolEmptyRSError, msg unless File.exist?(exp_file)

        res = File.readlines(exp_file).find do |l|
          l.split(',').first.split('.').first == hostname.split('.').first
        end

        if res
          rs          = res.split('/').first
          zk_info     = CM.find_zk_leader(cm, cl)
          zk          = zk_info[:hostname]
          cdh_ver     = zk_info[:cdh_ver]
          hm          = ht4cdh(tool: 'hbase-manager', cdh_ver: cdh_ver)
          krb_enabled = CM.hbase_kerberos_enabled?(cm, cl)
          opt = "--skip-export #{opts}"
          opt += gen_krb_opt_for_ht(cm) if krb_enabled
          cmd = "java -jar #{HT_HOME}/#{hm} assign #{zk} empty #{rs} #{opt}"

          msg = cmd.wrap(console_col_size - 26, "\n" + ' ' * 26)
          Formatter.puts_str("  └── #{msg}", true)

          res = system cmd
          raise CMUXHBaseToolEmptyRSError, "[#{hostname}] #{rs}" unless res
        else
          msg = "  └── #{'This RegionServer is already empty.'.green}"
          Formatter.puts_str(msg, true)
        end
      end
    end
  end
end

require_relative 'utils/api_caller'
require_relative 'utils/checker'
require_relative 'utils/cm'
require_relative 'utils/errors'
require_relative 'utils/formatter'
require_relative 'utils/opt_parser'
