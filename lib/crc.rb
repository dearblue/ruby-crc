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
      when bitsize > 64
        bitreflect_reference(num, bitsize)
      when bitsize > 32
        bitreflect64(num) >> (64 - bitsize)
      when bitsize > 16
        bitreflect32(num) >> (32 - bitsize)
      when bitsize >  8
        bitreflect16(num) >> (16 - bitsize)
      else
        bitreflect8(num)  >> ( 8 - bitsize)
      end
    end

    if false
      20.times do
        n = rand(1 << 62)
        bitsize = rand(64) + 1
        a = bitreflect_reference(n, bitsize)
        b = bitreflect(n, bitsize)
        puts "0x%016X (%2d) => 0x%016X, 0x%016X (%s)" % [n, bitsize, a, b, (a == b)]
      end
      puts
      require "benchmark"
      Benchmark.bm(24) do |bm|
        t = 1 << 16
        4.times do
          bm.report("reference(-1, 8)") { t.times { bitreflect_reference(-1, 8) } }
          bm.report("reference(-1, 16)") { t.times { bitreflect_reference(-1, 16) } }
          bm.report("reference(-1, 24)") { t.times { bitreflect_reference(-1, 24) } }
          bm.report("reference(-1, 32)") { t.times { bitreflect_reference(-1, 32) } }
          bm.report("reference(-1, 64)") { t.times { bitreflect_reference(-1, 64) } }
          bm.report("bitreflect(-1, 8)") { t.times { bitreflect(-1, 8) } }
          bm.report("bitreflect(-1, 16)") { t.times { bitreflect(-1, 16) } }
          bm.report("bitreflect(-1, 24)") { t.times { bitreflect(-1, 24) } }
          bm.report("bitreflect(-1, 32)") { t.times { bitreflect(-1, 32) } }
          bm.report("bitreflect(-1, 64)") { t.times { bitreflect(-1, 64) } }
          puts
        end
      end
      abort "TEST ABORT"
    end

    def build_table(bitsize, polynomial)
      bitmask = ~(~0 << bitsize)
      carrydown = bitmask >> 1
      polynomial = bitmask & polynomial
      table = []
      head = 7
      256.times do |i|
        8.times { i = (i[head] == 0) ? (i << 1) : (((i & carrydown) << 1) ^ polynomial) }
        table << i
      end

      table.freeze
    end

    def build_table8(bitsize, polynomial, unfreeze = false)
      bitmask = ~(~0 << bitsize)
      table = []
      Aux.slide_to_head(bitsize, 0, bitmask & polynomial, bitmask) do |xx, poly, csh, head, carries, pad|
        8.times do |s|
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

    def build_table!(bitsize, polynomial)
      polynomial = bitreflect(polynomial, bitsize)
      table = []
      256.times do |i|
        8.times { i = (i[0] == 0) ? (i >> 1) : ((i >> 1) ^ polynomial) }
        table << i
      end

      table.freeze
    end

    def build_table8!(bitsize, polynomial, unfreeze = false)
      polynomial = bitreflect(polynomial, bitsize)
      table = []
      16.times do |s|
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
      state ^= xor_output
      state = CRC.bitreflect(state, bitsize) if reflect_input ^ reflect_output
      state
    end

    def finish(state)
      state = CRC.bitreflect(state, bitsize) if reflect_input ^ reflect_output
      state ^ xor_output
    end

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
        "#{nm}(CRC-%d-0x%0#{width}X init=%s%s, xor=%s)" % [bitsize, polynomial, init, ref, xor]
      else
        "(CRC-%d-0x%0#{width}X init=%s%s, xor=%s)" % [bitsize, polynomial, init, ref, xor]
      end
    end

    def inspect
      "\#<#{self.class} #{to_s}>"
    end

    def pretty_inspect(q)
      q.text inspect
    end
  end

  class BasicCRC < Struct.new(:internal_state, :initial_state)
    BasicStruct = superclass

    class BasicStruct
      alias state! internal_state
      alias set_state! internal_state=
    end

    def initialize(initial_state = nil)
      generator = self.class::GENERATOR
      initial_state ||= generator.initial_state
      super generator.setup(initial_state), initial_state
    end

    def reset(initial_state = self.initial_state)
      generator = self.class::GENERATOR
      initial_state ||= generator.initial_state
      set_state! generator.setup(initial_state)
      self.initial_state = initial_state
      self
    end

    def update(seq)
      set_state! self.class::GENERATOR.update!(seq, state!)
      self
    end

    alias << update

    def finish
      self.class::GENERATOR.finish(state!)
    end

    alias state finish

    def digest
      Aux.DIGEST(state, self.class::GENERATOR.bitsize) { |n| [n].pack("C") }
    end

    # ビット反転せずに値を返す
    def digest!
      Aux.DIGEST(state!, self.class::GENERATOR.bitsize) { |n| [n].pack("C") }
    end

    def hexdigest
      Aux.DIGEST(state, self.class::GENERATOR.bitsize) { |n| "%02X" % n }
    end

    # ビット反転せずに値を返す
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

      def crc(seq, state = nil)
        self::GENERATOR.crc(seq, state)
      end

      def digest(seq, state = nil)
        Aux.digest(self::GENERATOR.crc(seq, state), self::GENERATOR.bitsize)
      end

      def hexdigest(seq, state = nil)
        Aux.hexdigest(self::GENERATOR.crc(seq, state), self::GENERATOR.bitsize)
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
      generator = Generator.new(bitsize, polynomial, initial_state, refin, refout, xor, name)
      crc = Class.new(BasicCRC)
      crc.const_set :GENERATOR, generator
      crc
    end
  end

  SELF_TEST = ($0 == __FILE__) ? true : false
end

require_relative "crc/_modules"
