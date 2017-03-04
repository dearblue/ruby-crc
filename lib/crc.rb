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

  module Extentions
    # refinements
    # * each_byte
    # * reverse_each_byte
    ;

    refine Array do
      def each_byte
        return to_enum(:each_byte) unless block_given?
        each { |ch| yield 0xff & ch }
        self
      end

      def reverse_each_byte
        return to_enum(:reverse_each_byte) unless block_given?
        reverse_each { |ch| yield 0xff & ch }
        self
      end
    end

    refine BasicObject do
      def each_byte(&block)
        Array(self).each_byte(&block)
      end

      def reverse_each_byte(&block)
        Array(self).reverse_each_byte(&block)
      end
    end

    refine String do
      def reverse_each_byte
        return to_enum(:reverse_each_byte) unless block_given?
        (bytesize - 1).downto(0) { |i| yield getbyte(i) }
        self
      end
    end

    # refinements:
    # * convert_internal_state_for
    # * convert_target_state_for
    ;

    refine BasicObject do
      def convert_internal_state_for(crc)
        raise TypeError, "cant convertion to #{crc.to_s} (for #{inspect})"
      end

      def convert_target_state_for(crc)
        raise TypeError, "cant convertion to #{crc.to_s} (for #{inspect})"
      end
    end

    refine NilClass do
      def convert_internal_state_for(crc)
        crc.setup(crc.initial_crc)
      end

      def convert_target_state_for(crc)
        crc.setup(0)
      end
    end

    refine String do
      def convert_internal_state_for(crc)
        crc.update(self, crc.setup(crc.initial_crc))
      end
    end

    refine Integer do
      def convert_internal_state_for(crc)
        crc.setup(self)
      end

      def convert_target_state_for(crc)
        crc.setup(self)
      end
    end

    refine CRC do
      def convert_internal_state_for(crc)
        unless crc.variant?(self)
          raise "not variant crc module (expect #{crc.to_s}, but self is #{inspect})"
        end

        state
      end

      def convert_target_state_for(crc)
        unless crc.variant?(self)
          raise "not variant crc module (expect #{crc.to_s}, but self is #{inspect})"
        end

        state
      end
    end

    # refinements:
    # * splitbytes
    ;

    refine Integer do
      def splitbytes(bucket, bytes, is_little_endian)
        if is_little_endian
          bytes.times { |i| bucket.pushbyte self >> (i * 8) }
        else
          (bytes - 1).downto(0) { |i| bucket.pushbyte self >> (i * 8) }
        end

        bucket
      end
    end

    refine String do
      def pushbyte(ch)
        self << (0xff & ch).chr(Encoding::BINARY)
      end
    end

    refine Array do
      def pushbyte(ch)
        self << (0xff & ch)
      end
    end
  end

  using Extentions

  #
  # Utilities.
  #
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
        table << (t = [])
        256.times do |b|
          b <<= csh
          8.times { b = (b[head] == 0) ? (b << 1) : (((carries & b) << 1) ^ poly) }
          t << b
        end
        t.freeze unless unfreeze

        carries8 = carries >> 7
        (1...slice).step do
          tt = table[-1]
          table << (t = [])
          256.times do |b|
            t << (table[0][tt[b] >> csh] ^ ((carries8 & tt[b]) << 8))
          end
          t.freeze unless unfreeze
        end
        0
      end
      table.freeze unless unfreeze
      table
    end

    def build_reflect_table(bitsize, polynomial, unfreeze = false, slice: 16)
      polynomial = bitreflect(polynomial, bitsize)
      table = []

      table << (t = [])
      256.times do |b|
        8.times { b = (b[0] == 0) ? (b >> 1) : ((b >> 1) ^ polynomial) }
        t << b
      end
      t.freeze unless unfreeze

      (1...slice).step do
        tt = table[-1]
        table << (t = [])
        256.times do |b|
          t << (table[0][tt[b] & 0xff] ^ (tt[b] >> 8))
        end
        t.freeze unless unfreeze
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
  end

  extend Utils

  #
  # Internal using module.
  #
  module Aux
    def self.DIGEST(num, bitsize)
      bits = (bitsize + 7) / 8 * 8
      seq = ""
      (bits - 8).step(0, -8) { |i| seq << yield((num >> i) & 0xff) }
      seq
    end

    def self.digest(num, bitsize)
      DIGEST(num, bitsize) { |n| n.chr(Encoding::BINARY) }
    end

    def self.hexdigest(num, bitsize)
      DIGEST(num, bitsize) { |n| "%02X" % n }
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
      case
      when obj.kind_of?(CRC)
        mod = obj.class
      when obj.kind_of?(Class) && obj < CRC
        mod = obj
      else
        return false
      end

      if bitsize == mod.bitsize &&
         polynomial == mod.polynomial &&
         reflect_input? == mod.reflect_input? &&
         reflect_output? == mod.reflect_output? &&
         xor_output == mod.xor_output
        true
      else
        false
      end
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
    raise ArgumentError, "not a CRC instance (#{crc2.inspect})" unless crc2.kind_of?(CRC)
    m1 = self.class
    m2 = crc2.class
    unless m1.bitsize == m2.bitsize &&
           m1.polynomial == m2.polynomial &&
           m1.reflect_input? == m2.reflect_input? &&
           m1.reflect_output? == m2.reflect_output? &&
           # m1.initial_crc == m2.initial_crc &&
           m1.xor_output == m2.xor_output
      raise ArgumentError, "different CRC module (#{m1.inspect} and #{m2.inspect})"
    end
    m1.new(m1.combine(crc, crc2.crc, crc2.size), size + crc2.size)
  end

  def ==(a)
    case a
    when CRC
      m1 = self.class
      m2 = a.class
      if m1.bitsize == m2.bitsize &&
         m1.polynomial == m2.polynomial &&
         m1.reflect_input? == m2.reflect_input? &&
         m1.reflect_output? == m2.reflect_output? &&
         # m1.initial_crc == m2.initial_crc &&
         m1.xor_output == m2.xor_output &&
         state == a.state
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
