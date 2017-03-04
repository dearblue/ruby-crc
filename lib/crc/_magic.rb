class CRC
  module Extensions
    refine Integer do
      def to_magicdigest(bitsize, reflect, bytesize = bitsize.bitsize_to_bytesize)
        if reflect
          magic = splitbytes("".b, bytesize, true)
        else
          tmp = self << ((bytesize * 8) - bitsize)
          magic = tmp.splitbytes("".b, bytesize, false)
        end
      end

      def to_magicdigest_for(m)
        to_magicdigest(m.bitsize, m.reflect_output?)
      end
    end

    refine String do
      def to_magicdigest_for(m)
        bytes = m.bitsize.bitsize_to_bytesize
        unless bytes == bytesize
          raise "wrong byte size (expect #{bytes} bytes, but given #{inspect})", caller
        end

        unpack("C*").reduce { |a, ch| (a << 8) | ch }.to_magicdigest(m.bitsize, m.reflect_output?, bytes)
      end
    end

    refine CRC do
      def to_magicdigest_for(m)
        unless m.variant?(self.class)
          raise TypeError, "different crc type - #{self.class.inspect} (expect #{m.inspect})", caller
        end

        magicdigest
      end
    end

    refine BasicObject do
      def to_magicdigest_for(m)
        raise TypeError, "cant convert type - #{self.class}", caller
      end
    end

    refine CRC.singleton_class do
      def __cached_magic_code__
        @__cached_magic_code__ = crc("").to_magicdigest(bitsize, reflect_output?).freeze
        singleton_class.class_eval { attr_reader :__cached_magic_code__ }
        @__cached_magic_code__
      end
    end
  end

  using CRC::Extensions

  module ModuleClass
    def magicnumber
      @magicnumber = crc(__cached_magic_code__)
      singleton_class.class_eval { attr_reader :magicnumber }
      @magicnumber
    end

    def magic
      @magic = hexdigest(__cached_magic_code__).freeze
      singleton_class.class_eval { attr_reader :magic }
      @magic
    end

    def magicdigest(seq, crc = nil)
      crc(seq, crc).to_magicdigest(bitsize, reflect_output?)
    end

    def to_magicdigest(crc)
      crc.to_magicdigest_for(self)
    end
  end

  def magicdigest
    m = self.class
    crc.to_magicdigest(m.bitsize, m.reflect_output?)
  end
end
