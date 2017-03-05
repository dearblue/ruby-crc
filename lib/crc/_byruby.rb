#!ruby

#--
# File:: _byruby.rb
# Author:: dearblue <dearblue@users.osdn.me>
# License:: Creative Commons License Zero (CC0 / Public Domain)
#++

#
# \* \* \* \* \* \* \* \*
#
# Pure ruby implemented general CRC generator.
# It's used slice-by-16 algorithm with byte-order free.
# This is based on the Intel's slice-by-eight algorithm.
#
# It's faster than about 50% (CRC-32) and about 30% (CRC-64) of
# lookup-table algorithm. But need more memory.
#
# reference:
# * https://sourceforge.net/projects/slicing-by-8/
# * xz-utils
#   * http://tukaani.org/xz/
#   * xz-5.2.2/src/liblzma/check/crc32_fast.c
#   * xz-5.2.2/src/liblzma/check/crc32_tablegen.c
#
class CRC
  class << self
    #
    # call-seq:
    #   new(bitsize, polynomial, initial_crc = 0, reflect_input = true, reflect_output = true, xor_output = ~0, name = nil) -> new crc module class (CRC based class)
    #   new(initial_crc = nil, size = 0) -> new crc generator (CRC instance)
    #   new(seq, initial_crc = nil, size = 0) -> new crc generator (CRC instance)
    #
    def new(bitsize, polynomial, initial_crc = 0, reflect_input = true, reflect_output = true, xor_output = ~0, name = nil)
      bitsize = bitsize.to_i
      if bitsize < 1 || bitsize > 64
        raise ArgumentError, "wrong bitsize (except 1..64, but given #{bitsize})"
      end

      bitmask = ~(~0 << bitsize)
      polynomial = bitmask & polynomial
      initial_crc = bitmask & initial_crc
      xor_output = bitmask & xor_output
      name = (name.nil? || ((name = String(name)).empty?)) ? nil : name

      ::Class.new(self) do
        @bitsize = bitsize
        @bitmask = bitmask
        @polynomial = polynomial
        @initial_crc = initial_crc
        @table = nil
        @reflect_input = !!reflect_input
        @reflect_output = !!reflect_output
        @xor_output = xor_output
        @name = name

        # CRC クラスを普通に派生させた場合でも、CRC.new の基底メソッドが呼ばれるための細工
        define_singleton_method(:new, &Class.instance_method(:new).bind(self))

        extend CRC::Calcurator
      end
    end

    def update_with_reference(seq, state)
      if reflect_input
        poly = CRC.bitreflect(polynomial, bitsize)
        seq.each_byte do |ch|
          state ^= ch
          8.times { state = (state[0] == 0) ? (state >> 1) : ((state >> 1) ^ poly) }

          # 8.times { state = (state >> 1) ^ (poly & -state[0]) }
          # NOTE: ruby だと、分岐したほうが2割くらい高速
        end

        state
      else
        Aux.slide_to_head(bitsize, state, polynomial, bitmask) do |s, poly, csh, head, carries|
          seq.each_byte do |ch|
            s ^= ch << csh
            8.times { s = (s[head] == 0) ? (s << 1) : (((carries & s) << 1) ^ poly) }
          end

          s
        end
      end
    end

    def update_with_lookup_table(seq, state)
      t = table[0]

      if reflect_input
        String(seq).each_byte do |ch|
          state = t[state & 0xff ^ ch] ^ (state >> 8)
        end
        state
      else
        Aux.slide_to_head(bitsize, state, polynomial, bitmask) do |s, poly, csh, head, carries|
          carries8 = carries >> 7
          String(seq).each_byte do |ch|
            s = t[(s >> csh) ^ ch] ^ ((carries8 & s) << 8)
          end
          s
        end
      end
    end

    def update_with_slice_by_16(seq, s)
      tX = table
      t0 = tX[ 0]; t1 = tX[ 1]; t2 = tX[ 2]; t3 = tX[ 3]
      t4 = tX[ 4]; t5 = tX[ 5]; t6 = tX[ 6]; t7 = tX[ 7]
      t8 = tX[ 8]; t9 = tX[ 9]; tA = tX[10]; tB = tX[11]
      tC = tX[12]; tD = tX[13]; tE = tX[14]; tF = tX[15]

      i = 0
      ii = seq.bytesize
      ii16 = ii & ~15

      if reflect_input
        case
        when bitsize > 32
          i = 0
          while i < ii16
            s = tF[seq.getbyte(i     ) ^ (s      ) & 0xff] ^ tE[seq.getbyte(i +  1) ^ (s >>  8) & 0xff] ^
                tD[seq.getbyte(i +  2) ^ (s >> 16) & 0xff] ^ tC[seq.getbyte(i +  3) ^ (s >> 24) & 0xff] ^
                tB[seq.getbyte(i +  4) ^ (s >> 32) & 0xff] ^ tA[seq.getbyte(i +  5) ^ (s >> 40) & 0xff] ^
                t9[seq.getbyte(i +  6) ^ (s >> 48) & 0xff] ^ t8[seq.getbyte(i +  7) ^ (s >> 56)       ] ^
                t7[seq.getbyte(i +  8)                   ] ^ t6[seq.getbyte(i +  9)                   ] ^
                t5[seq.getbyte(i + 10)                   ] ^ t4[seq.getbyte(i + 11)                   ] ^
                t3[seq.getbyte(i + 12)                   ] ^ t2[seq.getbyte(i + 13)                   ] ^
                t1[seq.getbyte(i + 14)                   ] ^ t0[seq.getbyte(i + 15)                   ]
            i += 16
          end
        when bitsize > 16
          # speed improvement for 32-bits CRC
          i = 0
          while i < ii16
            s = tF[seq.getbyte(i     ) ^ (s      ) & 0xff] ^ tE[seq.getbyte(i +  1) ^ (s >>  8) & 0xff] ^
                tD[seq.getbyte(i +  2) ^ (s >> 16) & 0xff] ^ tC[seq.getbyte(i +  3) ^ (s >> 24)       ] ^
                tB[seq.getbyte(i +  4)                   ] ^ tA[seq.getbyte(i +  5)                   ] ^
                t9[seq.getbyte(i +  6)                   ] ^ t8[seq.getbyte(i +  7)                   ] ^
                t7[seq.getbyte(i +  8)                   ] ^ t6[seq.getbyte(i +  9)                   ] ^
                t5[seq.getbyte(i + 10)                   ] ^ t4[seq.getbyte(i + 11)                   ] ^
                t3[seq.getbyte(i + 12)                   ] ^ t2[seq.getbyte(i + 13)                   ] ^
                t1[seq.getbyte(i + 14)                   ] ^ t0[seq.getbyte(i + 15)                   ]
            i += 16
          end
        else # when bitsize <= 16
          # speed improvement for 16-bits CRC
          i = 0
          while i < ii16
            s = tF[seq.getbyte(i     ) ^ (s      ) & 0xff] ^ tE[seq.getbyte(i +  1) ^ (s >>  8)       ] ^
                tD[seq.getbyte(i +  2)                   ] ^ tC[seq.getbyte(i +  3)                   ] ^
                tB[seq.getbyte(i +  4)                   ] ^ tA[seq.getbyte(i +  5)                   ] ^
                t9[seq.getbyte(i +  6)                   ] ^ t8[seq.getbyte(i +  7)                   ] ^
                t7[seq.getbyte(i +  8)                   ] ^ t6[seq.getbyte(i +  9)                   ] ^
                t5[seq.getbyte(i + 10)                   ] ^ t4[seq.getbyte(i + 11)                   ] ^
                t3[seq.getbyte(i + 12)                   ] ^ t2[seq.getbyte(i + 13)                   ] ^
                t1[seq.getbyte(i + 14)                   ] ^ t0[seq.getbyte(i + 15)                   ]
            i += 16
          end
        end

        (i...ii).each do |n|
          s = t0[seq.getbyte(n) ^ s & 0xff] ^ (s >> 8)
        end

        s
      else
        Aux.slide_to_head(bitsize, s, polynomial, bitmask) do |s, poly, csh, head, carries|
          case
          when bitsize > 32
            sh = 64 - (head + 1)

            while i < ii16
              s <<= sh
              s = tF[seq.getbyte(i     ) ^ (s >> 56)       ] ^ tE[seq.getbyte(i +  1) ^ (s >> 48) & 0xff] ^
                  tD[seq.getbyte(i +  2) ^ (s >> 40) & 0xff] ^ tC[seq.getbyte(i +  3) ^ (s >> 32) & 0xff] ^
                  tB[seq.getbyte(i +  4) ^ (s >> 24) & 0xff] ^ tA[seq.getbyte(i +  5) ^ (s >> 16) & 0xff] ^
                  t9[seq.getbyte(i +  6) ^ (s >>  8) & 0xff] ^ t8[seq.getbyte(i +  7) ^ (s      ) & 0xff] ^
                  t7[seq.getbyte(i +  8)                   ] ^ t6[seq.getbyte(i +  9)                   ] ^
                  t5[seq.getbyte(i + 10)                   ] ^ t4[seq.getbyte(i + 11)                   ] ^
                  t3[seq.getbyte(i + 12)                   ] ^ t2[seq.getbyte(i + 13)                   ] ^
                  t1[seq.getbyte(i + 14)                   ] ^ t0[seq.getbyte(i + 15)                   ]
              i += 16
            end
          when bitsize > 16
            # speed improvement for 32-bits CRC
            sh = 32 - (head + 1)

            while i < ii16
              s <<= sh
              s = tF[seq.getbyte(i     ) ^ (s >> 24)       ] ^ tE[seq.getbyte(i +  1) ^ (s >> 16) & 0xff] ^
                  tD[seq.getbyte(i +  2) ^ (s >>  8) & 0xff] ^ tC[seq.getbyte(i +  3) ^ (s      ) & 0xff] ^
                  tB[seq.getbyte(i +  4)                   ] ^ tA[seq.getbyte(i +  5)                   ] ^
                  t9[seq.getbyte(i +  6)                   ] ^ t8[seq.getbyte(i +  7)                   ] ^
                  t7[seq.getbyte(i +  8)                   ] ^ t6[seq.getbyte(i +  9)                   ] ^
                  t5[seq.getbyte(i + 10)                   ] ^ t4[seq.getbyte(i + 11)                   ] ^
                  t3[seq.getbyte(i + 12)                   ] ^ t2[seq.getbyte(i + 13)                   ] ^
                  t1[seq.getbyte(i + 14)                   ] ^ t0[seq.getbyte(i + 15)                   ]
              i += 16
            end
          else # when bitsize <= 16
            # speed improvement for 16-bits CRC
            sh = 16 - (head + 1)

            while i < ii16
              s <<= sh
              s = tF[seq.getbyte(i     ) ^ (s >>  8)       ] ^ tE[seq.getbyte(i +  1) ^ (s      ) & 0xff] ^
                  tD[seq.getbyte(i +  2)                   ] ^ tC[seq.getbyte(i +  3)                   ] ^
                  tB[seq.getbyte(i +  4)                   ] ^ tA[seq.getbyte(i +  5)                   ] ^
                  t9[seq.getbyte(i +  6)                   ] ^ t8[seq.getbyte(i +  7)                   ] ^
                  t7[seq.getbyte(i +  8)                   ] ^ t6[seq.getbyte(i +  9)                   ] ^
                  t5[seq.getbyte(i + 10)                   ] ^ t4[seq.getbyte(i + 11)                   ] ^
                  t3[seq.getbyte(i + 12)                   ] ^ t2[seq.getbyte(i + 13)                   ] ^
                  t1[seq.getbyte(i + 14)                   ] ^ t0[seq.getbyte(i + 15)                   ]
              i += 16
            end
          end

          carries8 = carries >> 7
          (i...ii).each do |n|
            s = t0[(s >> csh) ^ seq.getbyte(n)] ^ ((carries8 & s) << 8)
          end
          s
        end
      end
    end

    def table
      if SLICING_SIZE
        if reflect_input
          @table = CRC.build_reflect_table(bitsize, polynomial, slice: SLICING_SIZE)
        else
          @table = CRC.build_table(bitsize, polynomial, slice: SLICING_SIZE)
        end
      else
        @table = nil
      end

      singleton_class.class_eval "attr_reader :table"

      @table
    end

    case ENV["RUBY_CRC_NOFAST"].to_i
    when 0, 1
      alias update update_with_slice_by_16
      SLICING_SIZE = 16
    when 2
      alias update update_with_lookup_table
      SLICING_SIZE = 1
    else
      alias update update_with_reference
      SLICING_SIZE = nil
    end
  end

  module Calcurator
    attr_reader :bitsize, :bitmask, :polynomial, :initial_crc,
                :reflect_input, :reflect_output, :xor_output, :name

    alias reflect_input? reflect_input
    alias reflect_output? reflect_output
  end

  module Utils
    def bitreflect8(n)
      n    = n.to_i
      n    = ((n & 0x55) <<  1) | ((n >>  1) & 0x55)
      n    = ((n & 0x33) <<  2) | ((n >>  2) & 0x33)
      return ((n & 0x0f) <<  4) |  (n >>  4) # 0x0f
    end

    def bitreflect16(n)
      n    = n.to_i
      n    = ((n & 0x5555) <<  1) | ((n >>  1) & 0x5555)
      n    = ((n & 0x3333) <<  2) | ((n >>  2) & 0x3333)
      n    = ((n & 0x0f0f) <<  4) | ((n >>  4) & 0x0f0f)
      return ((n & 0x00ff) <<  8) |  (n >>  8) # 0x00ff
    end

    def bitreflect32(n)
      n    = n.to_i
      n    = ((n & 0x55555555) <<  1) | ((n >>  1) & 0x55555555)
      n    = ((n & 0x33333333) <<  2) | ((n >>  2) & 0x33333333)
      n    = ((n & 0x0f0f0f0f) <<  4) | ((n >>  4) & 0x0f0f0f0f)
      n    = ((n & 0x00ff00ff) <<  8) | ((n >>  8) & 0x00ff00ff)
      return ((n & 0x0000ffff) << 16) |  (n >> 16) # 0x0000ffff
    end

    def bitreflect64(n)
      n    = n.to_i
      n    = ((n & 0x5555555555555555) <<  1) | ((n >>  1) & 0x5555555555555555)
      n    = ((n & 0x3333333333333333) <<  2) | ((n >>  2) & 0x3333333333333333)
      n    = ((n & 0x0f0f0f0f0f0f0f0f) <<  4) | ((n >>  4) & 0x0f0f0f0f0f0f0f0f)
      n    = ((n & 0x00ff00ff00ff00ff) <<  8) | ((n >>  8) & 0x00ff00ff00ff00ff)
      n    = ((n & 0x0000ffff0000ffff) << 16) | ((n >> 16) & 0x0000ffff0000ffff)
      return ((n & 0x00000000ffffffff) << 32) |  (n >> 32) # 0x00000000ffffffff
    end

    def bitreflect128(n)
      n    = n.to_i
      n    = ((n & 0x55555555555555555555555555555555) <<  1) | ((n >>  1) & 0x55555555555555555555555555555555)
      n    = ((n & 0x33333333333333333333333333333333) <<  2) | ((n >>  2) & 0x33333333333333333333333333333333)
      n    = ((n & 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f) <<  4) | ((n >>  4) & 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f)
      n    = ((n & 0x00ff00ff00ff00ff00ff00ff00ff00ff) <<  8) | ((n >>  8) & 0x00ff00ff00ff00ff00ff00ff00ff00ff)
      n    = ((n & 0x0000ffff0000ffff0000ffff0000ffff) << 16) | ((n >> 16) & 0x0000ffff0000ffff0000ffff0000ffff)
      n    = ((n & 0x00000000ffffffff00000000ffffffff) << 32) | ((n >> 32) & 0x00000000ffffffff00000000ffffffff)
      return ((n & 0x0000000000000000ffffffffffffffff) << 64) |  (n >> 64) # 0x0000000000000000ffffffffffffffff
    end
  end
end
