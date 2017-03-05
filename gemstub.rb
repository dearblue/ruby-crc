#!ruby

unless File.read("README.md", mode: "rt") =~ /^\s*\*\s*version: (\d+(?:\.\w+)+)/i
  raise "version number is not found in ``README.md''"
end

ver = $1

GEMSTUB = Gem::Specification.new do |s|
  s.name = "crc"
  s.version = ver
  s.summary = "general CRC calcurator"
  s.description = <<EOS
Pure ruby implemented general CRC (Cyclic Redundancy Check) calcurator.
Customization is posible for 1 to 64 bit width, any polynomials, and with/without bit reflection input/output.
If you need more speed, please use crc-turbo.
EOS
  s.homepage = "https://github.com/dearblue/ruby-crc-turbo"
  s.licenses = ["BSD-2-Clause", "Zlib", "CC0-1.0"]
  s.author = "dearblue"
  s.email = "dearblue@users.noreply.github.com"

  s.required_ruby_version = ">= 2.2"
  s.add_development_dependency "rake"
end

verfile = "lib/crc/version.rb"
task "version" => verfile
file verfile => "README.md" do
  File.write(verfile, <<-"EOS", mode: "wb")
#!ruby

class CRC
  VERSION = "#{ver}"
end
  EOS
end

LIB << verfile
LIB.uniq!

EXTRA << "benchmark.rb"
