This document is written in Japanese.

# crc for ruby の更新履歴

## crc-0.4.0.1 (平成29年3月28日 火曜日)

  * acrc、shift 系メソッドのバグ修正


## crc-0.4 (平成29年3月5日 日曜日)

***互換性を損なう変更があります。***

  * **[互換性を損なう変更]** CRC.new と CRC.[] の役割を分担

      * これまで CRC をサブクラスとしたクラスメソッド CRC.new と CRC.[] は全く同じ挙動をしていましたが、役割を分担しました。

        ``CRC.new`` は初期化のためのメソッドとし、``CRC.[]`` は CRC インスタンスを返す ``CRC.crc`` のようなメソッドとなるようにしました。

      * ``CRC.new(seq, ...)`` の形では呼び出せなくなりました。

      * ``CRC.[](seq, ...)`` の seq は必須としました。

  * **[互換性を損なう変更]** bin/rbcrc のオプション名を変更

      * ``-M`` および ``-N`` オプションをそれぞれ小文字に変更しました。

  * ``CRC.file`` 及び ``CRC#file`` メソッドの追加

      * ファイルパスを与えると CRC を計算してインスタンスを返す ``CRC.file`` 及び ``CRC#file`` を追加しました。

  * ``CRC.magic``、``CRC.magicnumber``、``CRC.magicdigest``、``CRC.to_magicdigest``、``CRC#magicdigest`` メソッドの追加

      * マジックナンバーを取得・計算するためのメソッドを追加しました。

        これらは CRC-32 の場合であれば RFC1570 で出てくるマジックナンバー 0xdebb20e3 のことです。

  * 任意の CRC 値から逆算してバイト列を生成する機能 CRC.acrc (crc/acrc.rb) を正式に追加

      * crc-0.3 で実験的に追加された同機能を、正式なものとしました。

        この機能は入出力の正順・逆順に関わらずに利用可能です。

  * ``CRC.shiftbits`` ``CRC.shiftbytes`` ``CRC.unshiftbits`` ``CRC.unshiftbytes`` を追加

      * 任意長のビット列を与えて内部状態を更新する ``CRC.shiftbits`` を追加しました。

      * 任意長の8ビット列を与えて内部状態を更新する ``CRC.shiftbytes`` を追加しました。
          * ``CRC.update`` とは異なり、整数値で構成される配列を渡すことが出来ます。

      * 任意長のビット列を与えて内部状態を差し戻す ``CRC.unshiftbits`` を追加しました。

      * 任意長の8ビット列を与えて内部状態を差し戻す ``CRC.unshiftbytes`` を追加しました。

  * **[BUG FIX]** 入出力のビット送り方向が異なる場合、CRC.reset が不正な初期化を行っていた問題を修正


## crc-0.3.1.1 (平成28年11月10日 木曜日)

  * rbcrc において reflect-input/output が既定値となっていなかったため修正


## crc-0.3.1 (平成28年11月10日 木曜日)

  * メソッド名 CRC#update\_with\_slice\_by\_eight を CRC#update\_with\_slice\_by\_16 に変更
  * 非 reflect-input も slicing-by-16 となるように修正
  * CRC#update\_with\_slice\_by\_16 の 16 ビット以下の crc に対する最適化
  * crc 計算におけるルックアップテーブルの作成の高速化
  * 実装が C か ruby かを判別しやすくするための定数 CRC::IMPLEMENT を追加
  * CRC-64-JONES を追加
  * 特定の CRC を計算するソースコード出力機能を追加
      * c、ruby、javascript 向けのソースコードを出力するための機能を追加しました。
      * 今のところアルゴリズムは c を除き slicing-by-16 に固定となります。


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
