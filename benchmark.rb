#
# Only this code to the PUBLIC DOMAIN.
#

require "optparse"
require "benchmark"
#require "securerandom"
require "zlib"
require "crc"
begin; require "extlzma"; rescue LoadError; no_extlzma = true; end
begin; require "digest/crc"; rescue LoadError; no_digest_crc = true; end
begin; require "crc32"; rescue LoadError; no_crc32 = true; end

def measure(size, generator_name)
  print "  * measuring for #{generator_name}..."
  $stdout.flush
  realms = 5.times.map do
    real = (Benchmark.measure { yield }.real * 1000)
    print " #{(real * 100).round / 100.0} ms."
    $stdout.flush
    real
  end.min
  printf " (%.2f ms.) (peak: %0.2f MiB / s)\n", realms, size / (realms / 1000)
  [generator_name, realms]
end

opt = OptionParser.new
size = 2
opt.on("-s size", "set input data size in MiB (default: #{size} MiB)") { |x| size = x.to_i }
opt.on("--no-digest-crc") { no_digest_crc = true }
opt.on("--no-extlzma") { no_extlzma = true }
opt.parse!

puts <<"EOS"
*** Benchmark with #{RUBY_DESCRIPTION}.
EOS

puts " ** preparing #{size} MiB data...\n"
#s = SecureRandom.random_bytes(size << 20)
s = "0" * (size << 20)

crc = measure(size, "crc/crc32") { CRC.crc32(s) }[1]
comparisons = []
comparisons << measure(size, "zlib/crc-32") { Zlib.crc32(s) }
comparisons << measure(size, "extlzma/crc-32") { LZMA.crc32(s) } unless no_extlzma
comparisons << measure(size, "digest/crc-32") { Digest::CRC32.digest(s) } unless no_digest_crc
comparisons << measure(size, "crc32/crc-32") { Crc32.calculate(s, s.bytesize, 0) } unless no_crc32
comparisons << measure(size, "crc/crc-64") { CRC.crc64(s) }
comparisons << measure(size, "extlzma/crc-64") { LZMA.crc64(s) } unless no_extlzma
comparisons << measure(size, "crc/crc-5-usb") { CRC.crc5_usb(s) }
comparisons << measure(size, "crc/crc-16-usb") { CRC.crc16_usb(s) }
comparisons << measure(size, "crc/crc-32-posix") { CRC.crc32_posix(s) }
comparisons << measure(size, "crc/crc-32c") { CRC.crc32c(s) }

puts <<'EOS'
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                             (ruby-crc/crc32 is slowly at over 1.0)
EOS

comparisons.each do |name, meas|
  puts "%24s : ruby-crc/crc32 = %10.5f : 1.0\n" % [name, crc / meas]
end

puts <<'EOS'
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EOS
