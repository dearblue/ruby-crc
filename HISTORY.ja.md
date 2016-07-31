This document is written in Japanese.

# crc for ruby の更新履歴

## crc-0.3 (平成28年7月31日 日曜日)

互換性を損なう変更があります。

  * CRC::BasicCRC クラスと CRC::Generator クラスを、CRC クラスに統合
      * ruby オブジェクト CRC をモジュールからクラスに変更しました。
      * CRC::BasicCRC クラスと CRC::Generator クラスを削除しました。
      * crc-0.2 まで CRC::BasicCRC の派生クラスだった各 crc モジュールは
        CRC クラスから派生するようになりました。
  * CRC.create\_module を削除し、CRC.new に統合
      * crc-0.2 まであった CRC.create\_module メソッドを削除しました。
      * CRC.new メソッドが変わりの役割を担うようになりました。
  * crc モジュールの別名も CRC クラスの定数 (クラスの別名) として追加するように変更
  * CRC としての整数値を得るメソッドを引数なしで呼び出した場合、CRC モジュールを返すように変更
      * 例えば ``CRC.crc32`` を引数なしで呼び出すと、CRC::CRC32 クラスオブジェクトが返るようになりました。
  * CRC-64-ISO の修正
  * CRC モジュール名の整理
  * 初期値以外が同じかどうかを確認する CRC.variant? メソッドを追加
  * ``CRC#initial_crc`` を廃止
  * 定義が不確かな CRC モジュールを無効化
  * (実験的) 任意の CRC 値から逆算してバイト列を生成する機能 CRC.acrc (crc/acrc.rb) を追加

## crc-0.2 (平成28年5月15日 (日))

  * CRC モジュールの追加と修正
  * CRC::Utils.build\_table、CRC::Utils.build\_reflect\_table メソッドに slice キーワード引数を導入
  * CRC::Generator#combine、CRC::BasicCRC#+ メソッドの実装

## crc-0.1 (平成28年5月8日 (日))

初版
