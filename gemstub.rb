require_relative "lib/crc/version"

GEMSTUB = Gem::Specification.new do |s|
  s.name = "crc"
  s.version = CRC::VERSION
  s.summary = "general CRC generator"
  s.description = <<EOS
This is a general CRC (Cyclic Redundancy Check) generator for ruby.
It is written by pure ruby.
Customization is posible for 1 to 64 bit width, any polynomial primitives, and with/without bit reflection input/output.
If you need more speed, please use crc-turbo.
EOS
  s.homepage = "https://osdn.jp/projects/rutsubo/"
  s.licenses = ["BSD-2-Clause", "Zlib", "CC0-1.0"]
  s.author = "dearblue"
  s.email = "dearblue@users.osdn.me"

  s.required_ruby_version = ">= 2.0"
  s.add_development_dependency "rake"
end

EXTRA << "benchmark.rb"
