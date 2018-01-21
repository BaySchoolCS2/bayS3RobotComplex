CON

_clkmode      = xtal1 + pll16x
_xinfreq      = 5_000_000

OBJ

  s2 : "s2"

PUB start
  s2.start_motors
  repeat
    waitcnt(clkfreq + cnt)
    waitpne(|< s2#BUTTON, |< s2#BUTTON,0)
