
# crc - CRC generator for ruby

This is a general CRC (Cyclic Redundancy Check) generator for ruby.

It is written by pure ruby with based on slice-by-eight algorithm (slice-by-16 algorithm with byte-order free).

Included built-in CRC modules are CRC-32, CRC-32C, CRC-64-XZ, CRC-16, CRC-8-MAXIM, CRC-5-USB and many more.

Customization is posible for 1 to 64 bit width, any polynomials, and with/without bit reflection input/output.

This library is slower than ×85+ of zlib/crc32, and slower than ×120+ of extlzma/crc32 on FreeBSD 10.3R amd64.

If you need more speed, please use with [crc-turbo](https://rubygems/gems/crc-turbo).


## Summary

  * package name: crc
  * author: dearblue (mailto:dearblue@users.noreply.github.com)
  * report issue to: <https://github.com/dearblue/ruby-crc/issues>
  * how to install: ``gem install crc``
  * version: 0.4
  * production quality: TECHNICAL PREVIEW
  * licensing:
      * ***BSD-2-Clause : MAIN LICENSE***
      * zlib-style License : ``lib/crc/_combine.rb``
      * Creative Commons License Zero (CC0 / Public Domain) : ``lib/crc/_byruby.rb``, ``lib/crc/_modules.rb``
  * dependency gems: none
  * dependency external C libraries: none
  * bundled external C libraries: none
  * installed executable file:
      * rbcrc: CRC calcuration source code generator for c, ruby and javascript


## API Guide

This examples are used CRC-32 module. Please see CRC for more details.

### Calcurate by direct

  * ``CRC.crc32(seq, init = CRC::CRC32.initial_crc) => crc-32 integer`` (likely as ``Zlib.crc32``)
  * ``CRC.crc32.crc(seq, init = CRC::CRC32.initial_crc) => crc-32 integer`` (likely as ``Zlib.crc32``)
  * ``CRC.crc32.digest(seq, init = CRC::CRC32.initial_crc) => crc-32 digest`` (likely as ``Digest::XXXX.digest``)
  * ``CRC.crc32.hexdigest(seq, init = 0) -> crc-32 hex-digest`` (likely as ``Digest::XXXX.hexdigest``)
  * ``CRC.crc32[seq, init = 0, current_length = 0] -> crc-32 generator``
  * ``CRC.crc32.new(seq, init = 0, current_length = 0) -> crc-32 generator``

### Calcurate by streaming

  * ``CRC.crc32[init = 0, current_length = 0] => crc-32 generator``
  * ``CRC.crc32.new(init = 0, current_length = 0) => crc-32 generator``
  * ``CRC::CRC32#update(seq) => self`` (likely as ``Digest::XXXX.update``)
  * ``CRC::CRC32#finish => crc-32 integer`` (likely as ``Digest::XXXX.finish``)
  * ``CRC::CRC32#crc => crc-32 integer`` (same as ``CRC::CRC32#finish``)
  * ``CRC::CRC32#digest => crc-32 digest`` (likely as ``Digest::XXXX.digest``)
  * ``CRC::CRC32#hexdigest => crc-32 hex-digest`` (likely as ``Digest::XXXX.hexdigest``)

Example ::

``` ruby:ruby
x = CRC.crc32.new     # => #<CRC::CRC32:00000000>
x.update "123"        # => #<CRC::CRC32:884863D2>
x.update "456789"     # => #<CRC::CRC32:CBF43926>
x.crc                 # => 3421780262
x.digest              # => "\xCB\xF49&"
x.hexdigest           # => "CBF43926"
```

### Combine

  * ``CRC.combine(crc1, crc2, len2) => combined crc integer`` (likely as ``Zlib.crc32_comibne``)
  * ``CRC#+(right_crc) => combined crc generator``

Example-1 ::

``` ruby:ruby
CRC.crc32.combine(CRC.crc32("123"), CRC.crc32("456789"), 6) # => 3421780262
```

Example-2 ::

``` ruby:ruby
CRC.crc32["123"] + CRC.crc32["456"] + CRC.crc32["789"] # => #<CRC::CRC32:CBF43926>
```

### Create customized crc module

  * ``CRC.new(bitsize, poly, initial_crc = 0, refin = true, refout = true, xor_output = ~0) => new crc module class``

Example ::

``` ruby:ruby
MyCRC32 = CRC.new(32, 0x04C11DB7)
MyCRC32.class                     # => Class
MyCRC32.hexdigest("123456789")    # => "CBF43926"
MyCRC32.new("123456789")          # => #<MyCRC32:CBF43926>
```

### Calcurate arc-crc

  * ``CRC::XXX.acrc(pre, post = nil, want_crc = 0) => arc-crc byte string``

Example ::

``` ruby:ruby
a = "12"
c = "789"
wantcrc = CRC.crc32("123456789")
b = CRC.crc32.acrc(a, c, wantcrc)   # => "3456"
CRC.crc32[a + b + c]                # => #<CRC::CRC32:CBF43926>
```

See CRC::ModuleClass.acrc or below for more detail.


## Built-in CRC modules

```
$ rbcrc -lq
```

CRC-1, CRC-3-ROHC, CRC-4-INTERLAKEN, CRC-4-ITU, CRC-5-EPC, CRC-5-ITU, CRC-5-USB, CRC-6-CDMA2000-A, CRC-6-CDMA2000-B, CRC-6-DARC, CRC-6-ITU, CRC-7, CRC-7-ROHC, CRC-7-UMTS, CRC-8-CCITT, CRC-8-MAXIM, CRC-8-DARC, CRC-8-SAE, CRC-8-WCDMA, CRC-8-CDMA2000, CRC-8-DVB-S2, CRC-8-EBU, CRC-8-I-CODE, CRC-8-ITU, CRC-8-LTE, CRC-8-ROHC, CRC-10, CRC-10-CDMA2000, CRC-11, CRC-11-UMTS, CRC-12-CDMA2000, CRC-12-DECT, CRC-12-UMTS, CRC-13-BBC, CRC-14-DARC, CRC-15, CRC-15-MPT1327, CRC-16, CRC-16-AUG-CCITT, CRC-16-CDMA2000, CRC-16-DECT-R, CRC-16-DECT-X, CRC-16-T10-DIF, CRC-16-DNP, CRC-16-BUYPASS, CRC-16-CCITT-FALSE, CRC-16-DDS-110, CRC-16-EN-13757, CRC-16-GENIBUS, CRC-16-LJ1200, CRC-16-MAXIM, CRC-16-MCRF4XX, CRC-16-RIELLO, CRC-16-TELEDISK, CRC-16-TMS37157, CRC-16-USB, CRC-16-A, CRC-16-KERMIT, CRC-16-MODBUS, CRC-16-X-25, CRC-16-XMODEM, CRC-24-Radix-64, CRC-24-OPENPGP, CRC-24-BLE, CRC-24-FLEXRAY-A, CRC-24-FLEXRAY-B, CRC-24-INTERLAKEN, CRC-24-LTE-A, CRC-24-LTE-B, CRC-30-CDMA, CRC-31-PHILIPS, CRC-32, CRC-32-BZIP2, CRC-32C, CRC-32D, CRC-32-MPEG-2, CRC-32-POSIX, CRC-32Q, CRC-32-JAMCRC, CRC-32-XFER, CRC-40-GSM, CRC-64-XZ, CRC-64-JONES, CRC-64-ECMA, CRC-64-WE, CRC-64-ISO


## Environment variables for behavior

  * ``RUBY_CRC_NOFAST=0``: Use "crc-turbo" if posible. When failure required, same as ``RUBY_CRC_NOFAST=1``.
  * ``RUBY_CRC_NOFAST=1``: Force use ruby implementation with slice-by-16 algorithm. Not used "crc-turbo".
  * ``RUBY_CRC_NOFAST=2``: Switch to lookup table algorithm from slice-by-16 algorithm. Slower than about 52% (when CRC-32).
  * ``RUBY_CRC_NOFAST=3``: Switch to reference algorithm from slice-by-16 algorithm. Slower than about 7% (when CRC-32).


## About CRC.combine

CRC.combine is ported from Mark Adler's crccomb.c in <https://stackoverflow.com/questions/29915764/generic-crc-8-16-32-64-combine-implementation#29928573>.


## Source code generator for the specific CRC calcurator (from crc-0.3.1)

Add source code generator for the specific CRC calcurator to c, ruby, and javascript.

Algorithm is slicing-by-16 only for ruby and javascript.

For C, be able choose into bit-by-bit, bit-by-bit-fast, halfbyte-table,
standard-table, slicing-by-4, slicing-by-8, and slicing-by-16.

```
$ rbcrc --help
usage: rbcrc [options] output-filename...
 -m crcname   choose included crc name in library (``-l'' to print list)
 -n crcname   declare function name or class name [DEFAULT is filename]
 -s bitsize   declare crc bit size [REQUIRED for customized crc]
 -p polynom   declare crc polynomial [REQUIRED for customized crc]
 -c initcrc   declare initial crc (not internal state) [DEFAULT: 0]
 -S initstate  declare initial state (internal state) [DEFAULT: unset]
 -x xormask   declare xor bit mask for when output [DEFAULT: ~0]
 -i           reflect input [DEFAULT]
 -I           normal input (not reflect)
 -o           reflect output [DEFAULT]
 -O           normal output (not reflect)
 -a algorithm  switch algorithm (see below) (C file type only)

 -l           print crc names
 -f           force overwrite
 -v           increment verbosery level
 -q           quiet mode (reset verbosery level to zero)

About LICENSE for generated source code:
  Generated code is under Creative Commons License Zero (CC0 / Public Domain).
  See https://creativecommons.org/publicdomain/zero/1.0/

Algorithms (C file type only):
  bit-by-bit, bit-by-bit-fast, halfbyte-table, standard-table,
  slicing-by-4, slicing-by-8, slicing-by-16

Support export file types:
  * .c for C (support C89, but required ``stdint.h'')
  * .js for javascript (required ECMAScript 6th edition)
  * .rb for ruby (for ruby-2.1+, jruby, and rubinius)
                 (executable for ruby-1.8, ruby-1.9 and ruby-2.0)
                 (executable for mruby and limitation bitsize by fixnum)

examples:
  * create crc-32 generator to c source (and header file)
    $ rbcrc crc32.c

  * create crc-32c generator to ruby source
    $ rbcrc crc32c.rb

  * create crc-30-cdma generator to javascript source
    $ rbcrc crc30cdma.js

  * create crc-32 generator to ``crc.c'', ``crc.rb'' and ``crc.js''
    $ rbcrc -mcrc32 crc.c crc.rb crc.js

  * create customized crc generator (as mycrc function) to ``mycrc.c''
    $ rbcrc -s15 -p0x6789 -io -x~0 mycrc.c

  * create customized crc generator (as MyCRC class) to ``mycrc_1.rb''
    $ rbcrc -s39 -p0x987654321 -IO -x1 -nMyCRC mycrc_1.rb
```


## arc-crc

(Written in japanese from here)

crc-0.4 にて、任意の CRC となるバイト列を逆算する機能が正式に追加されました。

``require "crc/acrc"`` にて、その機能が利用可能となります。

名前の由来は、arc-sin などの C 関数である asin と同様に、arc-crc => acrc となっています。

以下は使用例です。

  * 文字列 "123456789????" を CRC32 した場合に 0 となるような、???? の部分を逆算する

    ``` ruby:ruby
    require "crc/acrc"

    seq = "123456789"
    seq << CRC.crc32.acrc(seq)
    p CRC.crc32[seq] # => #<CRC::CRC32:00000000>
    ```

  * 文字列 "123456789????ABCDEFG" の、???? の部分を逆算する

    ``` ruby:ruby
    require "crc/acrc"

    seq1 = "123456789"
    seq2 = "ABCDEFG"
    seq = seq1 + CRC.crc32.acrc(seq1, seq2) + seq2
    p CRC.crc32[seq] # => #<CRC::CRC32:00000000>
    ```

  * 文字列 "123456789????ABCDEFG" を CRC32 した場合に 0x12345678 となるような、???? の部分を逆算する

    ``` ruby:ruby
    require "crc/acrc"

    seq1 = "123456789"
    seq2 = "ABCDEFG"
    target_crc = 0x12345678
    seq = seq1 + CRC.crc32.acrc(seq1, seq2, target_crc) + seq2
    p CRC.crc32[seq] # => #<CRC::CRC32:12345678>
    ```

  * 独自仕様の CRC モジュールにも対応

    ``` ruby:ruby
    require "crc/acrc"

    seq1 = "123456789"
    seq2 = "ABCDEFG"
    target_crc = 0x12345678
    MyCRC = CRC.new(29, rand(1 << 29) | 1)
    seq = seq1 + MyCRC.acrc(seq1, seq2, target_crc) + seq2
    p MyCRC[seq] # => #<MyCRC:12345678>
    ```

[EOF]
