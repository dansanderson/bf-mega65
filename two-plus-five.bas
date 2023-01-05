10 bank 0:bload "bf65":sys $1800:print peek($8800):end
20 rem this program adds 2 and 5. see $8800 for the answer.
30 ++           set c0 to 2
40 > +++++      set c1 to 5
50 [ < + > - ]  loop: adding 1 to c0 and subtracting 1 from c1 until c1 is 0
