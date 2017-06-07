#!/usr/bin/env ruby

module CMUX
  module Commands
    class Example
      CMD   = 'example'
      ALIAS = 'exam'
      DESC  = 'Example command'

      extend Commands
      reg_cmd(cmd: CMD, alias: ALIAS, desc: DESC)

      def initialize(*args)
        @args = *args
        build_opts
      end

      def process
        puts "Hello CMUX"
      end

      def build_opts
        opt = Utils::Checker::OptParser.new
        banner = 'Usage: cmux COMMAND [OPTIONS]'
        opt.banner(CMD, ALIAS, banner)
        opt.separator('Options:')
        opt.help_option
        opt.parse
      end
    end
  end
end
