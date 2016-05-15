
# crc - CRC generator for ruby

This is a general CRC (Cyclic Redundancy Check) generator for ruby.

It is written by pure ruby with based on slice-by-eight algorithm (slice-by-16 algorithm as byte-order free and byte-alignment free).

Included built-in CRC modules are CRC-32, CRC-64-ECMA, CRC-64-ISO, CRC-16-CCITT, CRC-16-IBM, CRC-8, CRC-5-USB, CRC-5-EPC and many more.

Additional your customized CRC modules are defined to posible.

This library is slower than ×85+ of zlib/crc32, and slower than ×120+ of extlzma/crc32 on FreeBSD 10.3R amd64.

If you need more speed, please use [crc-turbo](https://rubygems/gems/crc-turbo).


## Summary

  * package name: crc
  * author: dearblue (mailto:dearblue@users.osdn.me)
  * report issue to: <https://osdn.jp/projects/rutsubo/ticket/>
  * how to install: ``gem install crc``
  * version: 0.2
  * release quality: thechnical preview
  * licensing: BSD-2-Clause<br>any parts are under Creative Commons License Zero (CC0 / Public Domain), and zlib-style License.
  * dependency gems: none
  * dependency external c libraries: none
  * bundled external c libraries: none


## Features

This examples are used CRC-32 module. Please see CRC::BasicCRC for more details.

  * CRC.crc32(seq, init = 0) -> crc-32 integer (likely as ``Zlib.crc32``)
  * CRC::CRC32.crc(seq, init = 0) -> crc-32 integer (likely as ``Zlib.crc32``)
  * CRC::CRC32.digest(seq, init = 0) -> crc-32 digest (likely as ``Digest::XXXX.digest``)
  * CRC::CRC32.hexdigest(seq, init = 0) -> crc-32 hex-digest (likely as ``Digest::XXXX.hexdigest``)
  * CRC::CRC32.new(init = 0) -> crc-32 context (likely as ``Digest::XXXX.new``)
  * CRC::CRC32#update(seq) -> self (likely as ``Digest::XXXX#update``)
  * CRC::CRC32#state -> crc-32 integer
  * CRC::CRC32#digest -> crc-32 digest (likely as ``Digest::XXXX#digest``)
  * CRC::CRC32#hexdigest -> crc-32 hex-digest (likely as ``Digest::XXXX#hexdigest``)
  * CRC.crc("crc-32", seq, init = 0) -> crc-32 integer
  * CRC.digest("crc-32", seq, init = 0) -> crc-32 digest
  * CRC.hexdigest("crc-32", seq, init = 0) -> crc-32 hex-digest
  * CRC::CRC32.combine(CRC.crc32("123"), CRC.crc32("456789"), 6) -> 3421780262 (likely as ``Zlib.crc32_comibne``)
  * CRC.CRC32("123") + CRC.CRC32("456") + CRC.CRC32("789") -> &#35;&lt;CRC::CRC32:CBF43926&gt;

----

  * CRC.create\_module(bitsize, poly, init\_state, refin, refout, xorout) -> new crc module class

    ``` ruby:ruby
    MyCRC32 = CRC.create_module(32, 0x04C11DB7)
    p MyCRC32.class  # => Class
    p MyCRC32.hexdigest("123456789")  # => "CBF43926"
    ```


## Built-in CRC modules

``` shell:shell
% ruby -rcrc -e 'puts CRC::MODULE_TABLE.values.uniq.map { |m| m::GENERATOR.name }.join(", ")'
```

CRC-1, CRC-3-ROHC, CRC-4-INTERLAKEN, CRC-4-ITU, CRC-5-EPC, CRC-5-ITU, CRC-5-USB, CRC-6-CDMA2000-A, CRC-6-CDMA2000-B, CRC-6-DARC, CRC-6-ITU, CRC-7, CRC-7-MVB, CRC-7-ROHC, CRC-7-UMTS, CRC-8, CRC-8-CCITT, CRC-8-MAXIM, CRC-8-DARC, CRC-8-SAE, CRC-8-WCDMA, CRC-8-CDMA2000, CRC-8-DVB-S2, CRC-8-EBU, CRC-8-I-CODE, CRC-8-ITU, CRC-8-LTE, CRC-8-ROHC, CRC-10, CRC-10-CDMA2000, CRC-11, CRC-11-UMTS, CRC-12-CDMA2000, CRC-12-DECT, CRC-12-UMTS, CRC-13-BBC, CRC-14-DARC, CRC-15, CRC-15-MPT1327, Chakravarty, ARC, CRC-16-ARINC, CRC-16-AUG-CCITT, CRC-16-CDMA2000, CRC-16-DECT-R, CRC-16-DECT-X, CRC-16-T10-DIF, CRC-16-DNP, CRC-16-BUYPASS, CRC-16-CCITT-FALSE, CRC-16-DDS-110, CRC-16-EN-13757, CRC-16-GENIBUS, CRC-16-LJ1200, CRC-16-MAXIM, CRC-16-MCRF4XX, CRC-16-RIELLO, CRC-16-TELEDISK, CRC-16-TMS37157, CRC-16-USB, CRC-A, KERMIT, MODBUS, X-25, XMODEM, CRC-17-CAN, CRC-21-CAN, CRC-24, CRC-24-Radix-64, CRC-24-OPENPGP, CRC-24-BLE, CRC-24-FLEXRAY-A, CRC-24-FLEXRAY-B, CRC-24-INTERLAKEN, CRC-24-LTE-A, CRC-24-LTE-B, CRC-30, CRC-30-CDMA, CRC-31-PHILIPS, CRC-32, CRC-32-BZIP2, CRC-32C, CRC-32D, CRC-32-MPEG-2, CRC-32-POSIX, CRC-32K, CRC-32K2, CRC-32Q, JAMCRC, XFER, CRC-40-GSM, CRC-64, CRC-64-ECMA, CRC-64-WE, CRC-64-ISO


## Environment variables for behavior

  * ``RUBY_CRC_NOFAST=0``: Use "crc-turbo" if posible. When failure required, same as ``RUBY_CRC_NOFAST=1``.
  * ``RUBY_CRC_NOFAST=1``: Force use ruby implementation with slice-by-16 algorithm. Not used "crc-turbo".
  * ``RUBY_CRC_NOFAST=2``: Switch to lookup table algorithm from slice-by-16 algorithm. Slower than about 52% (when CRC-32).
  * ``RUBY_CRC_NOFAST=3``: Switch to reference algorithm from slice-by-16 algorithm. Slower than about 7% (when CRC-32).


## About CRC::Generator#combine

CRC::Generator#combine is ported from Mark Adler's crccomb.c in https://stackoverflow.com/questions/29915764/generic-crc-8-16-32-64-combine-implementation#29928573 .
