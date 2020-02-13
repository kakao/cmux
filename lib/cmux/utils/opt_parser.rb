module CMUX
  module Utils
    module Checker
      # Parse command options
      class OptParser
        attr_reader :parser

        # Initialize
        def initialize
          @parser = OptionParser.new
          @opts = {}
          help_option
        end

        # Set banner
        def banner(cmd, cmd_alias, banner = nil)
          @parser.new do |opt|
            opt.banner = banner || 'Usage: cmux COMMAND [OPTIONS]'
            opt.banner += "\n\nCommand:\n"
            opt.banner += "    #{cmd}, #{cmd_alias}\n\n"
          end
        end

        # separator
        def separator(title)
          @parser.new { |opt| opt.banner += "#{title}\n" }
        end

        # Lists of roles
        def roles
          @parser.new do |opt|
            body = slice_list(ROLE_TYPES.keys.sort, 3)
            FMT.table(body: body).each { |e| opt.banner += "#{e}\n" }
            opt.banner += "\n"
          end
        end

        # commands of the 'cloudera-scm-agent'
        def scmagent
          @parser.new do |opt|
            body = slice_list(SCMAGENT_ARGS.sort, 3)
            FMT.table(body: body).each { |e| opt.banner += "#{e}\n" }
            opt.banner += "\n"
          end
        end

        # Add the description of the 'shell_command' to the banner
        def shell_command
          @parser.new do |opt|
            opt.banner += "    shell_command[ shell_command[ ...]]
    One or more shell commands. Each command is separated by a space and
    commands which contain spaces must be quoted\n\n"
          end
        end

        # Add the description of the 'hbase_shell' to the banner
        def hbase_shell_option(opts = {})
          @parser.new do |opt|
            opt.banner += "    Extra options passed to the hbase shell.\n" \
                          "    e.g. HBASE_SHELL_OPTS=-Xmx2g\n\n"
          end
        end

        ## Options
        # The '--sync' option
        def sync_option(opts = {})
          @opts[:sync] = false
          @parser.new do |opt|
            opt_short = opts[:short] || '-s'
            opt_long  = opts[:long]  || '--sync'
            opt_text  = opts[:text]  || 'Run with synccm'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:sync] = e
            end
          end
        end

        # The '--query' option
        def query_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-q'
            opt_long  = opts[:long]  || '--query query_string'
            opt_text  = opts[:text]  || 'Run fzf with given query'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:query] = "-q #{e}"
            end
          end
        end

        # The '--user' option
        def hadoop_user_name_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-u'
            opt_long  = opts[:long]  || '--user HADOOP_USER_NAME'
            opt_text  = opts[:text]  || 'Run this command with specified' +
                                        ' HADOOP_USER_NAME'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:user] = e
            end
          end
        end

        # The '--preview' option
        def preview_option(opts = {})
          @opts[:preview] = false
          @parser.new do |opt|
            opt_short = opts[:short] || '-p'
            opt_long  = opts[:long]  || '--preview'
            opt_text  = opts[:text]  || '(Internal option) Preview mode'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:preview] = e
            end
          end
        end

        # The '--interval' option
        def interval_option(opts = {})
          default = opts[:default] || 10

          @parser.new do |opt|
            opt_short = opts[:short] || '-i'
            opt_long  = opts[:long]  || '--interval N'
            opt_text  = opts[:text]  || 'Run with interval' +
                                        "(default: #{default} sec)"
            opt.on_tail(opt_short, opt_long, Integer, opt_text) do |e|
              raise StandardError, "'interval' must be positive number" if e < 0
              @opts[:interval] = e
            end
            @opts[:interval] = default unless @opts[:interval]
          end
        rescue StandardError => e
          puts "cmux: #{CMD}: #{e.message}\n".red
          Utils.exit_with_msg(opt.parser, false)
        end

        # The '--file' option
        def file_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-f'
            opt_long  = opts[:long]  || '--file filename'
            opt_text  = opts[:text]  || 'File name'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:file] = e
            end
          end
        end

        # The '--dir' option
        def dir_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-d'
            opt_long  = opts[:long]  || '--dir directory'
            opt_text  = opts[:text]  || 'Directory path'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:dir] = e
            end
          end
        end

        # The '--list' option
        def list_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-l'
            opt_long  = opts[:long]  || '--list host[ host ...]]'
            opt_text  = opts[:text]  || 'Space separated host list'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:list] = e
            end
          end
        end

        # The '--port' option
        def port_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-p'
            opt_long  = opts[:long]  || '--port N'
            opt_text  = opts[:text]  || 'Port number'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:port] = e
            end
          end
        end

        # The '--user-mode' option
        def user_mode_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-u'
            opt_long  = opts[:long]  || '--user-mode'
            opt_text  = opts[:text]  || 'User mode'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:user_mode] = e
            end
          end
        end

        # The '--help' option
        def help_option(opts = {})
          @parser.new do |opt|
            opt_short = opts[:short] || '-h'
            opt_long  = opts[:long]  || '--help'
            opt_text  = opts[:text]  || 'Show this message'
            opt.on_tail(opt_short, opt_long, opt_text) do
              puts opt
              exit
            end
          end
        end

        # Parse options
        def parse
          @parser.parse!
          @opts
        rescue SystemExit
          raise
        rescue StandardError => e
          puts "cmux: #{e}\n".red
          puts parser
          exit
        end

        private

        # Slice given list
        def slice_list(arr, p)
          arr.each_slice(p).map do |e|
            e.fill(' ', e.length...p).map { |a| '    ' + a }
          end
        end
      end
    end
  end
end
