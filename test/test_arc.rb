#!ruby

require "test-unit"
require_relative "common"
require "crc"
require "crc/acrc"
require "securerandom"

class TestArcCRC < Test::Unit::TestCase
  $testmodels.each do |crc|
    class_eval(<<-"EOS", __FILE__, __LINE__ + 1)
      def test_arc_#{crc.to_s.slice(/\w+$/)}
        crc = #{crc}
        [["", "", 12345],
         ["123456789", nil, 1234567],
         ["", "123456789", 123456789]].each do |a, b, t|
          t &= crc.bitmask
          assert_equal(t, crc.crc(a + crc.acrc(a, b, t) + (b || "")))
        end
      end
    EOS
  end
end
