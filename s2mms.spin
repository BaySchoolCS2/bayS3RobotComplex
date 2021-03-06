'':::::::[ Motor Driver for the Scribbler 2 ]::::::::::::::::::::::::::::::::: 
{{File:  s2mms.spin


┌───────────────────────────────────────┐
│       Scribbler s2mms motor drive     │
│(c) Copyright 2012 Matt Greenwolfe     │
│   See end of file for terms of use.   │
└───────────────────────────────────────┘
This object provides both high and low level
methods to drive the scribbler 2 robot
accurately in units of mm/s.

Version History
───────────────

2012.06.21: Work started on beta version
2012.06.28: Working motor driver, producing smooth acceleration and constant velocity
2012.07   : Added higher level driver move_timed             
2012.07.20: Improved PID algorithm
2012.07.30: Working on stop conditions (time and distance) and immediate mode
2012.08.07:  Time and Distance stop conditions working, no immediate mode yet
}}

{{=======[ Introduction ]=========================================================

s2mms.spin provides low-level motor drivers for the S2 Robot as well as
top-level access functions to interface with those drivers. The motor driver is
written in assembly, strongly based on Phil Pilgrim's excellent original
motor driver for the scribbler, and runs in a single cog.

All motor driver spin functions include the text "_mms" in the name to distinguish
them from the original s2 spin functions.  Once work is complete, an attempt will be
made to write a wrapper using the new motor driver to mimic the behavior of the
origional s2 motor driver so that this can be incorporated into the whole s2 object
and provide new functionality while maintaining compatibility with the original. 

}}


''=======[ Constants... ]=========================================================

CON

  ''-[ Version, etc. ]-
  {{ Version numbers and miscellaneous other constants. }}

  VERSION         = "ß"                   'Major version ID.
  SUBVERSION      = "A"                 'Minor version ID.


  ''-[ Propeller pins ]-
  {{ Port names for pins A0 through A31. }}

  P0              =  0          'Hacker ports 0 - 5.
  P1              =  1
  P2              =  2
  P3              =  3
  P4              =  4
  P5              =  5  
  OBS_TX_LEFT     =  6          'Output to left obstacle IRED.
  LED_DATA        =  7          'Output to LED shift register data pin.
  LED_CLK         =  8          'Output to LED shift register clock pin.
  MIC_ADC_OUT     =  9          'Output (feedback) for microphone sigma-delta ADC.
  MIC_ADC_IN      = 10          'Input for microphone sigma-delta ADC.
  BUTTON          = 11          'Input for pushbutton.
  IDLER_TX        = 12          'Output to idler wheel encoder IRED.
  MOT_LEFT_ENC    = 13          'Input from left motor encoder.
  MOT_RIGHT_ENC   = 14          'Input from right motor encoder.
  OBS_TX_RIGHT    = 15          'Output to right obstacle IRED.
  MOT_LEFT_DIR    = 16          'Output to left motor controller direction pin.
  MOT_RIGHT_DIR   = 17          'Output to right motor controller direction pin.
  MOT_LEFT_PWM    = 18          'Output to left motor controller PWM pin.
  MOT_RIGHT_PWM   = 19          'Output to right motor controller PWM pin.
  OBS_RX          = 20          'Input from obstacle detector IR receiver.
  SPEAKER         = 21          'Output to speaker amplifier.
  MUX0            = 22          'Outputs to analog multiplexer address pins.
  MUX1            = 23
  MUX2            = 24
  MUX3            = 25
  _MUX_ADC_OUT    = 26          'Output (feedback) from main sigma-delta ADC.
  _MUX_ADC_IN     = 27          'Input to main sigma-delta ADC.
  SCL             = 28          'Output clock to EEPROMs.
  SDA             = 29          'Input/Output data from/to EEPROMs.
  TX              = 30          'Output to RS232.
  RX              = 31          'Input from RS232.

  ''-[ Motor constants ]-
  {{ Command, status bits, and indices into the motor debug array. }}

  'Command bits:

  MOT_IMM         = %00001      'Sets immediate (preemptive) mode for motor command.   in original s2 object
  MOT_DIST        = %00010      'Use total distance traveled as condition to stop motor command
                                'if not set, s2 running in what the original s2 object called continuous mode 
  'MOT_CONT        = %00010      'Sets continuous (non-distance) mode for motor command.   in original s2 object
                                 'run_motors, move, move_now, assembly once
  MOT_TIMED       = %00100      'Use time as condition to stop motor command  in original s2 object
                                '  used twice in assembly, never in spin 
  MOT_VEL         = %01000      'Use final velocity as condition to stop motor command (NOT YET IMPLEMENTED)
  MOT_WHEELS_OPP  = %10000      'When set, wheels will spin in opposite directions

  'Status bits:

  MOT_RUNNING     = %01
  MOT_STOPPED     = %00

  'motor constants
  FULL_CIRCLE   = 1910         '(153mm*pi)/(.244mm/count) = 1970      (was 1910)

''=======[ Public Spin methods... ]===============================================
''
''-------[ Start and stop methods... ]--------------------------------------------
''
'' Start and stop methods are used for starting individual cogs or stopping all
'' of them at once.

OBJ
  fMath   : "FloatMath"
  
PUB start_motors

  {{ This method starts the motor control cog. It must be called before any
     of the drawing and motor control methods are used. 
  ''
  '' `Example: s2.start_motors
  ''
  ''     Start the motor controller.
  }}

  ifnot (Motor_cog)
    Motor_cmd~~      'set Motor_cmd to be non-zero
    result := (Motor_cog := cognew(@motor_driver, @Motor_cmd) + 1) > 0
    repeat while Motor_cmd      'Wait until motor_driver sets motor_cmd to zero, signalling readiness for an actual command

PUB turn_mms(ccw_degrees) | d, v, a, ccw_counts
  {{ Turn in place counter-clockwise by the indicated number of degrees.
     Negative values will turn clockwise.
''  ******* All variables are floats ********
''  ******* Integer values must be passed in as 22.0 rather than 22 in order to be recognized as floats ******
  ''
  ''     `ccw_degrees: Number of counterclockwise degrees to turn.
  ''
  '' `Example: s2.turn_deg(-90.0)
  ''
  ''     Turn right.
  }}
  ccw_counts :=  fMath.FRound(fMath.Fdiv(fMath.Fmul(fMath.FFloat(FULL_CIRCLE),ccw_degrees),360.0))
  d := ||ccw_counts
  v := 100
  a := 1250
  if d > 32
    v := 200
  if (ccw_counts & $8000_0000)
    v := -v
    a := -a
  if d > 50
    run_motors_mms(MOT_WHEELS_OPP | MOT_DIST,16,16,0,a,0)
    run_motors_mms(MOT_WHEELS_OPP | MOT_DIST,d-32,d-32,v,0,0)
    run_motors_mms(MOT_WHEELS_OPP | MOT_DIST,16,16,v,-a,0)
  else
    run_motors_mms(MOT_WHEELS_OPP | MOT_DIST,d,d,v,0,0)


PUB move_distance_mms(d,v0,acc)
{{  This method will run the S2 straight forwards and/or backwards for the indicated distance with the indicated
''  acceleration.
''  ******* All variables are floats ********
''  ******* Integer values must be passed in as 22.0 rather than 22 in order to be recognized as floats ******
''  d = distance (0 < d < 160 cm)
''  v0 = initial velocity    (-20 < v0 < 20cm/s)   
''  acc = acceleration    (nominal:  +/-2.5cm/s² , but can be up to 50 times greater)  
}}
  d := fMath.FRound(fMath.FMul(d,40.8413))    '1cm*(10mm/cm)*(1count/.249mm)= 1cm*(40.1606counts/cm)
                                              'checking .2449mm 7-23-13   = 40.8413counts/cm
  v0 := fMath.FRound(fMath.FMul(v0,40.8413))     'new value
  acc := fMath.FRound(fMath.FMul(acc,40.8413))   'new value
  run_motors_mms(MOT_DIST,d,d,v0,acc,0) 

PUB move_timed_mms(v0,acc,time) | distance, vf, vbar
{{ This method will run the S2 straight forwards and/or backwards for the indicated time with the indicated acceleration
''  ******* All variables are floats ********
''  ******* Integer values must be passed in as 22.0 rather than 22 in order to be recognized as floats ******
''  v0 = initial velocity    (-20 < v0 < 20cm/s)   
''  acc = acceleration    (nominal:  +/-2.5cm/s² , but can be up to 50 times greater)                                     
''  time = time          (0< time < 65.535 s) }}

'  vf := fMath.FAdd( v0 , fMath.fMul(acc,time) )
'  if v0 and vf and( (v0 & $8000_0000)^(vf & $8000_0000) ) 'if v0 and vf are both non-zero and have opposite signs 
'    distance := fMath.FDiv(fMath.FAdd(fMath.FMul(v0,v0),fMath.FMul(vf,vf)),acc)
'    distance := fMath.FRound(fMath.FMul(distance,40.8413))    'testing new value 7-23-13 ... see above
'    ||distance
'    distance >>= 1
'  else
'    vbar := fMath.FDiv(fMath.FAdd(v0, vf) ,2.0)
'    distance := fMath.FMul(vbar, time)
'    distance := fMath.FRound(fMath.FMul(distance,40.8413)) '1cm*(10mm/cm)*(1count/.244mm)= 1cm*(40.9836counts/cm)
                                                            'original manufacturers value???
'    ||distance
  v0 := fMath.FRound(fMath.FMul(v0,40.8413))  '1cm*(10mm/cm)*(1count/.244mm)= 1cm*(40.9836counts/cm)
  acc := fMath.FRound(fMath.FMul(acc,40.8413))
'  vf := fMath.FRound(fMath.FMul(vf,40.8413))
'  ||vf
'  vf >>= 3
  time := fMath.FRound(fMath.FMul(time,1000.0)) 'convert to ms
'  time *= 15
'  time /= 10                                  'providing precise distance, so turn into timeout rather than precise time 
  run_motors_mms(0,0,0,v0,acc,time)
    
  

PUB run_motors_mms(command,left_distance,right_distance,v0,acc,timeout)  

  {{ Base level motor activation routine. Normally, this method is not called by the user but is called by the
     many convenience methods available to the user.
  ''
  ''     `command: the OR of any of the following:
  ''
  ''        `MOT_IMM:   Commanded motion starts immediately, without waiting for prior motion to finish.
  ''        `MOT_DIST:  Total distance traveled (counts) will be used as a condition to stop the commanded motion
  ''                     This is not changein position.  
  ''                     Distance covered means literally distance covered, even if direction changes
  ''        'MOT_VEL:   Final velocity reached (signed) will be used as a condition to stop the commanded motion
  ''                    NOT YET IMPLEMENTED                     
  ''        `MOT_WHEELS_OPP:  Wheels spin in opposite directions   
  ''         
  ''     `timeout (0 - 65535): If non-zero, time limit (ms) will be used as a condition to stop the commanded motion
  ''
  ''     `left_distance, `right_distance (0 to 65535): The distances (in encoder counts) to be covered by the 
  ''         left and right wheels, respectively.  (approx .244mm per count)
  ''         The "dominant wheel" is defined to be the one that will travel the greater distance
  ''         In case of a tie, the right wheel is dominant by default, so that the default rotation direction is CCW.
  ''         If these distances are 0 and MOT_DIST = 1, no motion will result
  ''         If they are 0 and MOT_DIST = 0, then the s2 will move straight ahead according to v0 and acc for the
  ''         timeout period.  This includes stopping for the timeout period if v0 = acc = 0
  ''
  ''     'V0 (-800 -> +800): Initial speed (counts/sec) and direction of dominant wheel
  ''           
  ''     'acc (-5000 - 5000):  acceleration (counts/sec²) of dominant wheel
  ''           If v0 = 0, the sign of acc sets the direction of the dominant wheel.
  ''
  ''
  '' There are three possible stop conditions, time, distance and velocity (not yet implemented).  If more than one
  '' is specified, the commanded motion will stop when the first condition is achieved.
  ''
  ''  If v0 and acc have opposite signs, the wheels slow down until one of the specified stop conditions is reached.
  ''  If the wheel speed reaches zero before any stop conditionsares reached, directions are reversed and
  ''  motion continues by speeding up in the opposite direction.
  ''
  ''  If maximum speed is reached during acceleration, motion continues at constant speed until a distance or time
  ''  limit is reached.  I INTEND TO HAVE AN ERROR THROWN INTO THE STATUS LONG.  NOT DONE YET.
  ''  
  '' `Example: s2.run_motors(s2#MOT_DIST, 1000, 1000, 0, 50, 0)
  ''
  ''     Travel a distance of 1000 counts (≈ 24.7cm), starting from rest and accelerating at 50counts/sec² (≈ 1.2cm/s²).
  ''
  '' `Example: s2.run_motors(s2#MOT_DIST | S2#MOT_WHEELS_OPP, 1000, 1000, -400, 0, 5000)
  ''
  ''     Turn in place clockwise for at a constant speed of 400counts/sec (≈ 9.9cm/s), until the right wheel has
  ''     traveled 1000 counts or until 5 seconds have passed, whichever occurs first.
  }}
   
  repeat while long[@Motor_cmd]     'wait until any previous command has cleared
  Motor_Ldist := 0 #> left_distance <# 65535 
  Motor_Rdist := 0 #> right_distance <# 65535 
  Motor_v0 := -800 #> v0 <# 800 'confirm max velocity                      
  Motor_acc := -5000 #> acc <# 5000 'adjust as necessary
  long[@Motor_cmd] := (0 #> timeout <# 65535) << 16 | command 'send it all at once to signal start
  if command  or v0 or acc
    timeout := cnt
    repeat until Motor_cmd == 0 or cnt - timeout > 800_000

PUB get_debug_mms(index)
  return motor_stat[index]

''=======[ Assembly Cogs... ]==================================================
DAT

              org       0
motor_driver  mov       dira,mdira0             'Set dir and pwm pins to output.
              mov       frqa,#1                 'Initialize PWM counter frequencies.
              mov       frqb,#1
              mov       dist_addr,par           'Get the hub address of L&R changes in position
              add       dist_addr,#4
              mov       va_addr, par            'Get the hub address of the initial speed and acceleration
              add       va_addr, #8
              mov       stat_addr,par           'Get the status address.
              add       stat_addr,#12
              test      right_enc_bit,ina wc    'Get right encoder input.
              rcl       Renc_shift,#1            'Shift it into register.
              test      left_enc_bit,ina wc     'Same for left encoder.
              rcl       Lenc_shift,#1
              mov       nominal_pwm,#0          'Zero the current PWM value.
              wrlong    _zero,par               'Tell caller we're ready for a command.

:main_lp      rdlong    mcmd,par wz             'Is there a command waiting?
       if_nz  jmp       #:do_cmd                '  Yes: Go do it.

:stop         mov       ctra,#0                 '  No:  Force stop. Turn off PWMs.
              mov       ctrb,#0
              
:chk_cmd      rdlong    mcmd,par wz             'Get the next command. Is it non-zero?
        if_z  jmp       #:chk_cmd               '  No:  Try again.

:do_cmd       mov       t,mcmd                  'Get and isolate time (in ms) for this segment of motion.
              shr       t,#16   wz              'Is it non-zero? 
        if_nz muxnz     mcmd,#MOT_TIMED         'Set timeout flag according to motor_timer <> 0           
              mov       X, #0
              muxnz     X, #%001
              rdlong    Rdist_c, dist_addr wz   'Get changes in position
              muxnz     X, #%010
              mov       Ldist_c, Rdist_c        'Left distance is upper 16 bits, signed, 
                                                '   move into place while waiting for Hub
              rdlong    V0_cps, va_addr   wz   'Get initial speed and acceleration
              muxnz     X, #%100 wz             'z = 1 => both distances = 0, v0 = acc = 0, and t = 0  
              mov       acc_cpsq, V0_cps        'acc is upper 16 bits signed
              wrlong    _zero, par              'Got everything, so signal caller            
        if_z  jmp       #:stop                  'if all zero, nothing to do
              mov         X, t                   'multiply t by 20     (harmless if t = 0 and time is not stop condition)
              shl         X, #2                  'to convert from ms to pulses
              add         t, X                  't + 4t
              shl         t, #2                 '*4, now is countdown timer
              and       mcmd, #$ff               'isolate command bits
              shr       Ldist_c, #16             'isolate distances (counts, unsigned)
              min       Ldist_c, #1              'need at least 1 count in here for wheel proportionality to work
              and       Rdist_c, _ffff
              min       Rdist_c, #1
              sar       acc_cpsq, #16            'isolate acceleration (c/s², signed)
              shl       V0_cps, #16              'isolate initial velocity (c/s, signed)
              sar       V0_cps, #16

              cmps      v0_cps, #0 wc, wz       'c = 1 => v0 is negative
        if_nz muxnc     outa, both_dir_bits     'not sure yet which is dominant, doesn't matter unless WHEELS_OPP
        if_z  cmps      acc_cpsq, #0 wc         'c = 1 => acc is negative
        if_z  muxnc     outa, both_dir_bits     'accel determines direction if v0 = 0

              test      mcmd, #MOT_WHEELS_OPP wc 'c = 1 => wheels go in opposite directions  
        if_nc jmp       #:dir_set                
              cmp       Rdist_c,Ldist_c wc      'c = 1 => L dominant, else R dominant.
        if_c  test      outa, right_dir_bit wz   'z set opposite of bit
        if_c  muxz      outa, right_dir_bit      'reverse direction of non-dominant wheel
        if_nc test      outa, left_dir_bit wz
        if_nc muxz      outa, left_dir_bit

:dir_set      cmp       Rdist_c,Ldist_c wc      'c = 1 => L dominant, else R dominant.
        if_c  mov       nDdist_c, Rdist_c        'store non-dominant wheel distance
        if_nc mov       nDdist_c, Ldist_c    
              abs       v0_cps, v0_cps wc, wz   'c = 1 if v0 was negative
        if_c  neg       acc_cpsq, acc_cpsq      'if v0 was negative, reverse sign of a to retain relative sign
        if_z  abs       acc_cpsq, acc_cpsq      'if v0 = 0, dir already set from sign of a, so make it + to speed up

              call      #put_debug             'TEMP FOR DEBUGGING       
'              jmp       #:chk_cmd               'TEMP FOR DEBUGGING              
                       
              mov       X, Rdist_c             'set up wheel proportionality   
              mov       Y, Ldist_c
              call      #umult
              mov       Rcount, X
              mov       Lcount, X
              mov       Phcount, X
            
              mov       phsa,#0                 'Kill the PWM.
              mov       phsb,#0
              mov       ctra,mctra0             'Initialize PWM counters.
              mov       ctrb,mctrb0
              mov       ptmr_cl,cnt              'Initialize pulse timer.
              add       ptmr_cl,_4K            
              mov       PWMtmr_P, #400           'countdown timer, 400 pulses = 20ms between modulation of pulse widths
              mov       bump,    #0              'initialize dropped and bumped pulse counters for first PID interval
              mov       drop,    #0
              mov       X, V0_cps              'counts per second = counts per 20000 pulses = 1 Wc/P
              call      #M20K
              mov       PhV_zcpp, X             'velocity of phantom wheel (in Zc/P)
              mov       PhD_zc, #0              'initialize phantom distance counter

:pulse_lp                                       'stuff that needs to be done each pulse, including prior to the first pulse,
                                                'stats timer and initialization stuff goes here
:go                                             'tests for immediate command and timeout

                                                
'------------------------------------------ check encoders and bump, drop or reverse direction  ----------
              
:cont_ok      test      right_enc_bit,ina wc    'Get right encoder input.
              rcl       Renc_shift,#1           'Shift it into register.
              test      Renc_shift,#%11 wc      'Test last two bits.
        if_c  cmpsub    Rcount, Ldist_c wz      'If Rcount > Ldist, then subtract a count
  if_c_and_z  mov       X, #MOT_DIST
  if_c_and_z  testn     X,mcmd wz               'result = 0 if mcmd dist bit = 1 => z = 1
  if_c_and_z  mov       ctra,#0                 'If counter is zero, done with this motor. Kill output.
  
              test      left_enc_bit,ina wc     'Same for left encoder.
              rcl       Lenc_shift,#1
              test      Lenc_shift,#%11 wc
        if_c  cmpsub    Lcount, Rdist_c wz
  if_c_and_z  mov       X, #MOT_DIST
  if_c_and_z  testn     X,mcmd wz               'result = 0 if mcmd dist bit = 1 => z = 1  
  if_c_and_z  mov       ctrb,#0                  

              mov       X, PhV_zcpp             'velocity of phantom wheel at beginning of pulse
              adds      X, acc_cpsq             'counts/s² = Zc/P², and a*1pulse = ΔV (in Zc/P)
              maxs      X, maxv_zcpp            'limit top speed  WRITE ERROR FLAG TO STATS???
              mins      X, #0                   'stop phantom wheel if speed slows down to zero (prepare to reverse dir)        
              mov       PhVnew_zcpp, X          'velocity at end of pulse (Zc/P)          
              add       X, PhV_zcpp             
              shr       X, #1                   'average velocity, & avgV*1pulse = distance traveled in that pulse (Zc)
              add       PhD_zc, X               'update distance traveled since last phantom encoder count
              cmpsub    PhD_zc, _400M wc        'when PhD > 1 count, subtract 1c and reset PhD to the remainder
        if_c  cmpsub    Phcount, nDdist_c       'Decrement phantom distance countdown
              cmp       PhV_zcpp, #0 wz         'z = 0 => PhV_zcpp is positive
        if_nz cmp       PhVnew_zcpp, #0  wz
              mov       PhV_zcpp, PhVnew_zcpp   'becomes velocity at beginning of next pulse

              cmp       PhVnew_ZCPP, #0 wz      'if phantom wheel stopped                                                
        if_nz jmp       #:bump_drop
              test      outa, right_dir_bit wz  'reverse wheels
              muxz      outa, right_dir_bit
              test      outa, left_dir_bit wz
              muxz      outa, left_dir_bit
              abs       acc_cpsq, acc_cpsq      'make the acceleration positive to restart the phantom wheel

:bump_drop    mov       right_pwm,nominal_pwm   'Initialize both PWMs to nominal value,
              mov       left_pwm,nominal_pwm  
              cmp       Rdist_c, Ldist_c wc     'c = 1 implies L dominant, else R dominant
        if_nc jmp       #:right_dom
:left_dom     cmp       Phcount,Lcount wc, wz   'see comments for right_dom
        if_c  mov       left_pwm,_4K           
        if_c  add       bump, #1                
if_nc_and_nz  mov       left_pwm,#0             
if_nc_and_nz  add       drop, #1                
              cmp       Lcount,Rcount wc, wz 
        if_c  mov       right_pwm,_4K           
if_nc_and_nz  mov       right_pwm,#0 
              jmp       #:check_time
:right_dom    cmp       Phcount,Rcount wc, wz   'Ph < R => R is behind, since counting down
        if_c  mov       right_pwm,_4K           'if R is behind, speed it up by setting next pulse at 100%
        if_c  add       bump, #1                'count bump for PID
if_nc_and_nz  mov       right_pwm,#0            'if R is ahead, stop it for the next pulse
if_nc_and_nz  add       drop, #1                'count drop for PID
              cmp       Rcount,Lcount wc, wz    'R < L => L is behind, since counting down
        if_c  mov       left_pwm,_4K            '  bump left wheel if its behind
if_nc_and_nz  mov       left_pwm,#0             '  drop if ahead, thus coordinating the two wheels            
              
:check_time   test      mcmd,#MOT_TIMED wz       'z = 1 => not using time as a stop condition
        if_z  jmp       #:check_cont             'if not using time as a stop condition, skip to distance
              sub       t, #1                    'decrement another pulse from countdown timer
              tjz       t, #:stop                'stop when time counts down to zero
:check_cont   test      mcmd, #MOT_DIST wz       'z = 1 => not using distance as a stop condition
        if_nz jmp       #:check_dist
              cmp       Rcount,top_dist wc,wz'Yes: Can right, left, and phantom counts be augmented?
   if_z_or_c  cmp       Lcount,top_dist wc,wz
   if_z_or_c  cmp       Phcount, top_dist wc, wz
   if_z_or_c  add       Rcount,top_dist    '         Yes: Augment all the same.
   if_z_or_c  add       Lcount,top_dist
   if_z_or_c  add       Phcount, top_dist
              jmp       #:wait_pulse
:check_dist   or        Rcount,Lcount nr,wz      'Are both counters now zero?
        if_z  jmp       #:main_lp                '      Yes: Target reached; we're done. (Already stopped individually.)
  
:wait_pulse   waitcnt   ptmr_cl,_4K            'wait for next pulse
              neg       phsa,right_pwm          'Put PWM widths into each counter.
              neg       phsb,left_pwm               'stuff here is done each pulse, but only after 1st pulse

'-------------------------------- PID ---------------------------------------------------------'
              djnz      PWMtmr_P, #:pulse_lp    'not yet time to adjust PWM, back for another pulse
              mov       pwm_temp, nominal_pwm  'just for debug
              cmp       drop, bump wc           'c = 1 => drop < bump
              mov       X, drop
              add       X, bump
              sumnc     nominal_pwm, X           'add if drop < bump, else subtract
              mov       pwm_temp2,nominal_pwm    'just for debug

:anticipate   mov       X, acc_cpsq             'acc*.02s = Δv(counts/sec)*4000/800cps = Δv*5 = acc/10 ≈ acc/8 
              sar       X, #3                   'linear approximation 0 < PWM < 4000 produces 0 < v < 800cps (≈20cm/s)
              add       nominal_pwm, X
              mins      nominal_pwm,#0
              maxs      nominal_pwm,_4K
              
              call      #put_debug              'Send debug data to hub.
              mov       PWMtmr_P, #400             'initialize time and distance counters for next PID interval
              mov       bump,    #0              'initialize dropped and bumped pulse counters for next PID interval
              mov       drop,    #0
              jmp       #:pulse_lp              'continue with stuff that needs to be done each pulse, including prior
                                                'to first pulse
                                               


'-------[ Write debug info to hub. ]-------------------------------------------

put_debug     mov       Y,stat_addr
              wrlong    acc_cpsq,Y
              add       Y,#4
              wrlong    PhV_zcpp, Y
              add       Y, #4              
              wrlong    t,Y
              add       Y,#4
              
              wrlong    bump,Y
              add       Y,#4
              wrlong    drop,Y  
              add       Y,#4
              
              wrlong    pwm_temp,Y
              add       Y,#4
              wrlong    pwm_temp2,Y
              add       Y,#4
              wrlong    nominal_pwm,Y
'              add       Y,#4
'              wrlong    dira,Y
put_debug_ret ret

'-------[ Unsigned 16 x 16 = 32 Multiply ]-------------------------------------

' X[31..0] = Y[15..0] x X[15..0]

umult         shl       Y,#16                   'Get multiplicand into acc[31..16].
              mov       I,#16                   'Ready for 16 multiplier bits.
              shr       X,#1 wc                 'Get initial multiplier bit into C.
:loop   if_c  add       X,Y wc                  'If C set, add multiplicand into product.
              rcr       X,#1 wc                 'Get next multiplier bit into C, shift product.
              djnz      I,#:loop                'Loop until done.
umult_ret     ret                               'Return with product in acc[31..0].

' Divide x[31..0] by y[15..0] (y[16] must be 0)  unsigned??
' on exit, quotient is in x[15..0] and remainder is in x[31..16]
' From:  Programming the Parallax Propeller using machine langauge by deSilva
'
udiv          shl       Y,#15         'get divisor into y[30..15]
              mov       I,#16         'ready for 16 quotient bits
:loop         cmpsub    X,Y wc        'if y =< x then subtract it, set C
              rcl       X,#1          'rotate c into quotient, shift dividend
              djnz      I,#:loop      'loop until done           
udiv_ret      ret                      'quotient in x[15..0], rem. no longer in x[31..16]

'-------[ Unsigned Multiply X (< ??) by 20_000 = 2^5*625 = 2^5* %0010 0111 0001 ]-------------------------------------
'-------[                                                = 2^5*(%0011 0001 0001 - %0000 0001 0000]--------------------


M20K           mov      Y, X
               shl      Y, #4
               sub      X, Y
               shl      Y, #3
               add      X, Y
               shl      Y, #2
               add      X, Y
               shl      X, #5
M20K_ret       ret

'-------[ Constants and Initialized Variables ]--------------------------------  

right_dir_bit long      1 << MOT_RIGHT_DIR
left_dir_bit  long      1 << MOT_LEFT_DIR
both_dir_bits long      1 << MOT_RIGHT_DIR | 1 << MOT_LEFT_DIR 
right_enc_bit long      1 << MOT_RIGHT_ENC
left_enc_bit  long      1 << MOT_LEFT_ENC
mdira0        long      1 << MOT_RIGHT_PWM | 1 << MOT_LEFT_PWM | 1 << MOT_RIGHT_DIR | 1 << MOT_LEFT_DIR
mctra0        long      %00100 << 26 | MOT_RIGHT_PWM
mctrb0        long      %00100 << 26 | MOT_LEFT_PWM
top_dist      long      $ffff
_zero         long      0
_ffff         long      $ffff               
_1K           long      1000
_2K           long      2000
_4K           long      4000
_20K          long      20_000
maxv_zcpp     long      16_000_000       '800c/s = 800wc/p and 800wc/p*20000zc/wc = 16Mzc/p (about 29.8cm/s)
_400M         long      400_000_000

'-------[ Variables ]---------------------------------------------------------- 

'ADDRESSES of HUB VARIABLES      par:  timeout[31..16] (ms),Vend[15..8](counts/eighth-sec, unsigned),command word[7..0]
dist_addr     res       1       'par + 4: Motor_Ldist[31..16],Motor_Rdist[15..0] (counts, unsigned) 
va_addr       res       1       'par + 8: accel[31..16] (counts/sec², signed), V0[15..0] (c/s, signed) 
stat_addr     res       1       'par + 12:  Hub address of status and debug registers.
mcmd          res       1       'command word
RmpDwn_speed  res       1       'end speed for ramp down (counts/sec, unsigned)
t             res       1       'countdown timeout for a single segment of constant acceleration motion  (pulses) 
Ldist_c       res       1       'left travel distance  (in encoder counts)
Rdist_c       res       1       'right travel distance  (in encoder counts)                                
V0_cps        res       1       'dominant wheel initial speed   0< V0 < 800cps (verify upper limit exactly)
acc_cpsq      res       1       'acceleration of dominant motor (in encoder counts per square second)
                                ' nominal range -200 < acc < 200cpsq, but can be many times that for very short periods                                
mot_stat      res       1       'Mirror of status long in hub.

nDdist_c      res       1       'non-dominant wheel travel distance (in counts)
Lcount        res       1       'Counts down left travel distance  (in encoder counts*Rdist)
Rcount        res       1       'Counts down right travel distance  (in encoder counts*Ldist)
Phcount       res       1       'counts down phantom travel distance (in counts*nDdist)

X             res       1       'General-purpose accumulator.       
Y             res       1       'General-purpose accumulator extension.
I             res       1       'General-purpose counter            

Renc_shift    res       1       'Shift register for right encoder.
Lenc_shift    res       1       'Shift register for left encoder.

bump          res       1       'number of pulses bumped to full pwm
drop          res       1       'number of pulses dropped to 0 to synchronize with phantom wheel       

PhV_zcpp      res       1       'velocity of phantom wheel at beginning current pulse (in 20000² counts per pulse)
PhVnew_zcpp   res       1       'phantom velocity at end of current pulse   (in 20000² counts per pulse)
PhD_zc        res       1       'distance traveled since last phantom encoder count (in 20000² counts)
PhStop        res       1       'PhStop = %10 = 2 => phantom wheel just stopped

ptmr_cl       res       1       'pulse countup timer (in clocks) 
PWMtmr_P      res       1       'Set to 400 pulses and counts down until next modulation of pulse width DIDN'T I RENAME?
nominal_pwm   res       1       'Nominal PWM value for dominant wheel.
pwm_temp      res       1
pwm_temp2     res       1
right_pwm     res       1       'nominal pwm, or _4K (for 100% if bumped), or 0  (if dropped)
left_pwm      res       1       

              fit
''=======[ Hub variables ]=====================================================

{{These are the global variables used by the various methods.}}

Motor_cmd     word      0                       ' ┐    2nd byte is ramp down speed (counts/eighth-second)
Motor_time    word      0                       ' │    (ms)
Motor_Rdist   word      0                       ' ├─ Must begin on a long boundary      (counts)
Motor_Ldist   word      0                       ' │  and be contiguous in this order.
Motor_v0      word      0                       ' │                                     (counts/sec)
Motor_acc     word      0                       ' │                                     (counts/sec²)
Motor_stat    long      0[7]                    ' ┘  one word for stats, rest for debug info

Motor_cog     byte      0 

''=======[ License ]===========================================================
{{{
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                            TERMS OF USE: Software License                            │                                                            
├──────────────────────────────────────────────────────────────────────────────────────┤
│The purchase of one copy of VvsT_GUI.py, PvsT_GUI.py, AvsT_GUI.py, VectorAdd_GUI.py or│
│s2mms.spin entitles you to install it on every computer in your school or, for        │
│post-secondary institutions, department. Installation to local machines over a network│
│is allowed. Purchasers are also permitted to distribute these programs to their       │
│students and instructors for home use. The license is limited to a single campus if   │
│your institution has multiple campuses.                                               │   
│                                                                                      │
│The above copyright notice and this permission notice shall be included in all copies │
│or substantial portions of the Software.                                              │
│                                                                                      │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,   │
│INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A         │
│PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT    │
│HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF  │
│CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE  │
│OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                         │
└──────────────────────────────────────────────────────────────────────────────────────┘
}}