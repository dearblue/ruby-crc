require_relative "../crc"

module CRC
  def self.find(crc, seq, bitsize, polynomial, initstate = [0, ~0, 1], xor = [0, ~0, 1])
    bitsize0 = bitsize.to_i
    if bitsize0 < 1 || bitsize0 > 128
      raise ArgumentError, "wrong bitsize (expect 1..128, but given #{bitsize})"
    end
    bitmask = ~(~0 << bitsize0)
    crc &= bitmask
    [polynomial, Utils.bitreflect(polynomial, bitsize0)].each do |poly|
      poly &= bitmask
      [false, true].each do |refin|
        [false, true].each do |refout|
          Array(xor).each do |xormask|
            xormask &= bitmask
            Array(initstate).each do |init|
              init &= bitmask
              mod = CRC.create_module(bitsize0, poly, init, refin, refout, xormask)
              return mod if mod.crc(seq) == crc
            end
          end
        end
      end
    end

    nil
  end
end
