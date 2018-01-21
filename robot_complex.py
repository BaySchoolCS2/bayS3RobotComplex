##:::::::[ Python module for complex behaviors of Scribbler 3 ]:::::::::::::::::::::::::::::::::
## File:  robot_complex.py v 1.0
##
##    ┌────────────────────────────────────────────────┐
##    │     Bay School Python Module Derived by        │
##    │                Richard Piccioni                │
##    │                   from                         │
##    │        Scribbler II Kinematic GUI              │
##    │  (c) Copyright 2012 and 2013 Matt Greenwolfe   │
##    │      See end of file for terms of use.         │
##    └────────────────────────────────────────────────┘
##
##
## This python module contains functions needed
## to program complex behaviors of the Scribbler 2 and 3
## robots.

## Dependencies:
##      Parallax USB Drivers: 
##          download from: https://www.parallax.com/downloads/parallax-usb-driver-installer
##
##      Python 3.x:  See www.python.org for installation instructions
##                   Download 32-bit version
##                   During installation, add to PATH
##
##      Parallax propellent (sic) dynamic link library (Propellent.dll)
##          download from: http://www.parallax.com/PropellerDownloads
##
##      Propeller FloatMath.spin library
##          download from: http://www.parallax.com/PropellerDownloads
##
##      S2 spin object (s2.spin)
##
##      Place s2.spin, propellent.dll, and FloatMath.spin in
##      the same folder as this file.


##=======[ Introduction ]=========================================================

## This Python module provides the functions needed to specify a series of
## robot behaviors, write a spin program, and send that program to the robot
#
##::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

from __future__ import division, print_function
import os
import sys
import ctypes

commands = []
speed_limit = 18.00 # cm/s

print("eggs")

def append_move_distance_command(d, v0, v, a):
    if abs(v0) > speed_limit or abs(v) > speed_limit:
        print("Oops! Speed limit exceeded.")
        return    
    global commands # Note to CS students: Don't use global variables in complex programs.
                    # We are using one here to simplify the argument list that IDLE displays
                    # to physics students when they edit their code.
    commands += ["s2.move_distance_mms(" + str(d)+ ", " + str(v0) + ", " + str(a) + ")\n"]
    
def speed_up_to(final_speed, time_interval):
    """ Uniformly accelerate the robot from rest """
    v0 = 0.00
    d  = final_speed * time_interval / 2
    a  = final_speed/time_interval
    v  = final_speed
    append_move_distance_command(d, v0, v, a)
    
def move_forward(distance, time_interval):
    d  = distance
    v0 = distance / time_interval
    a  = 0.00
    v  = v0
    append_move_distance_command(d, v0, v, a)

def move_backward(distance, time_interval):
    d  = distance
    v0 = - distance / time_interval
    a  = 0.00
    v  = v0
    append_move_distance_command(d, v0, v, a)

def cruise_at(cruising_speed, time_interval):
    d  = cruising_speed * time_interval
    v0 = cruising_speed
    a  = 0.00
    v  = v0
    append_move_distance_command(d, v0, v, a)

def stop_from(initial_speed, time_interval):
    d  = initial_speed * time_interval/2
    v0 = initial_speed
    a  = -initial_speed/time_interval
    v = v0
    append_move_distance_command(d, v0, v, a)

def accel(initial_speed, acceleration, time_interval):
    v0 = initial_speed
    Dt = time_interval
    a  = acceleration
    d  = v0 + a * Dt * Dt / 2
    v  = v0 + a * Dt
    append_move_distance_command(d, v0, v, a)
    
def accelerate(initial_speed, final_speed, time_interval):
    v0 = initial_speed
    Dt = time_interval
    d  = time_interval * (initial_speed + final_speed)/2
    a  = (final_speed - initial_speed)/time_interval
    v  = v0 + a * Dt
    append_move_distance_command(d, v0, v, a)
    
def pause_for(time_interval):
    global commands
    commands += ["s2.run_motors_mms(0,0,0,0.00,0.00, " +
    str(int(time_interval*1000)) + ")\n"]

def turn_left(degrees_ccw):
    global commands
    commands += ["s2.turn_mms(" + str(degrees_ccw)+ ")\n"]

def send_command_list(list_name = commands):
    print("Writing spin file . . . ")
    spinfile = "complex_s2.spin"
    try:
        ctype_spinfile = ctypes.c_char_p(spinfile)
    except TypeError:
        ctype_spinfile = ctypes.c_char_p(spinfile.encode('utf-8'))
    spin_code = '''CON

_clkmode      = xtal1 + pll16x
_xinfreq      = 5_000_000

OBJ

  s2 : "s2"

PUB start
  s2.start_motors
  repeat
    waitcnt(clkfreq + cnt)
    waitpne(|< s2#BUTTON, |< s2#BUTTON,0)
'''    
    for command in commands:
        spin_code += ("    " + command)
    with open(spinfile,"w") as ms2:
        ms2.write(spin_code)
    ms2.close()
    path = os.path.abspath(os.path.dirname(sys.argv[0])) #points to curr working dir
    prop = ctypes.cdll.LoadLibrary(path + "\Propellent.dll")
    prop.InitPropellent(None)
    try:
        libdir = ctypes.c_char_p(os.path.realpath(path))
    except TypeError:
        libdir = ctypes.c_char_p(os.path.realpath(path).encode('utf-8'))
    prop.SetLibraryPath(libdir)
    prop.CompileSource(ctype_spinfile,True)
#    prop.DownloadToPropeller(0,1) #store in RAM only?
    prop.DownloadToPropeller(0,3)  #store in RAM and EEPROM
    prop.FinalizePropellent

# legacy translations
left = turn_left
forward = move_forward
    
##=======[ License ]===========================================================
##
##┌──────────────────────────────────────────────────────────────────────────────────────┐
##│                            TERMS OF USE: Software License                            │
##├──────────────────────────────────────────────────────────────────────────────────────┤
##│The purchase of one copy of S2mmsKinematicGUI and it's dependent files S2Curve.py,    │
##│S2graph.py, S2Segment.py, S2StatusBar.py, S2ToolBar.py, S2VecAdd.py and     s2mms.spin│
##│entitles you to install it on every computer in your school or, for                   │
##│post-secondary institutions, department. Installation to local machines over a network│
##│is allowed. Purchasers are also permitted to distribute these programs to their       │
##│students and instructors for home use. The license is limited to a single campus if   │
##│your institution has multiple campuses.                                               │
##│                                                                                      │
##│The above copyright notice and this permission notice shall be included in all copies │
##│or substantial portions of the Software.                                              │
##│                                                                                      │
##│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,   │
##│INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A         │
##│PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT    │
##│HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF  │
##│CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE  │
##│OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                         │
##└──────────────────────────────────────────────────────────────────────────────────────┘
##
