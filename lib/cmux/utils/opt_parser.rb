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

        # The '--sync' option
        def sync_option
          @opts[:sync] = false
          @parser.new do |opt|
            opt_short = '-s'
            opt_long  = '--sync'
            opt_text  = 'Run with synccm'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:sync] = e
            end
          end
        end

        # The '--query' option
        def query_option
          @parser.new do |opt|
            opt_short = '-q'
            opt_long  = '--query query_string'
            opt_text  = 'Run fzf with given query'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:query] = "-q #{e}"
            end
          end
        end

        # The '--user' option
        def hadoop_user_name_option
          @parser.new do |opt|
            opt_short = '-u'
            opt_long  = '--user HADOOP_USER_NAME'
            opt_text  = 'Run this command with specified HADOOP_USER_NAME'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:user] = e
            end
          end
        end

        # The '--preview' option
        def preview_option
          @opts[:preview] = false
          @parser.new do |opt|
            opt_short = '-p'
            opt_long  = '--preview'
            opt_text  = '(Internal option) Preview mode'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:preview] = e
            end
          end
        end

        # The '--interval' option
        def interval_option
          @opts[:interval] = 10
          @parser.new do |opt|
            opt_short = '-i'
            opt_long  = '--interval N'
            opt_text  = 'Interval (default: 10)'
            opt.on_tail(opt_short, opt_long, Integer, opt_text) do |e|
              @opts[:interval] = e
            end
          end
        end

        # The '--file' option
        def file_option
          @parser.new do |opt|
            opt_short = '-f'
            opt_long  = '--file filename'
            opt_text  = 'File name where host list is stored'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:file] = e
            end
          end
        end

        # The '--list' option
        def list_option
          @parser.new do |opt|
            opt_short = '-l'
            opt_long  = '--list host[ host ...]]'
            opt_text  = 'Space separated host list'
            opt.on_tail(opt_short, opt_long, opt_text) do |e|
              @opts[:list] = e
            end
          end
        end

        # The '--help' option
        def help_option
          @parser.new do |opt|
            opt_short = '-h'
            opt_long  = '--help'
            opt_text  = 'Show this message'
            opt.on_tail(opt_short, opt_long, opt_text) do
              puts opt
              exit
            end
          end
        end

        # The 'HBASE_SEHLL_OPTS' option
        def hbase_shell_option
          @parser.new do |opt|
            opt.banner += "    Extra options passed to the hbase shell.\n" \
                          "    e.g. HBASE_SHELL_OPTS=-Xmx2g\n\n"
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
