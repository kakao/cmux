module CMUX
  # Raised when a command not registered in cmux is executed.
  class CMUXCommandError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "Invalid CMUX command: #{@message}"
    end
  end

  # Raised when two or more commands are executed without being attached to
  # the tmux session.
  class CMUXNotInTMUXError < StandardError
    def message
      'You are not in TMUX session!!!'
    end
  end

  # Raised when the arguments are not supplied.
  class CMUXNoArgumentError < StandardError
    def message
      'No arugment supplied'
    end
  end

  # Raised when the arguments are wrong.
  class CMUXInvalidArgumentError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "'#{@message}' is invaild argument"
    end
  end

  # Raised when the `cm.yaml` is not configured.
  class CMUXCMListError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "#{@message}: The `cm.yaml` must be configured. Please see the README."
    end
  end

  # Raised when no principal is defined in the `cm.yaml`.
  class CMUXNoPrincipalError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "A principal is not defined in '#{CM_LIST}' for this cluster"
    end
  end

  # Raised when CMUX can not reach to the Cloudera Manager API.
  class CMAPIError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "Can not reach to the Cloudera Manager API: #{@message}"
    end
  end

  # Raised when CMUX can not set the auto balancer via `hbase-tools`.
  class CMUXHBaseToolBalancerError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "Can not set the auto balancer: #{@message}"
    end
  end

  # Raised when CMUX can not empty regions via `hbase-tools`.
  class CMUXHBaseToolEmptyRSError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "Can not empty region: #{@message}"
    end
  end

  # Raised when CMUX can not export regions via `hbase-tools`.
  class CMUXHBaseToolExportRSError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "Can not export region: #{@message}"
    end
  end

  # Raised when CMUX can not import regions via `hbase-tools`.
  class CMUXHBaseToolImportRSError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      "Can not import region: #{@message}"
    end
  end

  # Raise when no nameservices is configured in cluster.
  class CMUXNameServiceError < StandardError
    def message
      'Does not have any configured nameservices.'
    end
  end

  # Raise when no nameservice is configured for HA in cluster.
  class CMUXNameServiceHAError < StandardError
    def message
      'Does not have at least one nameservice configured for High Availability.'
    end
  end

  # Raise when kerberos configuration are wrong.
  class CMUXKerberosError < StandardError
  end

  # Raise when the specified time to wait is exceeded.
  class CMUXMaxWaitTimeError < StandardError
    def initialize(msg = nil)
      @message = msg
    end

    def message
      'Max wait time error: ' \
      "#{@message} seconds have passed since the command was executed."
    end
  end

  # CMUX utilities.
  module Utils
    class << self
      # Print error messages.
      def print_error(error)
        tput_rmcup
        msg = "cmux: #{error.message}"
        puts msg.wrap(console_col_size - 6, "\n      ").red

        error.backtrace.each do |e|
          print '      '
          puts e.wrap(console_col_size - 6, "\n      ")
        end
      end

      # Print CMUX command error messages.
      def print_cmux_command_error(error)
        puts "cmux: #{error.message}\n".red
        puts 'Did you mean one of these?'
        print_cmux_cmds
        exit
      end

      # SystemExit exception.
      def system_exit
        tput_rmcup
        raise
      end

      # Interrupt exception.
      def interrupt
        exit_with_msg("\nInterrupted".red, false)
      end
    end
  end
end
