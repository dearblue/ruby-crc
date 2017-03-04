class CRC
  module Calcurator
    #
    # call-seq:
    #   shiftbits_by_bitbybit(bitset, state) -> state
    #
    def shiftbits_by_bitbybit(bitset, state)
      bitset = Array(bitset)

      if reflect_input?
        poly = CRC.bitreflect(polynomial, bitsize)
        bitset.each do |b|
          state ^= (1 & b)
          state = (state[0] == 0) ? (state >> 1) : ((state >> 1) ^ poly)
        end

        state
      else
        Aux.slide_to_head(bitsize, state, polynomial, bitmask) do |s, poly, csh, head, carries|
          bitset.each do |b|
            s ^= (1 & b) << head
            s = (s[head] == 0) ? (s << 1) : (((carries & s) << 1) ^ poly)
          end

          s
        end
      end
    end

    #
    # call-seq:
    #   shiftbytes_by_bitbybit(byteset, state)
    #
    # standard input の場合は byte は上位ビットから、reflect input の場合は byte は下位ビットから計算されます。
    #
    def shiftbytes_by_bitbybit(byteset, state)
      if reflect_input?
        poly = CRC.bitreflect(polynomial, bitsize)
        byteset.each_byte do |b|
          state ^= 0xff & b
          8.times do
            state = (state[0] == 0) ? (state >> 1) : ((state >> 1) ^ poly)
          end
        end

        state
      else
        Aux.slide_to_head(bitsize, state, polynomial, bitmask) do |s, poly, csh, head, carries|
          byteset.each_byte do |b|
            s ^= (0xff & b) << csh
            8.times do
              s = (s[head] == 0) ? (s << 1) : (((carries & s) << 1) ^ poly)
            end
          end

          s
        end
      end
    end

    #
    # call-seq:
    #   unshiftbits_by_bitbybit(bitset, state)
    #
    # bitset を与えることで state となるような内部状態を逆算します。
    #
    def unshiftbits_by_bitbybit(bitset, state)
      bitset = Array(bitset)

      if reflect_input?
        poly = (CRC.bitreflect(polynomial, bitsize) << 1) | 1
        head = bitsize
        bitset.reverse_each do |b|
          state <<= 1
          state ^= poly unless state[head] == 0
          state ^= 1 & b
        end

        state
      else
        Aux.slide_to_head(bitsize, state, polynomial, bitmask) do |s, poly, csh, head, carries|
          headbit = 1 << head
          lowoff = (head + 1) - bitsize
          poly = (poly >> 1) | headbit
          bitset.reverse_each do |b|
            tmp = s[lowoff]
            s >>= 1
            s ^= poly unless tmp == 0
            s ^= (1 & b) << head
          end

          s
        end
      end
    end

    #
    # call-seq:
    #   unshiftbytes_by_bitbybit(byteset, state)
    #
    # byteset を与えることで state となるような内部状態を逆算します。
    #
    def unshiftbytes_by_bitbybit(byteset, state)
      if reflect_input?
        poly = (CRC.bitreflect(polynomial, bitsize) << 1) | 1
        head = bitsize
        byteset.reverse_each_byte do |b|
          7.downto(0) do |i|
            state <<= 1
            state ^= poly unless state[head] == 0
            state ^= b[i]
          end
        end

        state
      else
        Aux.slide_to_head(bitsize, state, polynomial, bitmask) do |s, poly, csh, head, carries|
          headbit = 1 << head
          lowoff = (head + 1) - bitsize
          poly = (poly >> 1) | headbit
          byteset.reverse_each_byte do |b|
            8.times do |i|
              tmp = s[lowoff]
              s >>= 1
              s ^= poly unless tmp == 0
              s ^= b[i] << head
            end
          end

          s
        end
      end
    end

    def unshift_table
      if reflect_input?
        if bitsize < 8
          pad = 8 - bitsize
          shift = 0
        else
          pad = 0
          shift = bitsize - 8
        end
        poly = ((CRC.bitreflect(polynomial, bitsize) << 1) | 1) << pad
        head = bitsize + pad
        @unshift_table = 256.times.map do |ch|
          state = ch << shift
          8.times do |i|
            state <<= 1
            state ^= poly unless state[head] == 0
          end
          state >> pad
        end
      else
        raise NotImplementedError
      end

      singleton_class.module_eval { attr_reader :unshift_table }

      @unshift_table
    end

    def unshiftbytes_by_table(byteset, state)
      if reflect_input?
        table = unshift_table
        if bitsize < 8
          pad = 8 - bitsize
          shift = 0
          mask = bitmask
          byteset.reverse_each_byte do |ch|
            state = (state << 8) ^ ch
            state = table[state >> bitsize] ^ (ch & mask)
          end
        else
          shift = bitsize - 8
          mask = ~(~0 << shift)
          byteset.reverse_each_byte do |ch|
            state = table[state >> shift] ^ ((state & mask) << 8)
            state ^= ch
          end
        end

        state
      else
        unshiftbytes_by_bitbybit(byteset, state)
      end
    end

    alias shiftbits shiftbits_by_bitbybit
    alias shiftbytes shiftbytes_by_bitbybit
    alias unshiftbits unshiftbits_by_bitbybit
    alias unshiftbytes unshiftbytes_by_table
  end
end
