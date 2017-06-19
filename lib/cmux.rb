require 'optparse'
require 'io/console'
require 'json'
require 'net/http'
require 'tempfile'
require 'yaml'
require 'open3'
require 'openssl'
require 'socket'
require 'timeout'
require 'securerandom'
require 'cgi'
require 'set'
require 'pathname'
require_relative 'cmux/core_ext'
require_relative 'cmux/constants'
require_relative 'cmux/utils'
require_relative 'cmux/commands'

module CMUX
  CM  = Utils::CM
  FMT = Utils::Formatter
  CHK = Utils::Checker
  API = Utils::ApiCaller

  # CMUX is a set of commands for managing CDH clusters
  # using Cloudera Manager REST API.
  class Cmux
    # Initialize.
    def initialize
      load_n_require
    end

    # Load extensions.
    def load_n_require
      Dir.glob("#{CMUX_HOME}/ext/{,/*/**}/*.rb") { |e| require e }
    end

    # Run command.
    def run(*args)
      cmd = Utils.to_cmux_cmd(args.shift)
      Commands::CMDS[cmd][:class].new(*args).process
    rescue SystemExit
      Utils.system_exit
    rescue Interrupt
      Utils.interrupt
    rescue CMUXCommandError => e
      Utils.print_cmux_command_error e
    rescue StandardError => e
      Utils.print_error e
    end
  end
end
