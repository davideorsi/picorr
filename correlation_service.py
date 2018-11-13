#!/usr/bin/python3
import multitau_arduino 
import threading
from time import sleep
from time import perf_counter as time
from math import log,floor,ceil
from mat4py import savemat
#import matplotlib.pyplot as plt
from struct import unpack
import serial
import serial.tools.list_ports
import sys
from shutil import copyfile
from datetime import datetime
from numpy import mean
import signal

print('Warning! Max 50000 photons/sec!')

clock=42.0e6; # Arduino Due clock speed
bunchsize=2048; #How many bytes coming each time from the serial port
photons_to_correlate=2048;
crossover=0.001; #where to collate the fast and slow correlators

duration=60;

Narg=len(sys.argv);
Str_arg=sys.argv;

if Narg==2:
        duration=float(Str_arg[1]);

#finding the COM port
#ports=serial.tools.list_ports.comports();
#COMport=[];
#for port in ports:
#        portstr=str(port);
#        if portstr.find('Serial')>=0:
#                COMport=portstr[0:4];

#if not(COMport):
#        raise ValueError('Arduino Due not connected / not found')
COMport="/dev/ttyUSB0";

#initializing correlators
number_of_buffers=12;
number_of_levels=floor(log(duration/(crossover/4)/(number_of_buffers-1),2)+1);
slow=multitau_arduino.bin_and_correlate(crossover/4,number_of_buffers,number_of_levels);
fast=multitau_arduino.time_of_arrival(clock,crossover);

#Acquisition
print('Starting Acquisition for ',duration,'sec');

ser = serial.Serial(COMport,115200,timeout=1)  # open serial port
print(ser.name)         # check which port was really used
ser.flushInput();
sleep(2);
ser.write(b'd');        # Send to arduino the "start acquisition" signal
data=ser.read(bunchsize);
print(len(data))

x_limits=(1e-6,duration);
times=[];
fmt = "<%dI" % (len(data) // 4);
#acquisition function definition
def read_photons(ser):
	global times;
	while time()-t0<duration:
                data=ser.read(bunchsize);
                times.extend(list(unpack(fmt, data)))

# correlation function defition
def correlate_photons():
	global printed_end, arrival_times, times_between_photons, offset, running, tt, ttslow, g2, g2s, nfotoni, indx, tplot
	while running:
		if not(dataThread.isAlive()):
                	if todo>0 and printed_end==False:
                        	printed_end=True;
                        	print('');
                        	print('Acquisition ended, completing correlation...');
                	elif todo==0:
                        	print('Done!')
                        	running=False;
			
			
		if indx==0:
			arrival_times=[];
			time_between_photons=[];
			offset=0;
		
		todo=min(photons_to_correlate,len(times));
		if todo>0:
                	[arrival_times,time_between_photons,frames]=multitau_arduino.process_photons(times[:todo],offset,crossover,clock,arrival_times,time_between_photons);	
                	indx=fast.correlate_photons(arrival_times);
                	if printed_end==False:
                        	elapsed=round(time()-t0,2);
                        	print('Time: ',elapsed,'sec, Photons per sec: ',round(mean(frames)/crossover,0),end="\r")
                	slow.correlate(frames);
                	[arrival_times,offset]=multitau_arduino.post_process_photons(arrival_times,indx);
                	del times[:indx+1];
                	
		if (time()-tplot)>3:
			[tt,g2,nfotoni]=fast.normalize();
			[ttslow,g2s]=slow.normalize();
			tplot=time();


# Ending on Control-C
def handler(signum, frame):
        global duration
        duration=time()-t0;
signal.signal(signal.SIGINT, handler)



#starting data acquisition thread
starttime=datetime.now().strftime('%d-%b-%Y %H:%M:%S');
t0=time();
indx=0;

dataThread=threading.Thread(target=read_photons, args=(ser,)); #starting the data acquisition thread;
dataThread.start();

#starting correlation
running=True;
tplot=time();
printed_end=False;

corrThread=threading.Thread(target=correlate_photons, args=()); #starting the datacorrelation acquisition thread;
corrThread.start();



#[tt,g2,nfotoni]=fast.normalize();
#[ttslow,g2s]=slow.normalize();

#ser.write(b'd')     # Stop Acquisition
#ser.close()         #Closing serial connection

