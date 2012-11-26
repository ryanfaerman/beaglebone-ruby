module Beagle
  EXPORTS = {}
  PATHS = {
    :gpio => 'tmp/sys/class/gpio',
    :omap_mux => '/sys/kernel/debug/omap_mux'
  }

  def log(msg)
    puts "#{msg.inspect}"
  end

  class Gpio
    DIRECTIONS = %w(in out).freeze
    STATES = %w(low high 0 1).freeze

    attr_accessor :direction, :state

    def initialize(pin, options = {})
      @pin = parse(pin)
      @options = options

      export if needs_export?

      self.value = @options[:default] || :low
      self.direction = @options[:direction] || :out
      
    end

    def parse(pin)
      p = pin.to_s.gsub(/gpio/i, '')
      if p =~ /\d_\d*/
        pin_bits = p.split('_')
        pin_bits[0].to_i*32 + pin_bits[1].to_i
      else
        pin.to_i
      end
    end

    def direction=(dir)
      dir = dir.to_s.downcase.gsub(/put/, '')
      if DIRECTIONS.include? dir
        @direction = dir.to_sym
        File.open(File.join(PATHS[:gpio], "gpio#{@pin.to_s}", "direction"), 'w') do |gpio_direction|
          gpio_direction << @direction
        end
      else
        raise ArgumentError.new("Invalid GPIO direction")
      end
    end

    def value=(s)

      if STATES.include? s.to_s
        if [1, :high].include? s
          @value = :high
          val = 1
        elsif [0, :low].include? s
          @value = :low
          val = 0
        end
        @value = s.to_sym
        File.open(File.join(PATHS[:gpio], "gpio#{@pin.to_s}", "value"), 'w') do |gpio_value|
          gpio_value << val
        end
      elsif s.is_a?(Integer) && [0..255].include?(s)
        puts "Analog value of #{s}"
      else
        raise ArgumentError.new("Invalid GPIO value")
      end
    end

    def needs_export?
      !Beagle::EXPORTS.keys.include?(@pin)
    end

    def export
      puts "exporting #{self.to_s}"
      File.open(File.join(PATHS[:gpio], 'exports'), 'w') do |exports|
        exports << @pin
      end
      Beagle::EXPORTS[@pin] = @options
    end

    def to_s
      port = @pin / 32
      pin = @pin % 32

      "gpio#{port}_#{pin}"
    end
  end

end