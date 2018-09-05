module CMUX
  module Commands
    # Split tmux window and execute each command in each pane
    class TmuxWindowSplitter
      extend Commands

      # Command properties
      CMD   = 'tmux-window-splitter'.freeze
      ALIAS = 'tws'.freeze
      DESC  = 'Split tmux window and execute each command in each pane.'.freeze

      # Regist command
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*args)
        @args = args
        @opt  = build_opts
      end

      # Run command
      def process
        @win_id, @first_pane_cmd = nil
        tempfiles = Utils.cr_tempfile(@args)

        set_tmux_border_format

        @args.zip(tempfiles).map.with_index do |(arg, tempfile), idx|
          write_commands(tempfile, arg)
          print_commands(idx, tempfile)
          build_tmux_panes(idx, tempfile)
        end

        synchronize_pane
        run_first_pane_command
      end

      # Set TMUX border format
      def set_tmux_border_format
        system 'tmux set-option pane-border-status top &&' \
               'tmux set-window-option pane-border-format' \
               ' "#{pane_index} #{pane_title}"'
      end

      # Get command and pane title
      def get_command_title_from_arg(arg)
        arg.is_a?(String) ? [arg, arg[0..9]] : arg.values_at(:command, :title)
      end

      # Write commands to tempfile
      def write_commands(tempfile, arg)
        command, title = get_command_title_from_arg(arg)
        File.open(tempfile, 'w') do |f|
          f.puts " printf '\\033]2;#{title}\\033\\'; #{command}"
        end
      end

      # Print commands for debug
      def print_commands(idx, tempfile)
        puts "[#{idx}] #{File.read(tempfile)}" if Utils.cmux_tws_mode == 'debug'
      end

      # Build TMUX panes
      def build_tmux_panes(idx, tempfile)
        idx.zero? ? build_first_pane(tempfile) : build_other_panes(tempfile)
      end

      # Build first pane
      def build_first_pane(tempfile)
        pane_cnt = `tmux list-panes | wc -l`
        if pane_cnt.strip.to_i > 1 && @args.length > 1
          command = %(tmux new-window -F "\#{window_id}") +
                    %( -P "$SHELL -i #{tempfile}")
        else
          command = %(tmux display-message -p \"\#{window_id}\")
          @first_pane_cmd = tempfile
        end
        @win_id = `#{command}`.chomp
      end

      # Build other panes and execute each command in each pane
      def build_other_panes(tempfile)
        system %(tmux split-window -t #{@win_id} "$SHELL -i #{tempfile}";) +
               %(tmux select-layout -t #{@win_id} tiled)
      end

      # TMUX synchronize-panes on
      def synchronize_pane
        cmd = 'tmux set-window-option synchronize-panes on'
        system cmd if @args.length > 1
      end

      # Run first pane command
      def run_first_pane_command
        system %($SHELL -i #{@first_pane_cmd})
        system 'tmux set-window-option pane-border-format' \
               ' "#{pane_index} #{pane_current_command}"'
      end

      # Check arugments
      def chk_args(parser)
        raise CMUXNoArgumentError if @args.empty?
        raise CMUXNotInTMUXError if @args.length > 1 && (system 'test -z $TMUX')
      rescue CMUXNoArgumentError => e
        puts "cmux: #{CMD}: #{e.message}\n".red
        Utils.exit_with_msg(parser, false)
      rescue CMUXNotInTMUXError => e
        puts "cmux: #{CMD}: #{e.message}".red
        exit
      end

      # Build command options
      def build_opts
        opt    = CHK::OptParser.new
        banner = 'Usage: cmux COMMAND SHELL_COMMAND [OPTIONS]'
        opt.banner(CMD, ALIAS, banner)
        opt.separator('Shell commands:')
        opt.shell_command
        opt.separator('Options:')
        opt.help_option
        chk_args(opt.parser)
        opt.parse
      end
    end
  end
end
