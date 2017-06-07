#!/usr/bin/env ruby

module CMUX
  module Commands
    # Split tmux window and execute each command in each pane.
    class TmuxWindowSplitter
      extend Commands

      # Command properties.
      CMD   = 'tmux-window-splitter'.freeze
      ALIAS = 'tws'.freeze
      DESC  = 'Split tmux window and execute each command in each pane.'.freeze

      # Regist command.
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      # Initialize
      def initialize(*args)
        @args = args
        @opt  = build_opts
      end

      # Run command.
      def process
        @win_id, @first_pane_cmd = nil
        tempfile = Utils.cr_tempfile(@args)

        @args.zip(tempfile).map.with_index do |(e, tf), idx|
          File.open(tf, 'w') { |file| file.puts e.to_s }
          print_commands(idx, tf)
          build_tmux_panes(idx, tf)
        end

        sync_pane
        run_first_pane_command
      end

      # Print commands for debug.
      def print_commands(idx, tf)
        puts "[#{idx}] #{File.read(tf)}" if Utils.cmux_tws_mode == 'debug'
      end

      # Build TMUX panes.
      def build_tmux_panes(idx, tf)
        idx.zero? ? build_first_pane(tf) : build_other_panes(tf)
      end

      # Build first pane.
      def build_first_pane(tf)
        pane_cnt = `tmux list-panes | wc -l`
        if pane_cnt.strip.to_i > 1 && @args.length > 1
          @win_id = `tmux new-window -F "\#{window_id}" -P "$SHELL -i #{tf}"`
                    .chomp
        else
          @win_id = `tmux display-message -p \"\#{window_id}\"`.chomp
          @first_pane_cmd = tf
        end
      end

      # Build other panes and execute each command in each pane.
      def build_other_panes(tf)
        system %(tmux split-window -t #{@win_id} "$SHELL -i #{tf}";) +
               %(tmux select-layout -t #{@win_id} tiled)
      end

      # TMUX synchronize-panes on.
      def sync_pane
        cmd = 'tmux set-window-option synchronize-panes on'
        system cmd if @args.length > 1
      end

      # Run first pane command.
      def run_first_pane_command
        system %($SHELL -i #{@first_pane_cmd})
      end

      # Check arugments.
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

      # Build command options.
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
