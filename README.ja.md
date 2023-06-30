# crc - CRC calcurator for ruby

これは Ruby 向けの汎用 CRC (巡回冗長検査; Cyclic Redundancy Check) 算出器です。

“Slicing by 8” アルゴリズムを基にした“バイトオーダーフリーの Slicing by 16 アルゴリズム” を 100% Ruby で記述しています。

CRC モデルとして CRC-32、CRC-32C、CRC-64-XZ、CRC-16、CRC-8-MAXIM、CRC-5-USB ほか多数が最初から組み込まれています。

利用者は、1〜64のビット幅、任意の多項式、および入出力のビット反射の有無に関してカスタマイズが可能です。

このライブラリは FreeBSD 10.3R amd64 上の zlib の `crc32()` よりも 85倍以上遅く、liblzma の `crc32()` よりも 120倍以上低速です。

さらに速度が必要な場合は、[crc-turbo](https://rubygems.org/gems/crc-turbo) と併用してください。


## API Guide

この例は CRC-32 モデル (`CRC::CRC32` クラス) を使用しています。
他の CRC モデルについては脳内変換して下さい。

### 即時的算出

  * `CRC.crc32(seq, init = CRC::CRC32.initial_crc) => crc-32 integer` (likely as `Zlib.crc32`)
  * `CRC.crc32.crc(seq, init = CRC::CRC32.initial_crc) => crc-32 integer` (likely as `Zlib.crc32`)
  * `CRC.crc32.digest(seq, init = CRC::CRC32.initial_crc) => crc-32 digest` (likely as `Digest::XXXX.digest`)
  * `CRC.crc32.hexdigest(seq, init = CRC::CRC32.initial_crc) -> crc-32 hex-digest` (likely as `Digest::XXXX.hexdigest`)
  * `CRC.crc32[seq, init = CRC::CRC32.initial_crc, current_length = 0] -> crc-32 calcurator`

### 段階的算出 (ストリーミング)

  * `CRC.crc32.new(init = 0, current_length = 0) => crc-32 calcurator`
  * `CRC::CRC32#update(seq) => self` (likely as `Digest::XXXX.update`)
  * `CRC::CRC32#finish => crc-32 integer` (likely as `Digest::XXXX.finish`)
  * `CRC::CRC32#crc => crc-32 integer` (same as `CRC::CRC32#finish`)
  * `CRC::CRC32#digest => crc-32 digest` (likely as `Digest::XXXX.digest`)
  * `CRC::CRC32#hexdigest => crc-32 hex-digest` (likely as `Digest::XXXX.hexdigest`)

#### 例

``` ruby:ruby
x = CRC.crc32.new     # => #<CRC::CRC32:00000000>
x.update "123"        # => #<CRC::CRC32:884863D2>
x.update "456789"     # => #<CRC::CRC32:CBF43926>
x.crc                 # => 3421780262
x.digest              # => "\xCB\xF49&"
x.hexdigest           # => "CBF43926"
```

### CRC 値の結合

  - `CRC.combine(crc1, crc2, len2) => combined crc integer` (likely as `Zlib.crc32_comibne`)
  - `CRC#+(right_crc) => combined crc calcurator`

`CRC.combine` は Mark Adler 氏による crccomb.c (<https://stackoverflow.com/questions/29915764/generic-crc-8-16-32-64-combine-implementation#29928573>) をそっくり~~パクった~~移植したものです。

#### 例1

``` ruby:ruby
CRC.crc32.combine(CRC.crc32("123"), CRC.crc32("456789"), 6) # => 3421780262
```

#### 例2

``` ruby:ruby
CRC.crc32["123"] + CRC.crc32["456"] + CRC.crc32["789"] # => #<CRC::CRC32:CBF43926>
```

### 利用者定義 CRC モデルの生成

  * `CRC.new(bitsize, poly, initial_crc = 0, refin = true, refout = true, xor_output = ~0) => new crc model class`

#### 例

``` ruby:ruby
MyCRC32 = CRC.new(32, 0x04C11DB7)
MyCRC32.class                     # => Class
MyCRC32.hexdigest("123456789")    # => "CBF43926"
MyCRC32["123456789"]              # => #<MyCRC32:CBF43926>
```

### 逆進 CRC 値の算出

  - `CRC::XXX.acrc(pre, post = nil, want_crc = 0) => arc-crc byte string`

#### 例

``` ruby:ruby
a = "12"
c = "789"
wantcrc = CRC.crc32("123456789")
b = CRC.crc32.acrc(a, c, wantcrc)   # => "3456"
CRC.crc32[a + b + c]                # => #<CRC::CRC32:CBF43926>
```

See CRC::Calcurate.acrc or below for more detail.


## 組み込み CRC モデル

```
$ rbcrc -lq
```

CRC-1, CRC-3-ROHC, CRC-4-INTERLAKEN, CRC-4-ITU, CRC-5-EPC, CRC-5-ITU, CRC-5-USB, CRC-6-CDMA2000-A, CRC-6-CDMA2000-B, CRC-6-DARC, CRC-6-ITU, CRC-7, CRC-7-ROHC, CRC-7-UMTS, CRC-8-CCITT, CRC-8-MAXIM, CRC-8-DARC, CRC-8-SAE, CRC-8-WCDMA, CRC-8-CDMA2000, CRC-8-DVB-S2, CRC-8-EBU, CRC-8-I-CODE, CRC-8-ITU, CRC-8-LTE, CRC-8-ROHC, CRC-10, CRC-10-CDMA2000, CRC-11, CRC-11-UMTS, CRC-12-CDMA2000, CRC-12-DECT, CRC-12-UMTS, CRC-13-BBC, CRC-14-DARC, CRC-15, CRC-15-MPT1327, CRC-16, CRC-16-AUG-CCITT, CRC-16-CDMA2000, CRC-16-DECT-R, CRC-16-DECT-X, CRC-16-T10-DIF, CRC-16-DNP, CRC-16-BUYPASS, CRC-16-CCITT-FALSE, CRC-16-DDS-110, CRC-16-EN-13757, CRC-16-GENIBUS, CRC-16-LJ1200, CRC-16-MAXIM, CRC-16-MCRF4XX, CRC-16-RIELLO, CRC-16-TELEDISK, CRC-16-TMS37157, CRC-16-USB, CRC-16-A, CRC-16-KERMIT, CRC-16-MODBUS, CRC-16-X-25, CRC-16-XMODEM, CRC-24-Radix-64, CRC-24-OPENPGP, CRC-24-BLE, CRC-24-FLEXRAY-A, CRC-24-FLEXRAY-B, CRC-24-INTERLAKEN, CRC-24-LTE-A, CRC-24-LTE-B, CRC-30-CDMA, CRC-31-PHILIPS, CRC-32, CRC-32-BZIP2, CRC-32C, CRC-32D, CRC-32-MPEG-2, CRC-32-POSIX, CRC-32Q, CRC-32-JAMCRC, CRC-32-XFER, CRC-40-GSM, CRC-64-XZ, CRC-64-JONES, CRC-64-ECMA, CRC-64-WE, CRC-64-ISO


## 環境変数

### `RUBY_CRC_NOFAST`

内部処理の実装を変更します。

  - `RUBY_CRC_NOFAST=0`: 可能であれば "crc-turbo" を使います。ライブラリの読み込みが出来なければ、`RUBY_CRC_NOFAST=1` と同じ挙動になります。
  - `RUBY_CRC_NOFAST=1`: Ruby で実装された“Slicing by 16”アルゴリズムの仕様を強制します。"crc-turbo" は使われません。
  - `RUBY_CRC_NOFAST=2`: Dilip V. Sarwate 氏によるテーブルアルゴリズムに切り替えます。52% ほどに低速となります (CRC-32 の場合)。
  - `RUBY_CRC_NOFAST=3`: ビット単位の計算アルゴリズムに切り替えます。`RUBY_CRC_NOFAST=1` と比較して 7% ほどに低速となります (CRC-32 の場合)。


## Source code generator for the specific CRC calcurator (from crc-0.3.1)

C・Ruby・javascript 向けの特化した CRC 算出器のソースコード生成機能があります。

アルゴリズムは Ruby および javascript の場合は“Slicing by 16”に限定されます。

Cの場合は、bit-by-bit, bit-by-bit-fast, halfbyte-table, standard-table, slicing-by-4, slicing-by-8, and slicing-by-16 を選択できます。

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
  slicing-by-4, slicing-by-8, slicing-by-16, slicing-by-{2..999}

Support export file types:
  * .c for C (support C89, but required ``stdint.h'')
  * .js for javascript (required ECMAScript 6th edition)
  * .rb for ruby (for ruby-2.1+, jruby, and rubinius)
                 (executable for ruby-1.8, ruby-1.9 and ruby-2.0)
                 (executable for mruby and limitation bitsize by fixnum)

examples:
  * create crc-32 calcurator to c source (and header file)
    $ rbcrc crc32.c

  * create crc-32c calcurator to ruby source
    $ rbcrc crc32c.rb

  * create crc-30-cdma calcurator to javascript source
    $ rbcrc crc30cdma.js

  * create crc-32 calcurator to ``crc.c'', ``crc.rb'' and ``crc.js''
    $ rbcrc -mcrc32 crc.c crc.rb crc.js

  * create customized crc calcurator (as mycrc function) to ``mycrc.c''
    $ rbcrc -s15 -p0x6789 -io -x~0 mycrc.c

  * create customized crc calcurator (as MyCRC class) to ``mycrc_1.rb''
    $ rbcrc -s39 -p0x987654321 -IO -x1 -nMyCRC mycrc_1.rb
```

- - - -

また、このコマンドには各 CRC 仕様を YAML 形式で出力する機能もあります。

``` text
$ rbcrc -lvv
...snip...
"CRC-32":
  bitsize:              32
  polynomial:           0x04C11DB7  # 0xEDB88320 (bit reflected)
  reversed reciprocal:  0x82608EDB  # 0xDB710641 (bit reflected)
  reflect input:        true
  reflect output:       true
  initial crc:          0x00000000  # 0xFFFFFFFF (initial state)
  xor output:           0xFFFFFFFF
  magic number:         0x2144DF1C  # 0xDEBB20E3 (internal state)
  another names:
  - "CRC-32-ADCCP"
  - "CRC-32-PKZIP"
  - "PKZIP"
...snip...
```


## CRC の逆算 (arc-crc)

crc-0.4 にて、任意の CRC となるバイト列を逆算する機能が正式に追加されました。

`require "crc/acrc"` にて、その機能が利用可能となります。

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


## Ractor への対応について

Ractor 対応は限定的です。

内部テーブルがメイン Ractor で初期化されていない場合、メインでない Ractor で検算処理を行うと `Ractor::IsolationError` 例外が発生します。

```ruby
ENV["RUBY_CRC_NOFAST"] = "1"
require "crc"

Ractor.new { CRC.crc32["123456789"] }.take
# => raised Ractor::IsolationError
```

メインではない Ractor で利用する CRC クラスを予め温めておく必要があります。

```ruby
ENV["RUBY_CRC_NOFAST"] = "1"
require "crc"

CRC.crc32.table rescue nil  # <= Warming up! ("rescue" modifier is for use with crc-turbo)

p Ractor.new { CRC.crc32["123456789"] }.take
# => #<CRC::CRC32:CBF43926>
```


## 諸元

  - package name: crc
  - author: dearblue (mailto:dearblue@users.noreply.github.com)
  - report issue to: <https://github.com/dearblue/ruby-crc/issues>
  - how to install: `gem install crc`
  - version: 0.4.2
  - production quality: TECHNICAL PREVIEW
  - licensing:
      - ***2 clause BSD License: MAIN LICENSE***
      - zlib-style License: `lib/crc/_combine.rb`
      - Creative Commons License Zero (CC0 / Public Domain): `lib/crc/_byruby.rb`, `lib/crc/_models.rb`
  - dependency gems: none
  - dependency external C libraries: none
  - bundled external C libraries: none
  - installed executable file:
      - `rbcrc`: CRC calcuration source code generator for c, ruby and javascript
