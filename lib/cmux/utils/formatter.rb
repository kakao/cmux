module CMUX
  module Utils
    # Convert to a specified format
    module Formatter
      class << self
        # Create well-formed table
        def table(args = {})
          table = []
          body  = args[:header] ? args[:body].unshift(args[:header]) : args[:body]
          maxes = body.transpose.map { |g| g.map { |e| e.gsub(ANSI, '').length }.max }

          separator = -> { table << maxes.map { |m| '-' * m }.join(' ') }

          row_generator = lambda do |row|
            row.zip(maxes).map.with_index do |pair, idx|
              ansi = args.fetch(:strip_ansi, true)
              data = ansi ? pair.first.gsub(ANSI, '') : pair.first
              pad  = pair.last + data.length - data.gsub(ANSI, '').length
              data = data.gsub(/[[:space:]]/, "\u00A0")
              args[:rjust] && args[:rjust].include?(idx) ? data.rjust(pad) : data.ljust(pad)
            end.join(' ')
          end

          body.each_with_index do |row, idx|
            row = row_generator.call(row)
            table.push(row)
            args[:header] && idx.zero? && separator.call
          end

          table
        end

        # Get current datetime with 'yyyy-mm-dd HH:MI:SS' format
        def cur_dt
          Time.new.strftime("%Y-%m-%d %H:%M:%S")
        end

        # Print string (with current datetime)
        def print_str(str, dt = false)
          str = dt ? "#{cur_dt} #{str}" : str
          print str
        end

        # Puts string (with current datetime)
        def puts_str(str, dt = false)
          str = dt ? "#{cur_dt} #{str}" : str
          puts str
        end

        # Convert boolean to Y/N
        def to_yn(arg)
          arg ? 'Y' : 'N'
        end

        # Horizonali splitter
        def horizonal_splitter(str)
          puts str * Utils.console_col_size
        end
      end
    end
  end
end
