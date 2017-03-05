require "crc"

$stderr.puts "#{__FILE__}:#{__LINE__}: SELF CHECK for CRC modules (#{File.basename($".grep(/_(?:byruby|turbo)/)[0]||"")})\n"

class CRC
  MODULE_TABLE.values.uniq.each do |crc|
    check = crc::CHECK
    checked = crc.crc("123456789")
    case check
    when nil
      $stderr.puts "| %20s(\"123456789\" * 1) = %16X (check only)\n" % [crc.name, checked]
    when checked
      ;
    else
      $stderr.puts "| %20s(\"123456789\" * 1) = %16X (expect to %X)\n" % [crc.name, checked, check]
    end

    check = 9.times.reduce(crc.new) { |a, x| a + crc.new(crc::CHECK, 9) }
    checked = crc["123456789" * 9]
    case check
    when nil
      $stderr.puts "| %20s(\"123456789\" * 9) = %16X (check only)\n" % [crc.name, checked]
    when checked
      ;
    else
      $stderr.puts "| %20s(\"123456789\" * 9) = %16X (expect to %X)\n" % [crc.name, checked, check]
    end
  end
end

$stderr.puts "#{__FILE__}:#{__LINE__}: DONE SELF CHECK\n"
