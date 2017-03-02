#!ruby

require_relative "../crc"

class CRC
  using CRC::Extentions

  module ModuleClass
    #
    # call-seq:
    #   acrc(pre, post = nil, target_crc = 0) -> byte string as arc-code
    #
    # 目的となる crc になるように、指定された crc に続くバイト列を逆算します。
    #
    # 出力されるバイト列は、crc のビット数を表現できるバイト数となります。
    #
    # 現在のところ、reflect-input/output 限定となっています。
    #
    # * crc32("123456789????") の結果が 0 となるような、???? の部分を逆算する
    #
    #     seq = "123456789"
    #     arced_seq = CRC::CRC32.acrc(seq)
    #     p CRC::CRC32[seq + arced_seq] # => #<CRC::CRC32:00000000>
    #
    # * crc32("123456789????ABCDEFG") の結果が 0 となるような、???? の部分を逆算する
    #
    #     seq1 = "123456789"
    #     seq2 = "ABCDEFG"
    #     seq = seq1 + CRC::CRC32.acrc(seq1, seq2) + seq2
    #     p CRC::CRC32[seq] # => #<CRC::CRC32:00000000>
    #
    # * crc32("123456789????ABCDEFG") の結果が 0x12345678 となるような、???? の部分を逆算する
    #
    #     seq1 = "123456789"
    #     seq2 = "ABCDEFG"
    #     target_crc = 0x12345678
    #     seq = seq1 + CRC::CRC32.acrc(seq1, seq2, target_crc) + seq2
    #     p CRC::CRC32[seq] # => #<CRC::CRC32:12345678>
    #
    def acrc(pre, post = nil, targetcrc = 0)
      pre = pre.convert_internal_state_for(self)
      laststate = targetcrc.convert_target_state_for(self)
      state = unshiftbytes(post, laststate)
      bytesize = (bitsize + 7) / 8
      pre <<= (bytesize * 8 - bitsize) unless reflect_input?
      bytes = pre.splitbytes("".b, bytesize, reflect_input?)
      state = unshiftbytes(bytes, state)
      state <<= (bytesize * 8 - bitsize) unless reflect_input?
      state.splitbytes("".b, bytesize, reflect_input?)
    end
  end
end

if $0 == __FILE__
  seq = "abcdefghijklmnopqrstuvwxyz"
  seq2 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  code = CRC::X_25.acrc(seq, seq2)
  puts "base-crc=[%p, %p], arc'd-crc=%p, arc-code=%s" % [CRC::X_25[seq], CRC::X_25[seq2], CRC::X_25[seq + code + seq2], code.unpack("H*")[0]]
  code = CRC::CRC32.acrc(seq, seq2)
  puts "base-crc=[%p, %p], arc'd-crc=%p, arc-code=%s" % [CRC::CRC32[seq], CRC::CRC32[seq2], CRC::CRC32[seq + code + seq2], code.unpack("H*")[0]]
  code = CRC::CRC32C.acrc(seq, seq2)
  puts "base-crc=[%p, %p], arc'd-crc=%p, arc-code=%s" % [CRC::CRC32C[seq], CRC::CRC32C[seq2], CRC::CRC32C[seq + code + seq2], code.unpack("H*")[0]]

  MyCRC = crcmod = CRC.new(32, rand(1<<32) | 1, rand(1<<32) | 1, true, true, rand(1<<32) | 1)
  20.times do |i|
    s = (10+rand(20)).times.reduce("") { |a, *| a << rand(256).chr(Encoding::BINARY) }
    t = (10+rand(20)).times.reduce("") { |a, *| a << rand(256).chr(Encoding::BINARY) }
    crc = crcmod.new(s)
    puts "crc=[%p, %p], arc'd-crc=%p, target=%08X, seq=%s" %
      [crc, crcmod[t], crcmod.new(s + crcmod.acrc(crc.crc, t, i * 9929) + t), i * 9929, s.unpack("H*")[0]]
  end
end

__END__

目的となる CRC 値を逆算して、特定のバイト列を得る機能です。

ただの思いつきで、crc すると結果が 0 になるバイト列を計算できないかなと遊んでみた結果、
それなりの形となってしまいました。

以下は acrc メソッドとして実装した、その仕組みとなります。


X-25{CRC-16-0x1021 ref-in/out xor=0xffff} を用いた場合

("abcdefghijklmnopqrstuvwxyz" + ??) を CRC して結果を 0 にしたい (?? は2バイト)。

この時の ?? を求める。

先に "abcdefghijklmnopqrstuvwxyz" までの CRC を求めておく => 0x0d43

(ここまでの内部状態は 0xf2bc) ?? <STOP> (この段階で内部状態が 0xffff であること)

内部状態の最上位ビットから順に送って、目的となる内部状態が 0xffff から 0xf2bc になるような値を逆算する


code = 0 # 最終的に求めたい CRC
state = 0b1111001010111100 # 現在の CRC 生成器の内部状態
reversed_polynomial = 0b1000010000001000

    1. 最終的に求めたい CRC と xor_output する
            1111111111111111

    2. この時、code の最上位ビットが1なので、poly (reversed) で xor する
       最上位ビットが0ならば何もしない
            0111101111110111

    3. 左にずらす
            1111011111101110

    4. (2) において poly-reversed で xor したため、最下位ビットを1にする
       (2) を行わなかった場合は何もしない
            1111011111101111

    5. 目的となる内部状態の最上位ビットと作業内部状態の最下位ビットを xor した時に 1 となるように調整する
       (2) を行わなかった場合は 0 を維持するように処置する
            1111011111101110

    6. 1 ビット目の処理が完了。(2) に戻って必要なだけ繰り返す

    1111011111101110 <= 1   ## 最上位から2ビット目を入力
    1110011111001100 <= 1   ## 最上位から3ビット目を入力
    1100011110001000 <= 1   ## 以下同様に……
    1000011100000000 <= 0
    0000011000010001 <= 0
    0000110000100010 <= 1
    0001100001000101 <= 0
    0011000010001010 <= 1
    0110000100010101 <= 0
    1100001000101010 <= 1
    1000110001000100 <= 1
    0001000010011000 <= 1
    0010000100110001 <= 1
    0100001001100011 <= 0
    1000010011000110 <= 0
    0000000110011101        ## 繰り返して得られた結果
                               この結果を元にして、バイト順を入れ替える
                               (CRC として求める場合に、下位から入力されるため)

    10011101:00000001 >>>> [0x9d, 0x01] が返る

[EOF]
