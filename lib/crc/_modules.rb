#!ruby

module CRC

  #
  # references from:
  #   * https://en.wikipedia.org/wiki/Cyclic_redundancy_check
  #   * https://ja.wikipedia.org/wiki/%E5%B7%A1%E5%9B%9E%E5%86%97%E9%95%B7%E6%A4%9C%E6%9F%BB
  #   * http://reveng.sourceforge.net/crc-catalogue/all.htm
  #   * http://crcmod.sourceforge.net/crcmod.predefined.html
  #   * https://users.ece.cmu.edu/~koopman/roses/dsn04/koopman04_crc_poly_embedded.pdf
  #

  list = [
    #
    # module name,        polynomial,     refrect input,
    #                           bit size,       reflect output,
    #                              initial state,     xor external,   crc("123456789"), alias names...
    #
    [:CRC1,                     0x01,  1,      0,  true,  true, ~0,                nil, "CRC-1"],
    [:CRC3_ROHC,                0x03,  3,     ~0,  true,  true,  0,               0x06, "CRC-3-ROHC"],
    [:CRC4_ITU,                 0x03,  4,      0,  true,  true,  0,               0x07, "CRC-4-ITU"],
    [:CRC5_EPC,                 0x09,  5,   0x09, false, false,  0,               0x00, "CRC-5-EPC"],
    [:CRC5_ITU,                 0x15,  5,      0,  true,  true,  0,               0x07, "CRC-5-ITU"],
    [:CRC5_USB,                 0x05,  5,      0,  true,  true, ~0,               0x19, "CRC-5-USB"],
    [:CRC6_CDMA2000_A,          0x27,  6,     ~0, false, false,  0,               0x0D, "CRC-6-CDMA2000-A"],
    [:CRC6_CDMA2000_B,          0x07,  6,     ~0, false, false,  0,               0x3B, "CRC-6-CDMA2000-B"],
    [:CRC6_DARC,                0x19,  6,      0,  true,  true,  0,               0x26, "CRC-6-DARC"],
    [:CRC6_ITU,                 0x03,  6,      0,  true,  true,  0,               0x06, "CRC-6-ITU"],
    [:CRC7,                     0x09,  7,      0, false, false,  0,               0x75, "CRC-7"],
    [:CRC7_MVB,                 0x65,  7,      0,  true,  true, ~0,                nil, "CRC-7-MVB"],
    [:CRC8,                     0xD5,  8,      0,  true,  true, ~0,                nil, "CRC-8"],
    [:CRC8_CCITT,               0x07,  8,      0,  true,  true, ~0,                nil, "CRC-8-CCITT"],
    [:CRC8_DALLAS_MAXIM,        0x31,  8,      0,  true,  true, ~0,                nil, "CRC-8-Dallas/Maxim"],
    [:CRC8_DARC,                0x39,  8,      0,  true,  true,  0,               0x15, "CRC-8-DARC"],
    [:CRC8_SAE,                 0x1D,  8,      0,  true,  true, ~0,                nil, "CRC-8-SAE"],
    [:CRC8_WCDMA,               0x9B,  8,      0,  true,  true,  0,               0x25, "CRC-8-WCDMA"],
    [:CRC10,                  0x0233, 10,      0, false, false,  0,             0x0199, "CRC-10"],
    [:CRC10_CDMA2000,         0x03D9, 10,     ~0, false, false,  0,             0x0233, "CRC-10-CDMA2000"],
    [:CRC11,                  0x0385, 11,   0x1a, false, false,  0,             0x05a3, "CRC-11"],
    [:CRC12,                  0x080F, 12,      0, false,  true,  0,             0x0daf, "CRC-12"],
    [:CRC12_CDMA2000,         0x0F13, 12,     ~0, false, false,  0,             0x0d4d, "CRC-12-CDMA2000"],
    [:CRC13_BBC,              0x1CF5, 13,      0, false, false,  0,             0x04fa, "CRC-13-BBC"],
    [:CRC14_DARC,             0x0805, 14,      0,  true,  true,  0,             0x082d, "CRC-14-DARC"],
    [:CRC15_CAN,              0x4599, 15,      0, false, false,  0,             0x059e, "CRC-15-CAN"],
    [:CRC15_MPT1327,          0x6815, 15,      1, false, false,  1,                nil, "CRC-15-MPT1327"],
    [:CHAKRAVARTY,            0x2F15, 16,      0,  true,  true, ~0,                nil, "Chakravarty"],
    [:CRC16_ARINC,            0xA02B, 16,      0,  true,  true, ~0,                nil, "CRC-16-ARINC"],
    [:CRC16_CCITT,            0x1021, 16,      0,  true,  true, ~0,                nil, "CRC-16-CCITT", "CRC-CCITT"],
    [:CRC16_CDMA2000,         0xC867, 16,      0,  true,  true, ~0,                nil, "CRC-16-CDMA2000"],
    [:CRC16_DECT,             0x0589, 16,      0,  true,  true, ~0,                nil, "CRC-16-DECT"],
    [:CRC16_T10_DIF,          0x8BB7, 16,      0,  true,  true, ~0,                nil, "CRC-16-T10-DIF"],
    [:CRC16_DNP,              0x3D65, 16,      0,  true,  true, ~0,                nil, "CRC-16-DNP"],
    [:CRC16_IBM,              0x8005, 16,      0,  true,  true, ~0,                nil, "CRC-16-IBM", "CRC-16", "CRC-16-ANSI"],
    [:CRC16_LZH,              0x8005, 16,      0,  true,  true,  0,             0xBB3D, "CRC-16-LZH", "CRC-LZH"],
    [:CRC17_CAN,          0x0001685B, 17,      0,  true,  true, ~0,                nil, "CRC-17-CAN"],
    [:CRC21_CAN,          0x00102899, 21,      0,  true,  true, ~0,                nil, "CRC-21-CAN"],
    [:CRC24,              0x005D6DCB, 24,      0,  true,  true, ~0,                nil, "CRC-24"],
    [:CRC24_RADIX_64,     0x00864CFB, 24,      0,  true,  true, ~0,                nil, "CRC-24-Radix-64"],
    [:CRC30,              0x2030B9C7, 30,      0,  true,  true, ~0,                nil, "CRC-30"],
    [:CRC32,              0x04c11db7, 32,      0,  true,  true, ~0,         0xCBF43926, "CRC-32"],
    [:CRC32C,             0x1edc6f41, 32,      0,  true,  true, ~0,         0xE3069283, "CRC-32C"],
    [:CRC32K,             0x741B8CD7, 32,      0,  true,  true, ~0,                nil, "CRC-32K"],
    [:CRC32K2,            0x32583499, 32,      0,  true,  true, ~0,                nil, "CRC-32K2"],
    [:CRC32Q,             0x814141AB, 32,      0, false, false,  0,         0x3010BF7F, "CRC-32Q"],
    [:CRC40_GSM,  0x0000000004820009, 40,     ~0, false, false, ~0,       0xD4164FC646, "CRC-40-GSM"],
    [:CRC64_ECMA, 0x42F0E1EBA9EA3693, 64,      0,  true,  true, ~0, 0x995DC9BBDF1939FA, "CRC-64-ECMA", "CRC-64"],
    [:CRC64_ISO,  0x000000000000001B, 64,      0,  true,  true, ~0,                nil, "CRC-64-ISO"],
  ]

  $stderr.puts "#{__FILE__}:#{__LINE__}: SELF CHECK for CRC modules (#{File.basename($".grep(/\/crc\/_(?:byruby|turbo)/)[0]||"")})\n" if SELF_TEST
  list.each do |name, polynomial, bitsize, initial_state, refin, refout, xor, check, *names|
    names.map! { |nm| nm.freeze }

    crc = create_module(bitsize, polynomial, initial_state, refin, refout, xor, names[0])

    const_set(name, crc)
    names.each { |nm| MODULE_TABLE[nm.downcase.gsub(/[\W_]+/, "")] = crc }

    check = Integer(check.to_i) if check
    crc.const_set :CHECK, check

    generator = crc::GENERATOR
    define_singleton_method(name.downcase, ->(*args) { generator.crc(*args) })
    define_singleton_method("#{name.downcase}_digest", ->(*args) { generator.digest(*args) })
    define_singleton_method("#{name.downcase}_hexdigest", ->(*args) { generator.hexdigest(*args) })

    if SELF_TEST
      checked = generator.crc("123456789")
      case
      when check.nil?
        $stderr.puts "| %20s(\"123456789\") = %16X (check only)\n" % [names[0], checked]
      when check != checked
        $stderr.puts "| %20s(\"123456789\") = %16X (expect to %016X)\n" % [names[0], checked, check]
      end
    end
  end
  exit if SELF_TEST

  class << self
    alias crc64 crc64_ecma
  end

  CRC64 = CRC64_ECMA
end
