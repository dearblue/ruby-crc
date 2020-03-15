#!ruby

#--
# Author:: dearblue <dearblue@users.noreply.github.com>
# License:: Creative Commons License Zero (CC0 / Public Domain)
#
# references from:
#   * https://en.wikipedia.org/wiki/Cyclic_redundancy_check
#   * https://ja.wikipedia.org/wiki/%E5%B7%A1%E5%9B%9E%E5%86%97%E9%95%B7%E6%A4%9C%E6%9F%BB
#   * http://reveng.sourceforge.net/crc-catalogue/all.htm
#   * http://crcmod.sourceforge.net/crcmod.predefined.html
#   * https://github.com/cluelogic/cluelib/blob/master/src/cl_crc.svh
#   * https://users.ece.cmu.edu/~koopman/crc/hw_data.html
#   * https://users.ece.cmu.edu/~koopman/roses/dsn04/koopman04_crc_poly_embedded.pdf
#   * (CRC-64-ISO-3309) http://swissknife.cvs.sourceforge.net/viewvc/swissknife/SWISS/lib/SWISS/CRC64.pm
#++

class CRC
  LIST = [
    #
    # bit size,  polynomial,              initial crc,
    #                reflect input,                xor output,
    #                      reflect output,                       crc("123456789"), names...
    #
    [ 1,               0x01,  true,  true,          0,     ~0,               0x01, "CRC-1"],
    [ 3,               0x03,  true,  true,         ~0,      0,               0x06, "CRC-3-ROHC", "CRC-3-RFC 3095"],
    [ 4,               0x03, false, false,          0,     ~0,               0x0b, "CRC-4-INTERLAKEN"],
    [ 4,               0x03,  true,  true,          0,      0,               0x07, "CRC-4-ITU"],
    [ 5,               0x09, false, false,       0x09,      0,               0x00, "CRC-5-EPC"],
    [ 5,               0x15,  true,  true,          0,      0,               0x07, "CRC-5-ITU"],
    [ 5,               0x05,  true,  true,          0,     ~0,               0x19, "CRC-5-USB"],
    [ 6,               0x27, false, false,         ~0,      0,               0x0D, "CRC-6-CDMA2000-A"],
    [ 6,               0x07, false, false,         ~0,      0,               0x3B, "CRC-6-CDMA2000-B"],
    [ 6,               0x19,  true,  true,          0,      0,               0x26, "CRC-6-DARC"],
    [ 6,               0x03,  true,  true,          0,      0,               0x06, "CRC-6-ITU"],
    [ 7,               0x09, false, false,          0,      0,               0x75, "CRC-7", "CRC-7-JESD84-A441"],
    #[ 7,               0x65, false, false,          0,      0,                nil, "CRC-7-MVB"],
    [ 7,               0x4F,  true,  true,         ~0,      0,               0x53, "CRC-7-ROHC", "CRC-7-RFC 3095"],
    [ 7,               0x45, false, false,          0,      0,               0x61, "CRC-7-UMTS"],
    #[ 8,               0xD5, false, false,          0,      0,                nil, "CRC-8"],
    [ 8,               0x07, false, false,          0,      0,               0xF4, "CRC-8-CCITT", "CRC-8-SMBus"],
    [ 8,               0x31,  true,  true,          0,      0,               0xA1, "CRC-8-MAXIM", "CRC-8-Dallas/Maxim", "DOW-CRC"],
    [ 8,               0x39,  true,  true,          0,      0,               0x15, "CRC-8-DARC"],
    [ 8,               0x1D, false, false,          0,     ~0,               0x4B, "CRC-8-SAE", "CRC-8-SAE-J1850"],
    [ 8,               0x9B,  true,  true,          0,      0,               0x25, "CRC-8-WCDMA"],
    [ 8,               0x9B, false, false,         ~0,      0,               0xDA, "CRC-8-CDMA2000"],
    [ 8,               0xD5, false, false,          0,      0,               0xBC, "CRC-8-DVB-S2"],
    [ 8,               0x1D,  true,  true,         ~0,      0,               0x97, "CRC-8-EBU", "CRC-8-AES"],
    [ 8,               0x1D, false, false,       0xFD,      0,               0x7E, "CRC-8-I-CODE"],
    [ 8,               0x07, false, false,       0x55,   0x55,               0xA1, "CRC-8-ITU"],
    [ 8,               0x9B, false, false,          0,      0,               0xEA, "CRC-8-LTE"],
    [ 8,               0x07,  true,  true,         ~0,      0,               0xD0, "CRC-8-ROHC", "CRC-8-RFC 3095"],
    [10,             0x0233, false, false,          0,      0,             0x0199, "CRC-10"],
    [10,             0x03D9, false, false,         ~0,      0,             0x0233, "CRC-10-CDMA2000"],
    [11,             0x0385, false, false,     0x001A,      0,             0x05A3, "CRC-11"],
    [11,             0x0307, false, false,          0,      0,             0x0061, "CRC-11-UMTS"],
    [12,             0x0F13, false, false,         ~0,      0,             0x0D4D, "CRC-12-CDMA2000"],
    [12,             0x080F, false, false,          0,      0,             0x0F5B, "CRC-12-DECT", "X-CRC-12"],
    [12,             0x080F, false,  true,          0,      0,             0x0DAF, "CRC-12-UMTS", "CRC-12-3GPP"],
    [13,             0x1CF5, false, false,          0,      0,             0x04FA, "CRC-13-BBC"],
    [14,             0x0805,  true,  true,          0,      0,             0x082D, "CRC-14-DARC"],
    [15,             0x4599, false, false,          0,      0,             0x059E, "CRC-15", "CRC-15-CAN"],
    [15,             0x6815, false, false,          1,      1,             0x2566, "CRC-15-MPT1327"],
    #[16,             0x2F15, false, false,          0,      0,                nil, "Chakravarty"],
    [16,             0x8005,  true,  true,          0,      0,             0xBB3D, "CRC-16", "ARC", "CRC-IBM", "CRC-16-ARC", "CRC-16-LHA"],
    #[16,             0xA02B, false, false,          0,      0,                nil, "CRC-16-ARINC"],
    [16,             0x1021, false, false,     0x1D0F,      0,             0xE5CC, "CRC-16-AUG-CCITT", "CRC-16-SPI-FUJITSU"],
    [16,             0xC867, false, false,         ~0,      0,             0x4C06, "CRC-16-CDMA2000"],
    [16,             0x0589, false, false,          1,      1,             0x007E, "CRC-16-DECT-R", "R-CRC-16"],
    [16,             0x0589, false, false,          0,      0,             0x007F, "CRC-16-DECT-X", "X-CRC-16"],
    [16,             0x8BB7, false, false,          0,      0,             0xD0DB, "CRC-16-T10-DIF"],
    [16,             0x3D65,  true,  true,         ~0,     ~0,             0xEA82, "CRC-16-DNP"],
    [16,             0x8005, false, false,          0,      0,             0xFEE8, "CRC-16-BUYPASS", "CRC-16-VERIFONE", "CRC-16-UMTS"],
    [16,             0x1021, false, false,         ~0,      0,             0x29B1, "CRC-16-CCITT-FALSE"],
    [16,             0x8005, false, false,     0x800D,      0,             0x9ECF, "CRC-16-DDS-110"],
    [16,             0x3D65, false, false,         ~0,     ~0,             0xC2B7, "CRC-16-EN-13757"],
    [16,             0x1021, false, false,          0,     ~0,             0xD64E, "CRC-16-GENIBUS", "CRC-16-EPC", "CRC-16-I-CODE", "CRC-16-DARC"],
    [16,             0x6F63, false, false,          0,      0,             0xBDF4, "CRC-16-LJ1200"],
    [16,             0x8005,  true,  true,         ~0,     ~0,             0x44C2, "CRC-16-MAXIM"],
    [16,             0x1021,  true,  true,         ~0,      0,             0x6F91, "CRC-16-MCRF4XX"],
    [16,             0x1021,  true,  true,     0x554D,      0,             0x63D0, "CRC-16-RIELLO"],
    [16,             0xA097, false, false,          0,      0,             0x0FB3, "CRC-16-TELEDISK"],
    [16,             0x1021,  true,  true,     0x3791,      0,             0x26B1, "CRC-16-TMS37157"],
    [16,             0x8005,  true,  true,          0,     ~0,             0xB4C8, "CRC-16-USB"],
    [16,             0x1021,  true,  true,     0x6363,      0,             0xBF05, "CRC-16-A", "CRC-A", "CRC-16-ISO/IEC FCD 14443-3"],
    [16,             0x1021,  true,  true,          0,      0,             0x2189, "CRC-16-KERMIT", "KERMIT", "CRC-16-CCITT", "CRC-16-CCITT-TRUE", "CRC-CCITT"],
    [16,             0x8005,  true,  true,         ~0,      0,             0x4B37, "CRC-16-MODBUS", "MODBUS"],
    [16,             0x1021,  true,  true,          0,     ~0,             0x906E, "CRC-16-X-25", "X-25", "CRC-16-IBM-SDLC", "CRC-16-ISO-HDLC", "CRC-16-CRC-B", "CRC-B"],
    [16,             0x1021, false, false,          0,      0,             0x31C3, "CRC-16-XMODEM", "XMODEM", "CRC-16-ZMODEM", "ZMODEM", "CRC-16-ACORN", "CRC-16-LTE"],
    #[17,         0x0001685B, false, false,          0,      0,                nil, "CRC-17-CAN"],
    #[21,         0x00102899, false, false,          0,      0,                nil, "CRC-21-CAN"],
    #[24,         0x005D6DCB, false, false,          0,      0,                nil, "CRC-24"],
    [24,         0x00864CFB, false, false,          0,      0,         0x00CDE703, "CRC-24-Radix-64"],
    [24,         0x00864CFB, false, false, 0x00B704CE,      0,         0x0021CF02, "CRC-24-OPENPGP"],
    [24,         0x0000065B,  true,  true, 0x00AAAAAA,      0,         0x00C25A56, "CRC-24-BLE"],
    [24,         0x005D6DCB, false, false, 0x00FEDCBA,      0,         0x007979BD, "CRC-24-FLEXRAY-A"],
    [24,         0x005D6DCB, false, false, 0x00ABCDEF,      0,         0x001F23B8, "CRC-24-FLEXRAY-B"],
    [24,         0x00328B63, false, false,          0,     ~0,         0x00B4F3E6, "CRC-24-INTERLAKEN"],
    [24,         0x00864CFB, false, false,          0,      0,         0x00CDE703, "CRC-24-LTE-A"],
    [24,         0x00800063, false, false,          0,      0,         0x0023EF52, "CRC-24-LTE-B"],
    #[30,         0x2030B9C7, false, false,          0,      0,                nil, "CRC-30"],
    [30,         0x2030B9C7, false, false,          0,     ~0,         0x04C34ABF, "CRC-30-CDMA"],
    [31,         0x04C11DB7, false, false,          0,     ~0,         0x0CE9E46C, "CRC-31-PHILIPS"],
    [32,         0x04C11DB7,  true,  true,          0,     ~0,         0xCBF43926, "CRC-32", "CRC-32-ADCCP", "CRC-32-PKZIP", "PKZIP"],
    [32,         0x04C11DB7, false, false,          0,     ~0,         0xFC891918, "CRC-32-BZIP2", "CRC-32-AAL5", "CRC-32-DECT-B", "B-CRC-32"],
    [32,         0x1EDC6F41,  true,  true,          0,     ~0,         0xE3069283, "CRC-32C", "CRC-32-ISCSI", "CRC-32-CASTAGNOLI", "CRC-32-INTERLAKEN"],
    [32,         0xa833982b,  true,  true,          0,     ~0,         0x87315576, "CRC-32D"],
    [32,         0x04C11DB7, false, false,         ~0,      0,         0x0376E6E7, "CRC-32-MPEG-2"],
    [32,         0x04C11DB7, false, false,         ~0,     ~0,         0x765E7680, "CRC-32-POSIX", "CKSUM"],
    #[32,         0x741B8CD7,  true,  true,          0,     ~0,                nil, "CRC-32K"],
    #[32,         0x32583499,  true,  true,          0,     ~0,                nil, "CRC-32K2"],
    [32,         0x814141AB, false, false,          0,      0,         0x3010BF7F, "CRC-32Q"],
    [32,         0x04C11DB7,  true,  true,         ~0,      0,         0x340BC6D9, "CRC-32-JAMCRC", "JAMCRC"],
    [32,         0x000000AF, false, false,          0,      0,         0xBD0BE338, "CRC-32-XFER", "XFER"],
    [40,       0x0004820009, false, false,         ~0,     ~0,       0xD4164FC646, "CRC-40-GSM"],
    [64, 0x42F0E1EBA9EA3693,  true,  true,          0,     ~0, 0x995DC9BBDF1939FA, "CRC-64-XZ", "CRC-64"],
    [64, 0xAD93D23594C935A9,  true,  true,         ~0,      0, 0xCAA717168609F281, "CRC-64-JONES"],
    [64, 0x42F0E1EBA9EA3693, false, false,          0,      0, 0x6C40DF5F0B497347, "CRC-64-ECMA", "CRC-64-ECMA-182"],
    [64, 0x42F0E1EBA9EA3693, false, false,          0,     ~0, 0x62EC59E3F1A4F00A, "CRC-64-WE"],
    [64, 0x000000000000001B,  true,  true,          0,      0, 0x46A5A9388A5BEFFE, "CRC-64-ISO", "CRC-64-ISO-3309"],
    # [82, 0x308C0111011401440411,  true,  true,          0,      0, 0x9EA83F625023801FD612, "CRC-82/DARC"],
  ]
end
