class CRC
  module Extensions
    refine Integer do
      def to_magicdigest(bitsize, reflect)
        bytesize = bitsize.bitsize_to_bytesize
        if reflect
          magic = splitbytes("".b, bytesize, true)
        else
          tmp = self << ((bytesize * 8) - bitsize)
          magic = tmp.splitbytes("".b, bytesize, false)
        end
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
  end

  def magicdigest
    m = self.class
    crc.to_magicdigest(m.bitsize, m.reflect_output?)
  end
end
