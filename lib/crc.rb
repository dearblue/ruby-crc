#!ruby

if ENV["RUBY_CRC_NOFAST"].to_i > 0
  require_relative "crc/_byruby"
  CRC::IMPLEMENT = :ruby
else
  begin
    gem "crc-turbo", "~> 0.4.A"
    require File.join("crc", RUBY_VERSION[/\d+\.\d+/], "_turbo.so")
    CRC::IMPLEMENT = :turbo
  rescue LoadError, Gem::MissingSpecVersionError
    require_relative "crc/_byruby"
    CRC::IMPLEMENT = :ruby
  end
end

require_relative "crc/version"

#
# This is a generic CRC calculator.
#
# When you want to use CRC-32 model, there are following ways:
#
# 1. Calculate CRC-32'd value at direct:
#
#     CRC.crc32("123456789") # => 3421780262
#
# 2. Calculate CRC-32'd hex-digest at direct:
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

  module Calculator
    def [](seq, *args)
      c = new(*args)
      c.update(seq) if seq
      c
    end

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
  #
  def initialize(initial_crc = nil, size = 0)
    m = get_crc_model
    @state = m.setup((initial_crc || m.initial_crc).to_i)
    @size = size.to_i
  end

  def reset(initial_crc = nil, size = 0)
    m = get_crc_model
    @state = m.setup((initial_crc || m.initial_crc).to_i)
    @size = size.to_i
    self
  end

  def update(seq)
    @state = get_crc_model.update(seq, state)
    @size += seq.bytesize
    self
  end

  alias << update

  def crc
    get_crc_model.finish(state)
  end

  def +(crc2)
    m1 = get_crc_model
    m2 = crc2.get_crc_model
    raise ArgumentError, "not a CRC instance (#{crc2.inspect})" unless m2
    unless m2.variant_for?(m1)
      raise ArgumentError, "different CRC model (#{m1.inspect} and #{m2.inspect})"
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
    Aux.digest(crc, get_crc_model.bitsize)
  end

  # return digest as internal state
  def digest!
    Aux.digest(state, get_crc_model.bitsize)
  end

  def hexdigest
    Aux.hexdigest(crc, get_crc_model.bitsize)
  end

  # return hex-digest as internal state
  def hexdigest!
    Aux.hexdigest(state, get_crc_model.bitsize)
  end

  alias to_str hexdigest
  alias to_s hexdigest

  def inspect
    "\#<#{get_crc_model}:#{hexdigest}>"
  end

  def pretty_inspect(q)
    q.text inspect
  end

  MODEL_TABLE = {}

  class << self
    def lookup(modelname)
      modelname1 = modelname.to_s.gsub(/[\W_]+/, "")
      modelname1.downcase!
      MODEL_TABLE[modelname1] or raise NameError, "modelname is not matched (for #{modelname})"
    end

    alias [] lookup

    def crc(modelname, seq, crc = nil)
      lookup(modelname).crc(seq, crc)
    end

    def digest(modelname, seq, crc = nil)
      lookup(modelname).digest(seq, crc)
    end

    def hexdigest(modelname, seq, crc = nil)
      lookup(modelname).hexdigest(seq, crc)
    end
  end

  # NOTE: "Calcurator" は typo ですが、後方互換のため一時的に残します。
  # TODO: CRC::Calcurator はいずれ削除されます。
  CRC::Calcurator = CRC::Calculator

  require_relative "crc/_models"
  require_relative "crc/_combine"
  require_relative "crc/_shift"
  require_relative "crc/_magic"
  require_relative "crc/_file"

  #
  # Create CRC model classes.
  #
  LIST.each do |bitsize, polynomial, refin, refout, initial_crc, xor, check, *names|
    names.flatten!
    names.map! { |nm| nm.freeze }

    crc = CRC.new(bitsize, polynomial, initial_crc, refin, refout, xor, names[0])
    crc.const_set :NAME, names

    names.each do |nm|
      nm1 = nm.downcase.gsub(/[\W_]+/, "")
      if MODEL_TABLE.key?(nm1)
        raise NameError, "collision crc-model name: #{nm} ({#{crc.to_str}} and {#{MODEL_TABLE[nm1].to_str}})"
      end
      MODEL_TABLE[nm1] = crc

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
end
