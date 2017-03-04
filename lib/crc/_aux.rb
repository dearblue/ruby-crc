class CRC
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
end
