#!/usr/bin/env ruby

# String
class String
  # Colorized string - default.
  def default
    "\e[0m#{self}\e[0m"
  end

  # Colorized string - black.
  def black
    "\e[30m#{self}\e[0m"
  end

  # Colorized string - red.
  def red
    "\e[31m#{self}\e[0m"
  end

  # Colorized string - green.
  def green
    "\e[32m#{self}\e[0m"
  end

  # Colorized string - yellow.
  def yellow
    "\e[33m#{self}\e[0m"
  end

  # Colorized string - blue.
  def blue
    "\e[34m#{self}\e[0m"
  end

  # Colorized string - magenta.
  def magenta
    "\e[35m#{self}\e[0m"
  end

  # Colorized string - cyan.
  def cyan
    "\e[36m#{self}\e[0m"
  end

  # Colorized string - gray.
  def gray
    "\e[37m#{self}\e[0m"
  end

  # Word wrap.
  def wrap(width = 80, char = "\n")
    scan(/\S.{0,#{width - 2}}\S(?=\s|$)|\S+/).join(char)
  end

  # Digit justification.
  def djust(just = 5)
    gsub(/\d+/) { |n| n.rjust(just, '0') }
  end
end

# Enumerable
module Enumerable
  # Parallel Map.
  def pmap
    map { |x| Thread.new { yield x } }.map { |t| t.join.value }
  end
end

# Hash
class Hash
  # Recursive dig.
  def dig(*path)
    path.inject(self) do |location, key|
      location.respond_to?(:keys) ? location[key] : nil
    end
  end

  # Marshal dump
  def marshal_dump
    self.inspect
  end

  # Marshal load
  def marshal_load str
    self.merge!(eval(str))
  end

  # Slice
  def slice(*keys)
    keys = keys.select { |k| key?(k) }
    keys.zip(values_at(*keys)).to_h
  end
end

# Array
class Array
  # Define to_h method for ruby < 2.1.
  unless Array.instance_methods.include?(:to_h)
    def to_h
      Hash[self]
    end
  end
end
