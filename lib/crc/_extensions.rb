class CRC
  module Extensions
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

    # refinements:
    # * bitsize_to_bytesize
    # * bitsize_to_intsize
    # * byte_paddingsize
    # * int_paddingsize
    ;

    refine Integer do
      def bitsize_to_bytesize
        (self + 7) / 8
      end

      def bitsize_to_intsize
        bitsize = 8
        intsize = 1
        10.times do
          return intsize if self <= bitsize
          bitsize <<= 1
          intsize <<= 1
        end

        raise "数値が巨大すぎるため、intsize が決定できません - #{inspect}"
      end

      def byte_paddingsize
        (bitsize_to_bytesize * 8) - bitsize
      end

      def int_paddingsize
        (bitsize_to_intsize * 8) - bitsize
      end
    end

    # refinements:
    # * get_crc_module
    # * variant_for?
    ;

    refine BasicObject do
      def get_crc_module
        nil
      end

      def variant_for?(m)
        false
      end
    end

    refine CRC do
      alias get_crc_module class

      def variant_for?(m)
        get_crc_module.variant_for?(m)
      end
    end

    refine CRC.singleton_class do
      alias get_crc_module itself

      def variant_for?(m)
        return false unless m = m.get_crc_module

        if bitsize == m.bitsize &&
           polynomial == m.polynomial &&
           reflect_input? == m.reflect_input? &&
           reflect_output? == m.reflect_output? &&
           xor_output == m.xor_output
          true
        else
          false
        end
      end
    end
  end
end
