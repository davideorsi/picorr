#!/usr/bin/python3
import multitau_arduino 
import threading
from time import sleep
from math import log,floor,ceil
import matplotlib.pyplot as plt
from struct import unpack
import os

clock=42.0e6;
duration=55; #in seconds
filename="/home/davide/Dati/DWS/fototubo/test_55sec.bin";
f = open(filename, "rb");

x_limits=(1e-6,duration);

times=[];
#function definition
def read_photons(f):
	global times;
	while True:
		data=f.read(bunchsize);
		if len(data)==0:
			break;
		fmt = "<%dI" % (len(data) // 4);
		times.extend(list(unpack(fmt, data)));	
		sleep(1);


bytesize= os.path.getsize(filename)
bunchsize=8192;
crossover=0.0005;

number_of_buffers=8;
number_of_levels=floor(log(duration/crossover/(number_of_buffers),2)+1);

#initializing correlators
slow=multitau_arduino.bin_and_correlate(crossover/4,number_of_buffers,number_of_levels);
fast=multitau_arduino.time_of_arrival(clock,crossover);

#creating plot
plt.ion()
fig,ax=plt.subplots()
[time,g2]=fast.normalize();
[timeslow,g2s]=slow.normalize();
line, =plt.semilogx(time+timeslow,g2+g2s,'b-');
plt.xlim(x_limits)
plt.ylim((0.95,1.4))

dataThread=threading.Thread(target=read_photons, args=(f,)); #starting the data acquisition thread;
dataThread.start();

indx=0;
running=True;
processed_photons=0;



while running:
	if not(dataThread.isAlive()):
		running=False;
		
	if indx==0:
			arrival_times=[];
			time_between_photons=[];
			offset=0;
	
	photons_acquired=len(times);
	if(photons_acquired>processed_photons):
		[arrival_times,time_between_photons,frames]=multitau_arduino.process_photons(times[processed_photons:photons_acquired],offset,crossover,clock,arrival_times,time_between_photons);
		processed_photons=photons_acquired;	
		indx=fast.correlate_photons(arrival_times);
		slow.correlate(frames);
		[arrival_times,offset]=multitau_arduino.post_process_photons(arrival_times,indx);
		

		[time,g2]=fast.normalize();
		[timeslow,g2s]=slow.normalize();

		line.set_xdata(time+timeslow);
		line.set_ydata(g2+g2s);
		sleep(0.05)
		ax.relim();
		fig.canvas.draw();

plt.show()


f.close();


#semilogx(slow.time,slow.g2); show()

