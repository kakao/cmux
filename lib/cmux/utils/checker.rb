#!/usr/bin/env ruby

module CMUX
  module Utils
    # Check arguments.
    module Checker
      class << self
        # Check whether yes or no.
        def yn?(*args)
          ans = CMUX::Utils.qna(*args) until %w[y Y n N].include?(ans)
          %w[y Y].include?(ans) ? true : false
        end

        # Check whether the port is open or closed.
        def port_open?(ip, port, seconds = 1)
          Timeout.timeout(seconds) do
            ip ||= Socket.ip_address_list.detect(&:ipv4_private?).ip_address
            TCPSocket.new(ip, port).close
            true
          end
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Timeout::Error
          false
        end

        # Check whether CMUX command or not.
        def cmux_cmd?(cmd)
          Commands::CMDS.key?(cmd)
        end

        # Check whether CMUX alias or not.
        def cmux_alias?(arg)
          Commands::CMDS.values.map { |e| e[:alias] }.include?(arg)
        end
      end
    end
  end
end
