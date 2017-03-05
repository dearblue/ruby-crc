#!ruby

require "test-unit"
require "crc"
require "optparse"

alltest = false
opt = OptionParser.new(nil, 12, " ")
opt.instance_eval do
  on("--all", "test all crc modules") { alltest = true }
  order!
end

if alltest
  $testmodules = CRC::MODULE_TABLE.values.uniq
else
  $testmodules = %w(
      CRC-32 CRC-32-POSIX CRC-64 CRC-64-ECMA
      CRC-3-ROHC CRC-5-USB CRC-7-ROHC CRC-7-UMTS CRC-8-CCITT CRC-8-MAXIM
      CRC-15 CRC-16 CRC-16-XMODEM CRC-24-OPENPGP CRC-24-BLE CRC-31-PHILIPS
  ).map { |e| CRC[e] }
end

