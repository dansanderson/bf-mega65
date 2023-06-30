10 bank 0:bload "bf65":sys $1800:end
20 ++       cell c0 = 2
30 > +++++  cell c1 = 5
40 [        start your loops with your cell pointer on the loop counter (c1 in our case)
50 < +      add 1 to c0
60 > -      subtract 1 from c1
70 ]        end your loops with the cell pointer on the loop counter
80 ++++ ++++  c1 = 8 and this will be our loop counter again
90 [
100 < +++ +++  add 6 to c0
110 > -        subtract 1 from c1
120 ]
130 < .        print out c0 which has the value 55 which translates to "7"
