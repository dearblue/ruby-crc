#!ruby

if ENV["RUBY_CRC_NOFAST"].to_i > 0
  require_relative "crc/_byruby"
else
  begin
    require File.join("crc", RUBY_VERSION[/\d+\.\d+/], "_turbo.so")
  rescue LoadError
    require_relative "crc/_byruby"
  end
end

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
#     p crc32.state     # => 1784883877
#     p crc32.digest    # => "jc*\xA5"
#     p crc32.hexdigest # => "6A632AA5"
#
module CRC
  CRC = self

  extend Utils

  module Utils
    extend self

    def bitreflect_reference(num, bitsize)
      n = 0
      bitsize.times { n <<= 1; n |= (num & 0x01); num >>= 1 }
      n
    end

    def bitreflect(num, bitsize)
      case
      when bitsize > 128
        bitreflect_reference(num, bitsize)
      when bitsize > 64
        bitreflect128(num) >> (128 - bitsize)
      when bitsize > 32
        bitreflect64(num) >> (64 - bitsize)
      when bitsize > 16
        bitreflect32(num) >> (32 - bitsize)
      when bitsize > 8
        bitreflect16(num) >> (16 - bitsize)
      else
        bitreflect8(num) >> (8 - bitsize)
      end
    end

    def build_table(bitsize, polynomial, unfreeze = false, slice: 16)
      bitmask = ~(~0 << bitsize)
      table = []
      Aux.slide_to_head(bitsize, 0, bitmask & polynomial, bitmask) do |xx, poly, csh, head, carries, pad|
        slice.times do |s|
          table << (t = [])
          256.times do |b|
            r = (s == 0 ? (b << csh) : (table[-2][b]))
            8.times { r = (r[head] == 0) ? (r << 1) : (((carries & r) << 1) ^ poly) }
            t << r
          end
          t.freeze unless unfreeze
          t
        end
        0
      end
      table.freeze unless unfreeze
      table
    end

    def build_reflect_table(bitsize, polynomial, unfreeze = false, slice: 16)
      polynomial = bitreflect(polynomial, bitsize)
      table = []
      slice.times do |s|
        table << (t = [])
        256.times do |b|
          r = (s == 0) ? b : table[-2][b]
          8.times { r = (r[0] == 0) ? (r >> 1) : ((r >> 1) ^ polynomial) }
          t << r
        end
        t.freeze unless unfreeze
        t
      end

      table.freeze unless unfreeze
      table
    end

    def export_table(table, bitsize, linewidth, indentsize = 2)
      bitsize0 = bitsize.to_i
      indent = " " * indentsize.to_i
      case
      when bitsize0 > 64 || bitsize0 < 1
        raise "invalid bitsize (expected to 1..64, but given #{bitsize})"
      when bitsize0 > 32
        packformat = "Q>"
        hexwidth = 16
      when bitsize0 > 16
        packformat = "N"
        hexwidth = 8
      when bitsize0 > 8
        packformat = "n"
        hexwidth = 4
      else # when bitsize0 > 0
        packformat = "C"
        hexwidth = 2
      end
      table = table.to_a.pack("#{packformat}*").unpack("H*")[0]
      table.gsub!(/(?<=\w)(?=\w{#{hexwidth}}{#{linewidth}}+$)/, "\n")
      table.gsub!(/(?<=\w)(?=\w{#{hexwidth}}+$)/, " ")
      table.gsub!(/(?<=\w)(?=\s|$)/, ",")
      table.gsub!(/(?:(?<=^)|(?<=\s))(?=\w)/, "0x")
      table.gsub!(/^/, "#{indent}  ")
      <<-EOS
#{indent}TABLE = [
#{table}
#{indent}].freeze
      EOS
    end

    #puts export_table(build_table(16, 0x1021), 16, 8); #abort "DEBUG EXIT"
    #puts export_table(build_table!(32, 0xEDB88320), 32, 8); abort "DEBUG EXIT"
  end

  extend Utils

  module Aux
    def self.DIGEST(state, bitsize)
      bits = (bitsize + 7) / 8 * 8
      seq = "".b
      (bits - 8).step(0, -8) { |i| seq << yield((state >> i) & 0xff) }
      seq
    end

    def self.digest(state, bitsize)
      DIGEST(state, bitsize) { |n| [n].pack("C") }
    end

    def self.hexdigest(state, bitsize)
      DIGEST(state, bitsize) { |n| "%02X" % n }
    end

    #
    # call-seq:
    #   slide_to_head(bitsize, state, polynomial, bitmask) { |padded_state, padded_polynomial, shift_input, off_msb, carries_mask, padding_size| padded_new_state } -> new_state
    #
    # YIELD(padded_state, padded_polynomial, shift_input, off_msb, carries_mask, padding_size) -> padded_new_state
    #
    def self.slide_to_head(bitsize, state, polynomial, bitmask)
      pad = bitsize & 0x07
      if pad == 0
        yield(state, polynomial, bitsize - 8, bitsize - 1, bitmask >> 1, 0)
      else
        pad = 8 - pad
        yield(state << pad, polynomial << pad, bitsize - 8 + pad, bitsize - 1 + pad, (bitmask << pad >> 1) | 0x7f, pad) >> pad
      end
    end
  end

  class Generator
    def crc(seq, state = nil)
      finish(update(seq, setup(state)))
    end

    def setup(state = nil)
      state ||= initial_state
      state = CRC.bitreflect(state, bitsize) if reflect_input ^ reflect_output
      state ^ xor_output
    end

    def finish(state)
      state = CRC.bitreflect(state, bitsize) if reflect_input ^ reflect_output
      state ^ xor_output
    end

    alias reflect_input? reflect_input
    alias reflect_output? reflect_output

    def digest(seq, state = nil)
      Aux.digest(crc(seq, state), bitsize)
    end

    def hexdigest(seq, state = nil)
      Aux.hexdigest(crc(seq, state), bitsize)
    end

    def to_s
      case
      when bitsize > 64 then width = 20
      when bitsize > 32 then width = 16
      when bitsize > 16 then width =  8
      when bitsize >  8 then width =  4
      else                   width =  2
      end

      if reflect_input
        ref = ", reflect-in#{reflect_output ? "/out" : ""}"
      else
        ref = reflect_output ? ", reflect-out" : ""
      end

      case initial_state
      when 0        then init = "0"
      when bitmask  then init = "~0"
      when 1        then init = "1"
      else               init = "0x%0#{width}X" % initial_state
      end

      case xor_output
      when 0        then xor = "0"
      when bitmask  then xor = "~0"
      when 1        then xor = "1"
      else               xor = "0x%0#{width}X" % xor_output
      end

      if nm = name
        "#{nm}(CRC-%d-0x%0#{width}X%s init=%s, xor=%s)" % [bitsize, polynomial, ref, init, xor]
      else
        "(CRC-%d-0x%0#{width}X%s init=%s, xor=%s)" % [bitsize, polynomial, ref, init, xor]
      end
    end

    def inspect
      "\#<#{self.class} #{to_s}>"
    end

    def pretty_inspect(q)
      q.text inspect
    end
  end

  class BasicCRC < Struct.new(:internal_state, :initial_state, :size)
    BasicStruct = superclass

    class BasicStruct
      alias state! internal_state
      alias set_state! internal_state=
    end

    #
    # call-seq:
    #   initialize(initial_state = nil, size = 0)
    #   initialize(seq, initial_state = nil, size = 0)
    #
    def initialize(*args)
      initialize_args(args) do |seq, initial_state, size|
        g = self.class::GENERATOR
        initial_state ||= g.initial_state
        super g.setup(initial_state.to_i), initial_state.to_i, size.to_i
        update(seq) if seq
      end
    end

    def reset(initial_state = self.initial_state, size = 0)
      g = self.class::GENERATOR
      initial_state ||= g.initial_state
      set_state! g.setup(initial_state)
      self.initial_state = initial_state
      self.size = size.to_i
      self
    end

    def update(seq)
      set_state! self.class::GENERATOR.update(seq, state!)
      self.size += seq.bytesize
      self
    end

    alias << update

    def state
      self.class::GENERATOR.finish(state!)
    end

    def +(crc2)
      raise ArgumentError, "not a CRC instance (#{crc2.inspect})" unless crc2.kind_of?(BasicCRC)
      c1 = self.class
      g1 = c1::GENERATOR
      g2 = crc2.class::GENERATOR
      unless g1.bitsize == g2.bitsize &&
             g1.polynomial == g2.polynomial &&
             g1.reflect_input == g2.reflect_input &&
             g1.reflect_output == g2.reflect_output &&
             # g1.initial_state == g2.initial_state &&
             g1.xor_output == g2.xor_output
        raise ArgumentError, "different CRC module (#{g1.inspect} and #{g2.inspect})"
      end
      c1.new(g1.combine(state, crc2.state, crc2.size), size + crc2.size)
    end

    def ==(a)
      case a
      when BasicCRC
        c1 = self.class
        g1 = c1::GENERATOR
        g2 = a.class::GENERATOR
        if g1.bitsize == g2.bitsize &&
           g1.polynomial == g2.polynomial &&
           g1.reflect_input == g2.reflect_input &&
           g1.reflect_output == g2.reflect_output &&
           # g1.initial_state == g2.initial_state &&
           g1.xor_output == g2.xor_output &&
           state! == a.state!
          true
        else
          false
        end
      when Integer
        state == a
      else
        super
      end
    end

    alias to_i state
    alias to_int state

    def to_a
      [state]
    end

    def digest
      Aux.DIGEST(state, self.class::GENERATOR.bitsize) { |n| [n].pack("C") }
    end

    # return digest as internal state
    def digest!
      Aux.DIGEST(state!, self.class::GENERATOR.bitsize) { |n| [n].pack("C") }
    end

    def hexdigest
      Aux.DIGEST(state, self.class::GENERATOR.bitsize) { |n| "%02X" % n }
    end

    # return hex-digest as internal state
    def hexdigest!
      Aux.DIGEST(state!, self.class::GENERATOR.bitsize) { |n| "%02X" % n }
    end

    alias to_str hexdigest
    alias to_s hexdigest

    def inspect
      "\#<#{self.class}:#{hexdigest}>"
    end

    def pretty_inspect(q)
      q.text inspect
    end

    class << self
      alias [] new

      #
      # call-seq:
      #   combine(crc1, crc2) -> new combined crc
      #   combine(crc1_int, crc2_int, crc2_len) -> new combined crc
      #
      def combine(crc1, crc2, len2 = nil)
        return crc1 + crc2 if crc1.kind_of?(BasicCRC) && crc2.kind_of?(BasicCRC)
        self::GENERATOR.combine(crc1.to_i, crc2.to_i, len2)
      end

      def crc(seq, state = nil)
        self::GENERATOR.crc(seq, state)
      end

      def digest(seq, state = nil)
        Aux.digest(self::GENERATOR.crc(seq, state), self::GENERATOR.bitsize)
      end

      def hexdigest(seq, state = nil)
        Aux.hexdigest(self::GENERATOR.crc(seq, state), self::GENERATOR.bitsize)
      end

      def inspect
        if const_defined?(:GENERATOR)
          if nm = name
            "#{nm}(#{self::GENERATOR.to_s})"
          else
            super.sub(/(?=\>$)/) { " #{self::GENERATOR.to_s}" }
          end
        else
          super
        end
      end

      def pretty_inspect(q)
        q.text inspect
      end
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
  end

  MODULE_TABLE = {}

  class << self
    def lookup(modulename)
      modulename1 = modulename.to_s.gsub(/[\W_]+/, "")
      modulename1.downcase!
      MODULE_TABLE[modulename1] or raise NameError, "modulename is not matched (for #{modulename})"
    end

    alias [] lookup

    def crc(modulename, seq, state = nil)
      lookup(modulename).crc(seq, state)
    end

    def digest(modulename, seq, state = nil)
      lookup(modulename).digest(seq, state)
    end

    def hexdigest(modulename, seq, state = nil)
      lookup(modulename).hexdigest(seq, state)
    end

    def create_module(bitsize, polynomial, initial_state = 0, refin = true, refout = true, xor = ~0, name = nil)
      g = Generator.new(bitsize, polynomial, initial_state, refin, refout, xor, name)
      crc = Class.new(BasicCRC)
      crc.const_set :GENERATOR, g
      crc
    end
  end

  require_relative "crc/_modules"
  require_relative "crc/_combine"

  #
  # Create CRC module classes.
  #
  LIST.each do |bitsize, polynomial, refin, refout, initial_state, xor, check, *names|
    names.map! { |nm| nm.freeze }

    crc = create_module(bitsize, polynomial, initial_state, refin, refout, xor, names[0])
    crc.const_set :NAME, names

    names.each do |nm|
      nm1 = nm.downcase.gsub(/[\W_]+/, "")
      if MODULE_TABLE.key?(nm1)
        raise NameError, "collision crc-module name: #{nm} (#{crc::GENERATOR} and #{MODULE_TABLE[nm1]::GENERATOR})"
      end
      MODULE_TABLE[nm1] = crc
    end
    name = names[0].sub(/(?<=\bCRC)-(?=\d+)/, "").gsub(/[\W]+/, "_")
    const_set(name, crc)

    check = Integer(check.to_i) if check
    crc.const_set :CHECK, check

    g = crc::GENERATOR
    define_singleton_method(name.upcase, ->(*args) { crc.new(*args) })
    define_singleton_method(name.downcase, ->(*args) { g.crc(*args) })
  end

  if $0 == __FILE__
    $stderr.puts "#{__FILE__}:#{__LINE__}: SELF CHECK for CRC modules (#{File.basename($".grep(/_(?:byruby|turbo)/)[0]||"")})\n"
    MODULE_TABLE.values.uniq.each do |crc|
      g = crc::GENERATOR
      check = crc::CHECK
      checked = g.crc("123456789")
      case check
      when nil
        $stderr.puts "| %20s(\"123456789\") = %16X (check only)\n" % [g.name, checked]
      when checked
        ;
      else
        $stderr.puts "| %20s(\"123456789\") = %16X (expect to %X)\n" % [g.name, checked, check]
      end
    end
    $stderr.puts "#{__FILE__}:#{__LINE__}: DONE SELF CHECK\n"

    exit
  end
end
