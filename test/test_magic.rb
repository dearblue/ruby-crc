#!ruby

require "test-unit"
require "crc"
require_relative "common"

class TestCRCMagic < Test::Unit::TestCase
  $testmodels.each do |crc|
    next unless crc.const_defined?(:CHECK) && crc::CHECK
    name = crc.to_s.slice(/\w+$/)
    class_eval(<<-"TESTCODE", __FILE__, __LINE__ + 1)
      def test_magic_#{name}
        assert_equal #{crc}.magic, #{crc}.hexdigest(#{crc}.magicdigest(""))
        assert_equal #{crc}.magic, #{crc}.hexdigest("A" + #{crc}.magicdigest("A"))
        assert_equal #{crc}.magic, #{crc}.hexdigest("A" * 100 + #{crc}.magicdigest("A" * 100))
      end

      def test_magicnumber_#{name}
        assert_equal #{crc}.magicnumber, #{crc}.crc(#{crc}.magicdigest(""))
        assert_equal #{crc}.magicnumber, #{crc}.crc("A" + #{crc}.magicdigest("A"))
        assert_equal #{crc}.magicnumber, #{crc}.crc("A" * 100 + #{crc}.magicdigest("A" * 100))
      end
    TESTCODE
  end
end
