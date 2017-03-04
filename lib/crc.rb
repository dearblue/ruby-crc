#!ruby

if ENV["RUBY_CRC_NOFAST"].to_i > 0
  require_relative "crc/_byruby"
  CRC::IMPLEMENT = :ruby
else
  begin
    gem "crc-turbo", ">= 0.3", "< 0.5"
    require File.join("crc", RUBY_VERSION[/\d+\.\d+/], "_turbo.so")
    CRC::IMPLEMENT = :turbo
  rescue LoadError, Gem::MissingSpecVersionError
    require_relative "crc/_byruby"
    CRC::IMPLEMENT = :ruby
  end
end

require_relative "crc/version"

#
# This is a general CRC generator.
#
# When you want to use CRC-32 module, there are following ways:
#
# 1. Generate CRC-32'd value at direct:
#
#     CRC.crc32("123456789") # => 3421780262
#
# 2. Generate CRC-32'd hex-digest at direct:
#
#     CRC::CRC32.hexdigest("123456789") # => "CBF43926"
#
# 3. Streaming process:
#
#     crc32 = CRC::CRC32.new  # => #<CRC::CRC32:00000000>
#     IO.foreach("/boot/kernel/kernel", nil, 262144, mode: "rb") do |s|
#       crc32 << s
#     end
#     p crc32           # => #<CRC::CRC32:6A632AA5>
#     p crc32.crc       # => 1784883877
#     p crc32.digest    # => "jc*\xA5"
#     p crc32.hexdigest # => "6A632AA5"
#
class CRC
  CRC = self

  extend Utils

  require_relative "crc/_extensions"
  require_relative "crc/_utils"
  require_relative "crc/_aux"

  using Extensions

  module ModuleClass
    def setup(crc = nil)
      crc ||= initial_crc
      crc ^= xor_output
      crc = CRC.bitreflect(crc, bitsize) if reflect_input? ^ reflect_output?
      crc & bitmask
    end

    alias init setup

    def finish(state)
      state = CRC.bitreflect(state, bitsize) if reflect_input? ^ reflect_output?
      state ^ xor_output & bitmask
    end

    def crc(seq, crc = nil)
      finish(update(seq, setup(crc)))
    end

    def digest(seq, crc = nil)
      Aux.digest(crc(seq, crc), bitsize)
    end

    def hexdigest(seq, crc = nil)
      Aux.hexdigest(crc(seq, crc), bitsize)
    end

    def variant?(obj)
      obj.variant_for?(self)
    end

    #
    # call-seq:
    #   combine(crc1, crc2) -> new combined crc
    #   combine(crc1_int, crc2_int, crc2_len) -> new combined crc
    #
    def combine(*args)
      case args.size
      when 2
        unless args[0].kind_of?(CRC) && args[1].kind_of?(CRC)
          raise ArgumentError, "When given two arguments, both arguments are should be CRC instance"
        end

        crc1 + crc2
      when 3
        Aux.combine(Integer(args[0].to_i), Integer(args[1].to_i), Integer(args[2].to_i),
                    bitsize, polynomial, initial_crc, reflect_input?, reflect_output?, xor_output)
      else
        raise ArgumentError, "wrong number of arguments (given #{args.size}, expect 2..3)"
      end
    end

    def to_str
      case
      when bitsize > 64 then width = 20
      when bitsize > 32 then width = 16
      when bitsize > 16 then width =  8
      when bitsize >  8 then width =  4
      else                   width =  2
      end

      if reflect_input?
        ref = " reflect-in#{reflect_output? ? "/out" : ""}"
      else
        ref = reflect_output? ? " reflect-out" : ""
      end

      case initial_crc
      when 0        then init = "0"
      when bitmask  then init = "~0"
      when 1        then init = "1"
      else               init = "0x%0#{width}X" % initial_crc
      end

      case xor_output
      when 0        then xor = "0"
      when bitmask  then xor = "~0"
      when 1        then xor = "1"
      else               xor = "0x%0#{width}X" % xor_output
      end

      "CRC-%d-0x%0#{width}X%s init=%s xor=%s" % [bitsize, polynomial, ref, init, xor]
    end

    def inspect
      "#{super}{#{to_str}}"
    end

    def pretty_inspect(q)
      q.text inspect
    end
  end

  attr_accessor :state, :size

  #
  # call-seq:
  #   initialize(initial_crc = nil, size = 0)
  #   initialize(seq, initial_crc = nil, size = 0)
  #
  def initialize(*args)
    initialize_args(args) do |seq, initial_crc, size|
      m = self.class
      @state = m.setup((initial_crc || m.initial_crc).to_i)
      @size = size.to_i
      update(seq) if seq
    end
  end

  def reset(initial_crc = nil, size = 0)
    m = self.class
    @state = m.setup((initial_crc || m.initial_crc).to_i)
    @size = size.to_i
    self
  end

  def update(seq)
    @state = self.class.update(seq, state)
    @size += seq.bytesize
    self
  end

  alias << update

  def crc
    self.class.finish(state)
  end

  def +(crc2)
    m1 = get_crc_module
    m2 = crc2.get_crc_module
    raise ArgumentError, "not a CRC instance (#{crc2.inspect})" unless m2
    unless m2.variant_for?(m1)
      raise ArgumentError, "different CRC module (#{m1.inspect} and #{m2.inspect})"
    end
    m1.new(m1.combine(crc, crc2.crc, crc2.size), size + crc2.size)
  end

  def ==(a)
    case a
    when CRC
      if variant_for?(a) && state == a.state
        true
      else
        false
      end
    when Integer
      crc == a
    else
      super
    end
  end

  alias to_i crc
  alias to_int crc

  def to_a
    [crc]
  end

  def digest
    Aux.digest(crc, self.class.bitsize)
  end

  # return digest as internal state
  def digest!
    Aux.digest(state, self.class.bitsize)
  end

  def hexdigest
    Aux.hexdigest(crc, self.class.bitsize)
  end

  # return hex-digest as internal state
  def hexdigest!
    Aux.hexdigest(state, self.class.bitsize)
  end

  alias to_str hexdigest
  alias to_s hexdigest

  def inspect
    "\#<#{self.class}:#{hexdigest}>"
  end

  def pretty_inspect(q)
    q.text inspect
  end

  private
  def initialize_args(args)
    case args.size
    when 0
      yield nil, nil, 0
    when 1
      if args[0].kind_of?(String)
        yield args[0], nil, 0
      else
        yield nil, args[0], 0
      end
    when 2
      if args[0].kind_of?(String)
        yield args[0], args[1], 0
      else
        yield nil, args[0], args[1].to_i
      end
    when 3
      yield args[0], args[1], args[2].to_i
    else
      raise ArgumentError, "wrong argument size (given #{args.size}, expect 0..3)"
    end
  end

  MODULE_TABLE = {}

  class << self
    def lookup(modulename)
      modulename1 = modulename.to_s.gsub(/[\W_]+/, "")
      modulename1.downcase!
      MODULE_TABLE[modulename1] or raise NameError, "modulename is not matched (for #{modulename})"
    end

    alias [] lookup

    def crc(modulename, seq, crc = nil)
      lookup(modulename).crc(seq, crc)
    end

    def digest(modulename, seq, crc = nil)
      lookup(modulename).digest(seq, crc)
    end

    def hexdigest(modulename, seq, crc = nil)
      lookup(modulename).hexdigest(seq, crc)
    end
  end

  require_relative "crc/_modules"
  require_relative "crc/_combine"
  require_relative "crc/_shift"
  require_relative "crc/_magic"
  require_relative "crc/_file"

  #
  # Create CRC module classes.
  #
  LIST.each do |bitsize, polynomial, refin, refout, initial_crc, xor, check, *names|
    names.flatten!
    names.map! { |nm| nm.freeze }

    crc = CRC.new(bitsize, polynomial, initial_crc, refin, refout, xor, names[0])
    crc.const_set :NAME, names

    names.each do |nm|
      nm1 = nm.downcase.gsub(/[\W_]+/, "")
      if MODULE_TABLE.key?(nm1)
        raise NameError, "collision crc-module name: #{nm} (#{crc::GENERATOR} and #{MODULE_TABLE[nm1]::GENERATOR})"
      end
      MODULE_TABLE[nm1] = crc

      name = nm.sub(/(?<=\bCRC)-(?=\d+)/, "").gsub(/[\W]+/, "_")
      const_set(name, crc)

      define_singleton_method(name.upcase, ->(*args) { crc.new(*args) })
      define_singleton_method(name.downcase, ->(*args) {
        if args.size == 0
          crc
        else
          crc.crc(*args)
        end
      })
    end

    check = Integer(check.to_i) if check
    crc.const_set :CHECK, check
  end

  if $0 == __FILE__
    $stderr.puts "#{__FILE__}:#{__LINE__}: SELF CHECK for CRC modules (#{File.basename($".grep(/_(?:byruby|turbo)/)[0]||"")})\n"
    MODULE_TABLE.values.uniq.each do |crc|
      check = crc::CHECK
      checked = crc.crc("123456789")
      case check
      when nil
        $stderr.puts "| %20s(\"123456789\" * 1) = %16X (check only)\n" % [crc.name, checked]
      when checked
        ;
      else
        $stderr.puts "| %20s(\"123456789\" * 1) = %16X (expect to %X)\n" % [crc.name, checked, check]
      end

      check = 9.times.reduce(crc.new) { |a, x| a + crc[crc::CHECK, 9] }
      checked = crc["123456789" * 9]
      case check
      when nil
        $stderr.puts "| %20s(\"123456789\" * 9) = %16X (check only)\n" % [crc.name, checked]
      when checked
        ;
      else
        $stderr.puts "| %20s(\"123456789\" * 9) = %16X (expect to %X)\n" % [crc.name, checked, check]
      end
    end
    $stderr.puts "#{__FILE__}:#{__LINE__}: DONE SELF CHECK\n"

    exit
  end
end
