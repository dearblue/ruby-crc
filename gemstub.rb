GEMSTUB = Gem::Specification.new do |s|
  s.name = "crc"
  s.version = "0.2"
  s.summary = "general CRC generator"
  s.description = <<EOS
This is a general CRC (Cyclic Redundancy Check) generator for ruby.
It is written by pure ruby with based on slice-by-eight algorithm (slice-by-16 algorithm as byte-order free and byte-alignment free).
Included built-in CRC modules are CRC-32, CRC-64-XZ, CRC-64-ECMA, CRC-64-ISO, CRC-16-CCITT, CRC-16-IBM, CRC-8, CRC-5-USB, CRC-5-EPC and many more.
Additional your customized CRC modules are defined to posible.
If you need more speed, please use crc-turbo.
EOS
  s.homepage = "https://osdn.jp/projects/rutsubo/"
  s.licenses = ["BSD-2-Clause", "Zlib", "CC0-1.0"]
  s.author = "dearblue"
  s.email = "dearblue@users.osdn.me"

  s.required_ruby_version = ">= 2.0"
  s.add_development_dependency "rake", "~> 11.0"
end

EXTRA << "benchmark.rb"
