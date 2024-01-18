.globl is_leap_year

is_leap_year:
        rem $t0, $a0, 4
        beqz $t0, divisible_by_four

        li $v0, 0
        jr $ra

divisible_by_four:
        rem $t0, $a0, 100
        beqz $t0, divisible_by_hundred

        li $v0, 1
        jr $ra

divisible_by_hundred:
        rem $t0, $a0, 400
        beqz $t0, divisible_by_four_hundred

        li $v0, 0
        jr $ra

divisible_by_four_hundred:
        li $v0, 1
        jr $ra