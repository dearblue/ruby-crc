
# crc - CRC generator for ruby

This is a general CRC (Cyclic Redundancy Check) generator for ruby.

It is written by pure ruby with based on slice-by-eight algorithm (byte-order-free slice-by-16 algorithm).

Included built-in CRC modules are CRC-32, CRC-64-ECMA, CRC-64-ISO, CRC-16-CCITT, CRC-16-IBM, CRC-8, CRC-5-USB, CRC-5-EPC and more.

And your defined CRC modules to use.

This is slower than x95+ of zlib/crc32, and slower than x135+ of extlzma/crc32 on FreeBSD 10.3R amd64.

If you need more speed, please use crc-turbo.


## SUMMARY

  * package name: crc
  * author: dearblue (mailto:dearblue@users.osdn.me)
  * report issue to: <https://osdn.jp/projects/rutsubo/ticket/>
  * how to install: ``gem install crc``
  * version: 0.1
  * release quality: thechnical preview
  * licensing: BSD-2-Clause
  * dependency gems: none
  * dependency external c libraries: none
  * bundled external c libraries: none

## FEATURES

  * ``CRC.crc32(seq, init = 0) -> crc-32 integer`` (likely as ``Zlib.crc32``)
  * ``CRC::CRC32.crc(seq, init = 0) -> crc-32 integer`` (likely as ``Zlib.crc32``)
  * ``CRC::CRC32.digest(seq, init = 0) -> crc-32 digest`` (likely as ``Digest::XXXX.digest``)
  * ``CRC::CRC32.hexdigest(seq, init = 0) -> crc-32 hex-digest`` (likely as ``Digest::XXXX.hexdigest``)
  * ``CRC::CRC32.new(init = 0) -> crc-32 context`` (likely as ``Digest::XXXX.new``)
  * ``CRC::CRC32#update(seq) -> self`` (likely as ``Digest::XXXX#update``)
  * ``CRC::CRC32#finish -> crc-32 integer`` (likely as ``Digest::XXXX#finish``)
  * ``CRC.crc("crc-32", seq, init = 0) -> crc-32 integer``
  * ``CRC.digest("crc-32", seq, init = 0) -> crc-32 digest``
  * ``CRC.hexdigest("crc-32", seq, init = 0) -> crc-32 hex-digest``

----

  * ``CRC.create_module(bitsize, poly, init_state, refin, refout, xorout) -> new crc module class``

    ``` ruby:ruby
    MyCRC32 = CRC.create_module(32, 0x04C11DB7)
    p MyCRC32.class  # => Class
    p MyCRC32.hexdigest("123456789")  # => "CBF43926"
    ```


## BUILD-IN CRC MODULES

``` shell:shell
% ruby -rcrc -e 'puts CRC::MODULE_TABLE.values.uniq.map { |m| m::TRAITS.name }.join(", ")'
```

CRC-1, CRC-3-ROHC, CRC-4-ITU, CRC-5-EPC, CRC-5-ITU, CRC-5-USB, CRC-6-CDMA2000-A, CRC-6-CDMA2000-B, CRC-6-DARC, CRC-6-ITU, CRC-7, CRC-7-MVB, CRC-8, CRC-8-CCITT, CRC-8-Dallas/Maxim, CRC-8-DARC, CRC-8-SAE, CRC-8-WCDMA, CRC-10, CRC-10-CDMA2000, CRC-11, CRC-12, CRC-12-CDMA2000, CRC-13-BBC, CRC-14-DARC, CRC-15-CAN, CRC-15-MPT1327, Chakravarty, CRC-16-ARINC, CRC-16-CCITT, CRC-16-CDMA2000, CRC-16-DECT, CRC-16-T10-DIF, CRC-16-DNP, CRC-16-IBM, CRC-16-LZH, CRC-17-CAN, CRC-21-CAN, CRC-24, CRC-24-Radix-64, CRC-30, CRC-32, CRC-32C, CRC-32K, CRC-32K2, CRC-32Q, CRC-40-GSM, CRC-64-ECMA, CRC-64-ISO


## ENVIRONMENT VARIABLES FOR BEHAVIOR

  * ``RUBY_CRC_NOFAST=1``: Force use ruby implementation with slice-by-16 algorithm. Not used "crc-turbo".
  * ``RUBY_CRC_NOFAST=2``: Switch to lookup table algorithm from slice-by-16 algorithm. Slower to about 52% (when CRC-32).
  * ``RUBY_CRC_NOFAST=3``: Switch to reference algorithm from slice-by-16 algorithm. Slower to about 7% (when CRC-32).
