#!ruby

require_relative "../crc"

class CRC
  ALGORITHM_BITBYBIT        = -2
  ALGORITHM_BITBYBIT_FAST   = -1
  ALGORITHM_HALFBYTE_TABLE  =  0
  ALGORITHM_STANDARD_TABLE  =  1
  ALGORITHM_SLICING_BY_4    =  4
  ALGORITHM_SLICING_BY_8    =  8
  ALGORITHM_SLICING_BY_16   = 16

  def self.dump_to_c(func_name = nil, header_name = nil, source_name = nil, indent: 4, visible: true, algorithm: ALGORITHM_SLICING_BY_16)
    func_name ||= self.to_s.slice(/\w+$/).downcase
    #func_name ||= self.name.gsub(/[\W]+/, "_").gsub(/_{2,}/, "_").gsub(/^_|_$/, "").downcase
    header_name ||= "#{func_name}.h"
    source_name ||= "#{func_name}.c"
    indentunit = " " * Integer(indent.to_i)
    indent = ->(level) { indentunit * level }
    visibility = visible ? "" : "static "

    case
    when bitsize <= 8
      type = "uint8_t"
      sizeof = 1
      suffix = "u"
    when bitsize <= 16
      type = "uint16_t"
      sizeof = 2
      suffix = "u"
    when bitsize <= 32
      type = "uint32_t"
      sizeof = 4
      suffix = "ul"
    else
      type = "uint64_t"
      sizeof = 8
      suffix = "ull"
    end

    typesize = sizeof * 8
    alignedbytes = (bitsize + 7) / 8
    alignedbits = (bitsize + 7) & ~0x07 # 8 bit alignmented bitsize
    bitreflect = func_name + "_bitreflect"
    hexnum = ->(n) { "0x%0#{sizeof * 2}X%s" % [n, suffix] }
    hexbyte = ->(n) { "0x%02Xu" % n }

    if reflect_input?
      getleadbyte = ->(expr, off = 0) { "(uint8_t)(#{expr} >> %2d)" % (off * 8) }
      getheadbit_from_byte = ->(expr, off = 0) { "((#{expr} >> #{off}) & 1)" }
      getleadbit = ->(expr, off = 0, width = 1) { "((%s >> %2d) & 0x%02X)" % [expr, off, ~(~0 << width)] }
      slideinput = ->(expr) { "#{expr}" }
      slidestate1 = ->(expr) { "(#{expr} >> 1)" }
      slidestate4 = ->(expr) { "(#{expr} >> 4)" }
      slidestate8 = ->(expr) { "(#{expr} >> 8)" }
      slideslicing = ->(expr) { "(#{expr} >> #{algorithm * 8})" }
      padding = depadding = nil
      workpoly = hexnum[Utils.bitreflect(polynomial, bitsize)]
      if algorithm >= 0
        table = Utils.build_reflect_table(bitsize, polynomial, true, slice: (algorithm < 1 ? 1 : algorithm))
      end
    else
      getleadbyte = ->(expr, off = 0) { "(uint8_t)(#{expr} >> %2d)" % (alignedbits - (off + 1) * 8) }
      getheadbit_from_byte = ->(expr, off = 0) { "((#{expr} >> #{8 - (off + 1)}) & 1)" }
      getleadbit = ->(expr, off = 0, width = 1) { "((%s >> %2d) & 0x%02X)" % [expr, (alignedbits - (off + 1) - (width - 1)), ~(~0 << width)] }
      slideinput = ->(expr) { "((#{type})#{expr} << #{alignedbits - 8})" }
      slidestate1 = ->(expr) { "(#{expr} << 1)" }
      slidestate4 = ->(expr) { "(#{expr} << 4)" }
      slidestate8 = ->(expr) { "(#{expr} << 8)" }
      slideslicing = ->(expr) { "(#{expr} << #{algorithm * 8})" }
      if (pad = (alignedbits - bitsize)) > 0
        padding = " << #{pad}"
        depadding = " >> #{pad}"
        workpoly = "#{func_name.upcase}_POLYNOMIAL << #{pad}"
      else
        padding = depadding = nil
        workpoly = "#{func_name.upcase}_POLYNOMIAL"
      end
      if algorithm >= 0
        table = Utils.build_table(bitsize, polynomial, true, slice: (algorithm < 1 ? 1 : algorithm))
      end
    end

    case algorithm
    when ALGORITHM_BITBYBIT
      comment = " /* bit reflected */" if reflect_input?
      prepare = <<-PREPARE_BITBYBIT
    static const #{type} workpoly = #{workpoly};#{comment}
      PREPARE_BITBYBIT
      update = <<-UPDATE_BITBYBIT
    for (; p < pp; p ++) {
        int i;
        s ^= #{slideinput["*p"]};
        for (i = 0; i < 8; i ++) {
            s = #{slidestate1["s"]} ^ (workpoly & -(#{type})#{getleadbit["s"]});
        }
    }
      UPDATE_BITBYBIT
    when ALGORITHM_BITBYBIT_FAST
      comment = " /* bit reflected */" if reflect_input?
      tspc = " " * type.size
      prepare = <<-PREPARE_BITBYBIT_FAST
    static const #{type} workpoly = #{workpoly};#{comment}
    static const #{type} g0 = workpoly,
                 #{tspc} g1 = #{slidestate1["g0"]} ^ (workpoly & -(#{type})#{getleadbit["g0"]}),
                 #{tspc} g2 = #{slidestate1["g1"]} ^ (workpoly & -(#{type})#{getleadbit["g1"]}),
                 #{tspc} g3 = #{slidestate1["g2"]} ^ (workpoly & -(#{type})#{getleadbit["g2"]}),
                 #{tspc} g4 = #{slidestate1["g3"]} ^ (workpoly & -(#{type})#{getleadbit["g3"]}),
                 #{tspc} g5 = #{slidestate1["g4"]} ^ (workpoly & -(#{type})#{getleadbit["g4"]}),
                 #{tspc} g6 = #{slidestate1["g5"]} ^ (workpoly & -(#{type})#{getleadbit["g5"]}),
                 #{tspc} g7 = #{slidestate1["g6"]} ^ (workpoly & -(#{type})#{getleadbit["g6"]});
      PREPARE_BITBYBIT_FAST
      update = <<-UPDATE_BITBYBIT_FAST
    for (; p < pp; p ++) {
        const uint8_t s1 = #{getleadbit["s", 0, 8]} ^ *p;
        s = #{slidestate8["s"]} ^
            (g7 & -(#{type})#{getheadbit_from_byte["s1", 0]}) ^
            (g6 & -(#{type})#{getheadbit_from_byte["s1", 1]}) ^
            (g5 & -(#{type})#{getheadbit_from_byte["s1", 2]}) ^
            (g4 & -(#{type})#{getheadbit_from_byte["s1", 3]}) ^
            (g3 & -(#{type})#{getheadbit_from_byte["s1", 4]}) ^
            (g2 & -(#{type})#{getheadbit_from_byte["s1", 5]}) ^
            (g1 & -(#{type})#{getheadbit_from_byte["s1", 6]}) ^
            (g0 & -(#{type})#{getheadbit_from_byte["s1", 7]});
    }
      UPDATE_BITBYBIT_FAST
    when ALGORITHM_HALFBYTE_TABLE
      table = table[0]
      if reflect_input?
        table = 16.times.map { |i| table[i * 16] }
      else
        table = 16.times.map { |i| table[i] }
      end
      prepare = <<-PREPARE_HALFBYTE_TABLE
    static const #{type} table[16] = {
#{Aux.export_slicing_table(table, "    ", 4, nil, nil, nil, nil, sizeof > 2 ? 4 : 8, &hexnum)}
    };
      PREPARE_HALFBYTE_TABLE
      update = <<-UPDATE_HALFBYTE_TABLE
    for (; p < pp; p ++) {
        s ^= #{slideinput["(#{type})*p"]};
        s = table[#{getleadbit["s", 0, 4]}] ^ #{slidestate4["s"]};
        s = table[#{getleadbit["s", 0, 4]}] ^ #{slidestate4["s"]};
    }
      UPDATE_HALFBYTE_TABLE
    when ALGORITHM_STANDARD_TABLE
      prepare = <<-PREPARE_STANDARD_TABLE
    static const #{type} table[256] = {
#{Aux.export_slicing_table(table[0], "    ", 4, nil, nil, nil, nil, sizeof > 2 ? 4 : 8, &hexnum)}
    };
      PREPARE_STANDARD_TABLE
      update = <<-UPDATE_STANDARD_TABLE
    for (; p < pp; p ++) {
        s ^= #{slideinput["(#{type})*p"]};
        s = table[(uint8_t)#{getleadbit["s", 0, 8]}] ^ #{slidestate8["s"]};
    }
      UPDATE_STANDARD_TABLE
    when ALGORITHM_SLICING_BY_4,
         ALGORITHM_SLICING_BY_8,
         ALGORITHM_SLICING_BY_16
      slicing = algorithm.times.map { |off|
        ioff = (algorithm - 1) - off
        "table[%2d][p[%2d] %20s]" % [
          off, ioff,
          ioff >= alignedbytes ? nil : "^ #{getleadbyte["s", ioff]}"]
      }
      if algorithm < alignedbytes
        slicing.insert 0, slideslicing["s"]
      end
      slicing = slicing.join(" ^\n            ")

      prepare = <<-PREPARE_SLICING_TABLE
    static const #{type} table[#{algorithm}][256] = {
#{Aux.export_slicing_table(table, "    ", 4, nil, nil, "{", "}", sizeof > 2 ? 4 : 8, &hexnum)}
    };
      PREPARE_SLICING_TABLE
      update = <<-UPDATE_SLICING_TABLE
    const uint8_t *ppby = p + (len / #{algorithm} * #{algorithm});
    for (; p < ppby; p += #{algorithm}) {
        s = #{slicing};
    }

    for (; p < pp; p ++) {
        s = table[0][*p ^ #{getleadbyte["s"]}] ^ #{slidestate8["s"]};
    }
      UPDATE_SLICING_TABLE
    else
      raise ArgumentError, "wrong algorithm code - #{algorithm}"
    end

    if reflect_output? ^ reflect_input?
      slideleft = (typesize == bitsize) ? nil : "\n" << <<-SLIDELEFT.chomp!
    n <<= #{typesize - bitsize};
      SLIDELEFT
      swapby32 = (sizeof < 8) ? nil : "\n" << <<-SWAPBY32.chomp!
    n = ((n & 0X00000000FFFFFFFF#{suffix}) << 32) |  (n >> 32);
      SWAPBY32
      swapby16 = (sizeof < 4) ? nil : "\n" << <<-SWAPBY16.chomp!
    n = ((n & 0x#{"0000FFFF" * (sizeof / 4)}#{suffix}) << 16) | ((n >> 16) & 0x#{"0000FFFF" * (sizeof / 4)}#{suffix});
      SWAPBY16
      swapby8 = (sizeof < 2) ? nil : "\n" << <<-SWAPBY8.chomp!
    n = ((n & 0x#{"00FF" * (sizeof / 2)}#{suffix}) <<  8) | ((n >>  8) & 0x#{"00FF" * (sizeof / 2)}#{suffix});
      SWAPBY8

      func_bitreflect = "\n" << <<-BITREFLECT
static #{type}
#{bitreflect}(#{type} n)
{#{slideleft}#{swapby32}#{swapby16}#{swapby8}
    n = ((n & 0x#{"0F" * sizeof}#{suffix}) <<  4) | ((n >>  4) & 0x#{"0F" * sizeof}#{suffix});
    n = ((n & 0x#{"33" * sizeof}#{suffix}) <<  2) | ((n >>  2) & 0x#{"33" * sizeof}#{suffix});
    n = ((n & 0x#{"55" * sizeof}#{suffix}) <<  1) | ((n >>  1) & 0x#{"55" * sizeof}#{suffix});
    return n;
}
      BITREFLECT
    else
      bitreflect = nil
    end

    { header: <<-CHEADER, source: <<-CSOURCE }
/*
#{Aux.dump_banner(" *", "#{self.name}{#{to_str}}", algorithm)}
 */

#ifndef #{func_name.upcase}_H__
#define #{func_name.upcase}_H__ 1

#include <stdlib.h>
#include <stdint.h>

#define #{func_name.upcase}_TYPE           #{type}
#define #{func_name.upcase}_BITSIZE        #{bitsize}
#define #{func_name.upcase}_BITMASK        #{hexnum[bitmask]}
#define #{func_name.upcase}_POLYNOMIAL     #{hexnum[polynomial]}
#define #{func_name.upcase}_INITIAL_CRC    #{hexnum[initial_crc]}
#define #{func_name.upcase}_XOR_OUTPUT     #{hexnum[xor_output]}
#define #{func_name.upcase}_REFLECT_INPUT  #{reflect_input? ? 1 : 0}
#define #{func_name.upcase}_REFLECT_OUTPUT #{reflect_output? ? 1 : 0}

#ifdef __cplusplus
extern "C"
#{visibility}#{type} #{func_name}(const void *ptr, size_t len, #{type} crc = #{func_name.upcase}_INITIAL_CRC);
#else
#{visibility}#{type} #{func_name}(const void *ptr, size_t len, #{type} crc);
#endif

#endif /* #{func_name.upcase}_H__ */
    CHEADER
/*
#{Aux.dump_banner(" *", "#{self.name}{#{to_str}}", algorithm)}
 */

#include "#{header_name}"
#{func_bitreflect}
#{visibility}#{type}
#{func_name}(const void *ptr, size_t len, #{type} crc)
{
#{prepare}
    #{type} s = ((#{bitreflect}(crc) & #{func_name.upcase}_BITMASK) ^ #{func_name.upcase}_XOR_OUTPUT)#{padding};
    const uint8_t *p = (const uint8_t *)ptr;
    const uint8_t *pp = p + len;

#{update}
    return #{bitreflect}((s#{depadding}) & #{func_name.upcase}_BITMASK) ^ #{func_name.upcase}_XOR_OUTPUT;
}
    CSOURCE
  end

  def self.dump_to_ruby(class_name = nil)
    class_name ||= self.to_s.slice(/\w+$/)
    name = class_name.split("::")
    name.map! { |nm| nm.gsub!(/[\W]+/m, "_"); nm.sub!(/^_+/, ""); nm.sub!(/^[a-z]/) { |m| m.upcase! }; nm }
    case
    when bitsize <= 8
      sizeof = 1
      pack = "C"
    when bitsize <= 16
      sizeof = 2
      pack = "n"
    when bitsize <= 32
      sizeof = 4
      pack = "N"
    else
      sizeof = 8
      pack = "Q>"
    end

    typebits = sizeof * 8
    hexnum = ->(n) { "0x%0*X" % [sizeof * 2, n] }
    if reflect_input?
      table1 = Utils.build_reflect_table(bitsize, polynomial, slice: 16)
      headstate = "(s & 0xFF)"
      slidestate = "(s >> 8)"
      slicing = ->(off) {
        t = "t%X" % (15 - off)
        getbyte = off > 0 ? "+ %2d" % off : ""
        shiftstate = off < sizeof ? "^ (s %5s) & 0xFF" % (off > 0 ? ">> %2d" % (off * 8) : "") : ""
        "%s[seq.getbyte(i %4s) %18s]" % [t, getbyte, shiftstate]
      }
    else
      table1 = Utils.build_table(bitsize, polynomial, true, slice: 16)
      bitpad = typebits - bitsize
      headstate = "((s >> #{typebits - 8}) & 0xFF)"
      slidestate = "((s & #{hexnum[~(~0 << typebits) >> 8]}) << 8)"
      slicing = ->(off) {
        t = "t%X" % (15 - off)
        getbyte = off > 0 ? "+ %2d" % off : ""
        shiftstate = off < sizeof ? "^ (s %5s) & 0xFF" % (off + 1 < sizeof ? ">> %2d" % ((sizeof - off) * 8 - 8) : "") : ""
        "%s[seq.getbyte(i %4s) %18s]" % [t, getbyte, shiftstate]
      }
    end

    code = <<-EOS
#!ruby

#
#{Aux.dump_banner("#", "#{self.name}{#{to_str}}", ALGORITHM_SLICING_BY_16)}
#

# for ruby-1.8
unless "".respond_to?(:getbyte)
  class String
    alias getbyte []
  end
end

# for mruby
unless [].respond_to?(:freeze)
  class Array
    def freeze
      self
    end
  end
end

class #{name.join("::")}
  BITSIZE         = #{bitsize}
  BITMASK         = #{hexnum[bitmask]}
  POLYNOMIAL      = #{hexnum[polynomial]}
  INITIAL_CRC     = #{hexnum[initial_crc]}
  REFLECT_INPUT   = #{reflect_input?.inspect}
  REFLECT_OUTPUT  = #{reflect_output?.inspect}
  XOR_OUTPUT      = #{hexnum[xor_output]}

  attr_accessor :state

  #
  # call-seq:
  #   initialize(prevcrc = nil)
  #   initialize(seq, prevcrc = nil)
  #
  def initialize(*args)
    case args.size
    when 0
      seq = nil
      prevcrc = nil
    when 1
      if args[0].kind_of?(String)
        seq = args[0]
      else
        prevcrc = args[0]
      end
    when 2
      (seq, prevcrc) = args
    else
      raise ArgumentError, "wrong number of argument (given \#{args.size}, expect 0..2)"
    end

    reset(prevcrc)
    update(seq) if seq
  end

  def reset(prevcrc = nil)
    @state = self.class.setup(prevcrc || INITIAL_CRC)
    self
  end

  def update(seq)
    @state = self.class.update(seq, state)
    self
  end

  alias << update

  def crc
    self.class.finish(state)
  end

  alias finish crc

  def digest
    [crc].pack(#{pack.inspect})
  end

  def hexdigest
    "%0#{sizeof * 2}X" % crc
  end

  def inspect
    "#<\#{self.class}:\#{hexdigest}>"
  end

  def pretty_print(q)
    q.text inspect
  end

  class << self
    def [](seq, prevcrc = nil)
      new(seq, prevcrc)
    end

    def setup(crc = INITIAL_CRC)
      #{
        s = "(BITMASK & crc ^ XOR_OUTPUT)"

        if reflect_output? ^ reflect_input?
          s = "bitreflect#{s}"
        end

        if !reflect_input? && typebits > bitsize
          s << " << #{typebits - bitsize}"
        end

        s
      }
    end

    alias init setup

    def finish(state)
      #{
        if !reflect_input? && typebits > bitsize
          state = "(state >> #{typebits - bitsize})"
        else
          state = "state"
        end

        if reflect_output? ^ reflect_input?
          "bitreflect(BITMASK & #{state} ^ XOR_OUTPUT)"
        else
          "BITMASK & #{state} ^ XOR_OUTPUT"
        end
      }
    end

    #
    # call-seq:
    #   update(seq, state) -> state
    #
    def update(seq, s)
      i = 0
      ii = seq.bytesize
      ii16 = ii & ~15
      t0 = TABLE[ 0]; t1 = TABLE[ 1]; t2 = TABLE[ 2]; t3 = TABLE[ 3]
      t4 = TABLE[ 4]; t5 = TABLE[ 5]; t6 = TABLE[ 6]; t7 = TABLE[ 7]
      t8 = TABLE[ 8]; t9 = TABLE[ 9]; tA = TABLE[10]; tB = TABLE[11]
      tC = TABLE[12]; tD = TABLE[13]; tE = TABLE[14]; tF = TABLE[15]
      while i < ii16
        s = #{slicing[ 0]} ^
            #{slicing[ 1]} ^
            #{slicing[ 2]} ^
            #{slicing[ 3]} ^
            #{slicing[ 4]} ^
            #{slicing[ 5]} ^
            #{slicing[ 6]} ^
            #{slicing[ 7]} ^
            #{slicing[ 8]} ^
            #{slicing[ 9]} ^
            #{slicing[10]} ^
            #{slicing[11]} ^
            #{slicing[12]} ^
            #{slicing[13]} ^
            #{slicing[14]} ^
            #{slicing[15]}
        i += 16
      end

      while i < ii
        s = t0[seq.getbyte(i) ^ #{headstate}] ^ #{slidestate}
        i += 1
      end

      s
    end

    def crc(seq, initcrc = INITIAL_CRC)
      finish(update(seq, setup(initcrc)))
    end

    def digest(seq, initcrc = INITIAL_CRC)
      [crc(seq, initcrc)].pack(#{pack.inspect})
    end

    def hexdigest(seq, initcrc = INITIAL_CRC)
      "%0#{sizeof * 2}X" % crc(seq, initcrc)
    end
      EOS

      if reflect_output? ^ reflect_input?
      code << <<-EOS

    def bitreflect(n)
      EOS

      if typebits > bitsize
        code << <<-EOS
      n <<= #{typebits - bitsize}
        EOS
      end

      if typebits > 32
        code << <<-EOS
      n = ((n >> 32) & 0x00000000ffffffff) | ((n & 0x00000000ffffffff) << 32)
        EOS
      end

      if typebits > 16
        code << <<-EOS
      n = ((n >> 16) & 0x#{"0000ffff" * (sizeof / 4)}) | ((n & 0x#{"0000ffff" * (sizeof / 4)}) << 16)
        EOS
      end

      if typebits > 8
        code << <<-EOS
      n = ((n >>  8) & 0x#{"00ff" * (sizeof / 2)}) | ((n & 0x#{"00ff" * (sizeof / 2)}) <<  8)
        EOS
      end

      code << <<-EOS
      n = ((n >>  4) & 0x#{"0f" * sizeof}) | ((n & 0x#{"0f" * sizeof}) <<  4)
      n = ((n >>  2) & 0x#{"33" * sizeof}) | ((n & 0x#{"33" * sizeof}) <<  2)
      n = ((n >>  1) & 0x#{"55" * sizeof}) | ((n & 0x#{"55" * sizeof}) <<  1)
    end
      EOS
    end

    code << <<-EOS
  end

  TABLE = [
#{Aux.export_slicing_table(table1, "  ", 2, nil, nil, "[", "].freeze", sizeof > 2 ? 4 : 8, &hexnum)}
  ].freeze
end
    EOS

    ({ source: code })
  end

  def self.dump_to_javascript(class_name = nil)
    class_name ||= self.to_s.slice(/\w+$/).downcase
    name = class_name.split("::")
    name.map! { |nm| nm.gsub!(/[\W]+/m, "_"); nm.sub!(/^_+/, ""); nm }
    case
    when bitsize <= 8
      sizeof = 1
    when bitsize <= 16
      sizeof = 2
    when bitsize <= 32
      sizeof = 4
    else
      sizeof = 8
    end

    pack = ""

    typebits = sizeof * 8
    hexnum = ->(n) { "0x%0*X" % [sizeof * 2, n] }
    if reflect_input?
      table1 = Utils.build_reflect_table(bitsize, polynomial, slice: 16)
      headstate = "(s & 0xFF)"
      slidestate = "(s >>> 8)"
      slicing = ->(off) {
        t = "t%X" % (15 - off)
        getbyte = off > 0 ? "+ %2d" % off : ""
        shiftstate = off < sizeof ? "^ (s %6s) & 0xFF" % (off > 0 ? ">>> %2d" % (off * 8) : "") : ""
        "%s[(0xFF & seq.charCodeAt(i %4s)) %19s]" % [t, getbyte, shiftstate]
      }
    else
      table1 = Utils.build_table(bitsize, polynomial, true, slice: 16)
      bitpad = typebits - bitsize
      #table1.each { |t| t.map! { |tt| tt << bitpad } }
      headstate = "((s >>> #{typebits - 8}) & 0xFF)"
      slidestate = "((s & #{hexnum[~(~0 << typebits) >> 8]}) << 8)"
      slicing = ->(off) {
        t = "t%X" % (15 - off)
        getbyte = off > 0 ? "+ %2d" % off : ""
        shiftstate = off < sizeof ? "^ (s %6s) & 0xFF" % (off + 1 < sizeof ? ">>> %2d" % ((sizeof - off) * 8 - 8) : "") : ""
        "%s[(0xFF & seq.charCodeAt(i %4s)) %19s]" % [t, getbyte, shiftstate]
      }
    end

    typename = name.join(".")

    code = <<-EOS
/*
#{Aux.dump_banner(" *", "#{self.name}{#{to_str}}", ALGORITHM_SLICING_BY_16)}
 * * Required ECMASCript version: 6th edition
 *
 * *** IMPORTANT BUG! ***
 *
 * This can not be calculated correctly,
 * if string included with 0x100+ codepointed character.
 */

"use strict";

/*
 * #{typename}(prevcrc = null)
 * #{typename}(seq, prevcrc = null)
 * new #{typename}(prevcrc = null)
 * new #{typename}(seq, prevcrc = null)
 */
(function(root, undefined) {
  if (typeof(module) != "undefined") {
    // case node-js
    root = global;
  }

  var BITSIZE         = #{bitsize};
  var BITMASK         = #{hexnum[bitmask]} >>> 0;
  var POLYNOMIAL      = #{hexnum[polynomial]} >>> 0;
  var INITIAL_CRC     = #{hexnum[initial_crc]} >>> 0;
  var REFLECT_INPUT   = #{reflect_input?.inspect};
  var REFLECT_OUTPUT  = #{reflect_output?.inspect};
  var XOR_OUTPUT      = #{hexnum[xor_output]} >>> 0;

  var #{typename} = function() {
    if(!(this instanceof #{typename})) {
        return new #{typename}(...arguments).crc;
    }

    var seq, prevcrc;

    switch (arguments.length) {
    case 0:
      seq = null;
      prevcrc = null;
      break;
    case 1:
      if (typeof(arguments[0]) == "string") {
        seq = arguments[0];
      } else {
        prevcrc = arguments[0];
      }
      break;
    case 2:
      seq = arguments[0];
      prevcrc = arguments[1];
      break;
    default:
      throw `wrong number of argument (given ${arguments.size}, expect 0..2)`;
    }

    this.reset(prevcrc);
    if (seq) { this.update(seq); }
  };

  var proto = #{typename}.prototype;

  proto.reset = function(prevcrc = null) {
    this.state = #{typename}.setup(prevcrc || INITIAL_CRC);
    return this;
  };

  proto.update = function(seq) {
    this.state = #{typename}.update(seq, this.state);
    return this;
  };

  // proto.operator << = proto.update;

  proto.finish = function() {
    return #{typename}.finish(this.state);
  };

  Object.defineProperty(proto, "crc", {
    get: proto.finish
  });

  Object.defineProperty(proto, "hexdigest", {
    get: function() {
      var s = this.crc.toString(16);
      for (var i = s.length; i < #{sizeof * 2}; i ++) {
        s = "0" + s;
      }
      return s;
    }
  });

  proto.toString = function() {
    return `#<#{typename}:${this.hexdigest}>`;
  };

  #{typename}.setup = function(crc = INITIAL_CRC) {
    return #{
      s = "(BITMASK & crc ^ XOR_OUTPUT)"

      if reflect_output? ^ reflect_input?
        s = "bitreflect#{s}"
      end

      if !reflect_input? && typebits > bitsize
        s << " << #{typebits - bitsize}"
      end

      s
    };
  };

  #{typename}.init = #{typename}.setup;

  #{typename}.finish = function(state) {
    return (#{
      if !reflect_input? && typebits > bitsize
        state = "(state >>> #{typebits - bitsize})"
      else
        state = "state"
      end

      if reflect_output? ^ reflect_input?
        "bitreflect(BITMASK & #{state} ^ XOR_OUTPUT)"
      else
        "BITMASK & #{state} ^ XOR_OUTPUT"
      end
    }) >>> 0;
  };

  /*
   * update(seq, state) -> state
   */
  #{typename}.update = function(seq, s) {
    var i = 0;
    var ii = seq.length;
    var ii16 = ii & ~15;
    var t0 = TABLE[ 0], t1 = TABLE[ 1], t2 = TABLE[ 2], t3 = TABLE[ 3],
        t4 = TABLE[ 4], t5 = TABLE[ 5], t6 = TABLE[ 6], t7 = TABLE[ 7],
        t8 = TABLE[ 8], t9 = TABLE[ 9], tA = TABLE[10], tB = TABLE[11],
        tC = TABLE[12], tD = TABLE[13], tE = TABLE[14], tF = TABLE[15];
    for (; i < ii16; i += 16) {
      s = #{slicing[ 0]} ^
          #{slicing[ 1]} ^
          #{slicing[ 2]} ^
          #{slicing[ 3]} ^
          #{slicing[ 4]} ^
          #{slicing[ 5]} ^
          #{slicing[ 6]} ^
          #{slicing[ 7]} ^
          #{slicing[ 8]} ^
          #{slicing[ 9]} ^
          #{slicing[10]} ^
          #{slicing[11]} ^
          #{slicing[12]} ^
          #{slicing[13]} ^
          #{slicing[14]} ^
          #{slicing[15]};
    }

    for (; i < ii; i ++) {
      s = t0[(0xFF & seq.charCodeAt(i)) ^ #{headstate}] ^ #{slidestate}
    }

    return s;
  }

  #{typename}.crc = function(seq, initcrc = INITIAL_CRC) {
    return #{typename}.finish(#{typename}.update(seq, #{typename}.setup(initcrc)));
  };

  #{typename}.hexdigest = function(seq, initcrc = INITIAL_CRC) {
    var s = #{typename}.crc(seq, initcrc).toString(16);
    for (var i = s.length; i < #{sizeof * 2}; i ++) {
      s = "0" + s;
    }
    return s;
  };
    EOS

    if reflect_output? ^ reflect_input?
      code << <<-EOS

  #{typename}.bitreflect = function(n) {
      EOS

      if typebits > bitsize
        code << <<-EOS
    n <<= #{typebits - bitsize}
        EOS
      end

      if typebits > 32
        code << <<-EOS
    n = ((n >>> 32) & 0x00000000ffffffff) | ((n & 0x00000000ffffffff) << 32)
        EOS
      end

      if typebits > 16
        code << <<-EOS
    n = ((n >>> 16) & 0x#{"0000ffff" * (sizeof / 4)}) | ((n & 0x#{"0000ffff" * (sizeof / 4)}) << 16)
        EOS
      end

      if typebits > 8
        code << <<-EOS
    n = ((n >>>  8) & 0x#{"00ff" * (sizeof / 2)}) | ((n & 0x#{"00ff" * (sizeof / 2)}) <<  8)
        EOS
      end

      code << <<-EOS
    n = ((n >>>  4) & 0x#{"0f" * sizeof}) | ((n & 0x#{"0f" * sizeof}) <<  4)
    n = ((n >>>  2) & 0x#{"33" * sizeof}) | ((n & 0x#{"33" * sizeof}) <<  2)
    n = ((n >>>  1) & 0x#{"55" * sizeof}) | ((n & 0x#{"55" * sizeof}) <<  1)
    return n;
  }
      EOS
    end

    code << <<-EOS

  var TABLE = [
#{Aux.export_slicing_table(table1, "  ", 2, nil, nil, "[", "]", sizeof > 2 ? 4 : 8, &hexnum)}
  ];

  root.#{typename} = #{typename};

  Object.defineProperty(#{typename}, "BITSIZE", { get: function() { return BITSIZE } });
  Object.defineProperty(#{typename}, "BITMASK", { get: function() { return BITMASK } });
  Object.defineProperty(#{typename}, "POLYNOMIAL", { get: function() { return POLYNOMIAL } });
  Object.defineProperty(#{typename}, "INITIAL_CRC", { get: function() { return INITIAL_CRC } });
  Object.defineProperty(#{typename}, "REFLECT_INPUT", { get: function() { return REFLECT_INPUT } });
  Object.defineProperty(#{typename}, "REFLECT_OUTPUT", { get: function() { return REFLECT_OUTPUT } });
  Object.defineProperty(#{typename}, "XOR_OUTPUT", { get: function() { return XOR_OUTPUT } });

  return #{typename};
})(this);
    EOS

    ({ source: code })
  end

  module Aux
    def self.dump_banner(line_prefix, crcname, algorithm)
      case algorithm
      when ALGORITHM_BITBYBIT
        algorithm = "bit-by-bit"
      when ALGORITHM_BITBYBIT_FAST
        algorithm = "bit-by-bit-fast"
      when ALGORITHM_HALFBYTE_TABLE
        algorithm = "halfbyte-table"
      when ALGORITHM_STANDARD_TABLE
        algorithm = "standard-table"
      when ALGORITHM_SLICING_BY_4, ALGORITHM_SLICING_BY_8, ALGORITHM_SLICING_BY_16
        algorithm = "slicing-by-#{algorithm} (with byte-order free), based Intel's slicing-by-8"
      else
        raise ArgumentError, "out of algorithm code (given #{algorithm})"
      end
      (<<-EOS).gsub!(/^(?!$)/, " ").gsub!(/^/) { line_prefix }.chomp!
A CRC calculator for #{crcname}.

This code is auto generated by <https://rubygems.org/gems/crc>.

* License:: Creative Commons License Zero (CC0 / Public Domain)
            See <https://creativecommons.org/publicdomain/zero/1.0/>
* Version:: crc-#{CRC::VERSION} (powered by #{RUBY_DESCRIPTION})
* Generated at:: #{Time.now.strftime "%Y-%m-%d"}
* Algorithm:: #{algorithm}
* Need available memory:: about 1 MiB
      EOS
    end

    def self.export_slicing_table(table, baseindent, indentsize, tableprefix, tablesuffix, elementprefix, elementsuffix, lineinelements, &hexnum)
      indent = ->(n = 0) { baseindent + (" " * (indentsize * n)) }
      tableprefix &&= "#{indent[0]}#{tableprefix}\n"
      tablesuffix &&= "\n#{indent[0]}#{tablesuffix}"
      if table[0].kind_of?(Array)
        (<<-TABLE2).chomp!
#{tableprefix}#{indent[1]}#{elementprefix}
#{
    table = table.map { |tt|
      tt = tt.map(&hexnum)
      %(#{indent[2]}#{tt.each_slice(lineinelements).map { |ttt| ttt.join(", ") }.join(",\n#{indent[2]}")}\n)
    }.join("#{indent[1]}#{elementsuffix},\n#{indent[1]}#{elementprefix}\n").chomp!
}
#{indent[1]}#{elementsuffix}#{tablesuffix}
        TABLE2
      else
        table = table.map(&hexnum)
        %(#{indent[1]}#{table.each_slice(lineinelements).map { |ttt| ttt.join(", ") }.join(",\n#{indent[1]}")}\n).chomp!
      end
    end
  end
end
