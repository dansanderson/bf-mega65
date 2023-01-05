10 bank 0:bload "bf65":sys $1800:end
20 ++       Cell c0 = 2
30 > +++++  Cell c1 = 5
40 [        Start your loops with your cell pointer on the loop counter (c1 in our case)
50 < +      Add 1 to c0
60 > -      Subtract 1 from c1
70 ]        End your loops with the cell pointer on the loop counter
80 ++++ ++++  c1 = 8 and this will be our loop counter again
90 [
100 < +++ +++  Add 6 to c0
110 > -        Subtract 1 from c1
120 ]
130 < .        Print out c0 which has the value 55 which translates to "7"
