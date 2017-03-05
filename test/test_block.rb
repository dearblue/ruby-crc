#!ruby

require "test-unit"
require "crc"
require_relative "common"

class TestCRC < Test::Unit::TestCase
  $testmodules.each do |crc|
    next unless crc.const_defined?(:CHECK) && crc::CHECK
    class_eval(<<-"EOS", __FILE__, __LINE__ + 1)
      def test_block_#{crc.to_s.slice(/\w+$/)}
        assert_equal(#{crc}::CHECK, #{crc}.crc("123456789"))
      end

      def test_stream_#{crc.to_s.slice(/\w+$/)}
        s = #{crc}.new
        s << "123456789"
        assert_equal(#{crc}::CHECK, s.crc)
      end

      def test_stream2_#{crc.to_s.slice(/\w+$/)}
        s = #{crc}.new
        "123456789".each_char { |ch| s << ch }
        assert_equal(#{crc}::CHECK, s.crc)
      end
    EOS
  end
end
