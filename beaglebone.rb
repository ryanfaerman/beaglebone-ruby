module Beagle
  GPIOEXPORTS = {}
  PWMEXPORTS = {}

  PATHS = {
    :gpio => '/sys/class/gpio',
    :capemgr => '/sys/devices/bone_capemgr.9',
    :analog => '/sys/devices/ocp.3/helper.15',
    :pwm =>'/sys/devices/ocp.3/',
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

    def value
      File.open(File.join(PATHS[:gpio], "gpio#{@pin.to_s}", "value")) do |gpio_value|
        @value = gpio_value.read
      end

      if @value.to_i == 1
        :high
      elsif @value.to_i == 0
        :low
      end
    end

    def needs_export?
      !Beagle::GPIOEXPORTS.keys.include?(@pin)
    end

    def export
      puts "exporting GPIO pin #{self.to_s}"
      File.open(File.join(PATHS[:gpio], 'export'), 'w') do |exports|
        exports << @pin
      end
      Beagle::GPIOEXPORTS[@pin] = @options
    end

    def to_s
      port = @pin / 32
      pin = @pin % 32

      "gpio#{port}_#{pin}"
    end
  end

  class Analog
    @@ENABLED = false

    def initialize(pin)
      @pin = parse(pin)
      enable if need_enabling?
    end

    def parse(pin)
      p = pin.to_i
      raise ArgumentError.new("Bad analog pin #{p}") unless p.between?(0,7)
      p
    end

    def need_enabling?
      !@@ENABLED
    end

    def enable
      puts "enabling analog pins"
      File.open(File.join(PATHS[:capemgr], 'slots'), 'w') do |slots|
        slots << "cape-bone-iio\n"
      end
      @@ENABLED = true
    end

    def value
      val = -1
      File.open(File.join(PATHS[:analog], "AIN#{@pin.to_s}"), 'r') do |analog_value|
        val = analog_value.read
      end
      val = val.to_i
      raise RangeError.new("Failed to read from pin #{@pin}") unless val.between?(0,4096)
      val
    end
  end


  class PWM
    attr_accessor :duty, :period, :run

    def initialize(pin)
      @pin = parse(pin)
      export if needs_export?
    end

    def parse(pin)
      p = pin.to_s
      p
    end

    def needs_export?
      !Beagle::PWMEXPORTS.keys.include?(@pin)
    end

    def export
      puts "exporting PWM pin #{self.to_s}"
      File.open(File.join(PATHS[:capemgr], 'slots'), 'w') do |slots|
        slots << "am33xx_pwm\n"
      end

      File.open(File.join(PATHS[:capemgr], 'slots'), 'w') do |slots|
        slots << "bone_pwm_P#{self.to_s}""\n"
      end
      Beagle::PWMEXPORTS[@pin] = Dir.glob(File.join(PATHS[:pwm], "pwm_test_P#{self.to_s}.*")).first
    end

    def duty=(v)
      v = v.to_i
      File.open(File.join(Beagle::PWMEXPORTS[@pin], "duty"), 'w') do |f|
        f << "#{v}\n"
      end
    end

    def period=(v)
      v = v.to_i
      File.open(File.join(Beagle::PWMEXPORTS[@pin], "period"), 'w') do |f|
        f << "#{v}\n"
      end
    end

    def run=(v)
      v = v.to_i
      raise ArgumentError.new("Bad run value #{v}") unless v.between?(0,1)
      File.open(File.join(Beagle::PWMEXPORTS[@pin], "run"), 'w') do |f|
        f << "#{v}\n"
      end
    end

    def to_s
      @pin.to_s
    end
  end
end