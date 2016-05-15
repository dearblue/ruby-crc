#!ruby

#--
# This part is based from http://stackoverflow.com/questions/29915764/generic-crc-8-16-32-64-combine-implementation
#
# > /* crccomb.c -- generalized combination of CRCs
# >  * Copyright (C) 2015 Mark Adler
# >  * Version 1.1  29 Apr 2015  Mark Adler
# >  */
# >
# > /*
# >   This software is provided 'as-is', without any express or implied
# >   warranty.  In no event will the author be held liable for any damages
# >   arising from the use of this software.
# >
# >   Permission is granted to anyone to use this software for any purpose,
# >   including commercial applications, and to alter it and redistribute it
# >   freely, subject to the following restrictions:
# >
# >   1. The origin of this software must not be misrepresented; you must not
# >      claim that you wrote the original software. If you use this software
# >      in a product, an acknowledgment in the product documentation would be
# >      appreciated but is not required.
# >   2. Altered source versions must be plainly marked as such, and must not be
# >      misrepresented as being the original software.
# >   3. This notice may not be removed or altered from any source distribution.
# >
# >   Mark Adler
# >   madler@alumni.caltech.edu
# >  */
#
# Ported by:: dearblue <dearblue@users.osdn.me>
# License:: zlib-style
#--

module CRC
  module Aux
    def self.gf2_matrix_times(matrix, vector)
      sum = 0
      matrix.each do |m|
        break unless vector > 0
        sum ^= m unless vector[0] == 0
        vector >>= 1
      end

      sum
    end

    def self.gf2_matrix_square(bitsize, square, matrix)
      bitsize.times do |n|
        square[n] = gf2_matrix_times(matrix, matrix[n])
      end

      nil
    end
  end

  class Generator
    def combine(crc1, crc2, len2)
      return crc1 unless len2 > 1

      crc1 ^= initial_state

      odd = []
      even = []
      if reflect_output
        odd << Utils.bitreflect(polynomial, bitsize)
        col = 1
        (bitsize - 1).times do
          odd << col
          col <<= 1
        end
      else
        col = 2
        (bitsize - 1).times do
          odd << col
          col <<= 1
        end
        odd << polynomial
      end

      Aux.gf2_matrix_square(bitsize, even, odd)
      Aux.gf2_matrix_square(bitsize, odd, even)

      while true
        Aux.gf2_matrix_square(bitsize, even, odd)
        if len2[0] == 1
          crc1 = Aux.gf2_matrix_times(even, crc1)
        end
        len2 >>= 1
        break unless len2 > 0

        Aux.gf2_matrix_square(bitsize, odd, even)
        if len2[0] == 1
          crc1 = Aux.gf2_matrix_times(odd, crc1)
        end
        len2 >>= 1;
        break unless len2 > 0
      end

      crc1 ^ crc2
    end
  end
end
