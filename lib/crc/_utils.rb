class CRC
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
end
