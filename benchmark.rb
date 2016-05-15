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

def measure(generator_name)
  print "  * measuring for #{generator_name}..."
  $stdout.flush
  realms = 5.times.map do
    real = (Benchmark.measure { yield }.real * 1000)
    print " #{(real * 100).round / 100.0} ms."
    $stdout.flush
    real
  end.min
  puts " (#{(realms * 100).round / 100.0} ms.)\n"
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

crc = measure("ruby-crc/crc32") { CRC.crc32(s) }[1]
comparisons = []
comparisons << measure("zlib/crc-32") { Zlib.crc32(s) }
comparisons << measure("extlzma/crc-32") { LZMA.crc32(s) } unless no_extlzma
comparisons << measure("digest/crc-32") { Digest::CRC32.digest(s) } unless no_digest_crc
comparisons << measure("ruby-crc/crc-64") { CRC.crc64(s) }
comparisons << measure("extlzma/crc-64") { LZMA.crc64(s) } unless no_extlzma

puts <<'EOS'
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                          (slowly at over 1.0)
EOS

comparisons.each do |name, meas|
  puts "%24s : ruby-crc/crc32 = %10.5f : 1.0\n" % [name, crc / meas]
end

puts <<'EOS'
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EOS
