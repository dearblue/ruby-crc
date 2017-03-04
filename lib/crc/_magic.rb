class CRC
  module Extensions
    refine Integer do
      def to_magicdigest_for(m, bytesize = m.bitsize.bitsize_to_bytesize)
        if m.reflect_output?
          magic = splitbytes("".b, bytesize, true)
        else
          tmp = self << ((bytesize * 8) - m.bitsize)
          magic = tmp.splitbytes("".b, bytesize, false)
        end
      end
    end

    refine String do
      def to_magicdigest_for(m)
        bytes = m.bitsize.bitsize_to_bytesize
        case bytesize
        when bytes
          crc = unpack("C*").reduce { |a, ch| (a << 8) | ch }
        when bytes * 2
          crc = hex
        else
          raise TypeError, "wrong byte size (expect #{bytes} or #{bytes * 2} bytes, but given #{inspect})", caller
        end

        crc.to_magicdigest_for(m, bytes)
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
        @__cached_magic_code__ = initial_crc.to_magicdigest_for(self).freeze
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
      crc(seq, crc).to_magicdigest_for(self)
    end

    #
    # crc 値を与えると magicdigest へと変換したバイナリデータを返します。
    #
    # crc には整数値、digest/hexdigest データ、変種を含む CRC インスタンスを渡すことが出来ます。
    #
    def to_magicdigest(crc)
      crc.to_magicdigest_for(self)
    end
  end

  def magicdigest
    crc.to_magicdigest_for(self.class)
  end
end
