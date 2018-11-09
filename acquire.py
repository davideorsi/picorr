#!/usr/bin/python
import serial
import serial.tools.list_ports
from time import perf_counter as time
import sys
from shutil import copyfile

Tmeas=60;
filename='test.bin';

Narg=len(sys.argv);
Str_arg=sys.argv;

if Narg==2:
        Tmeas=float(Str_arg[1]);
if Narg==3:
        Tmeas=float(Str_arg[1]);
        filename=Str_arg[2];

#finding the COM port
ports=serial.tools.list_ports.comports();
COMport=[];
for port in ports:
        portstr=str(port);
        if portstr.find('Arduino Due')>=0:
                COMport=portstr[0:4];

if not(COMport):
        print('Arduino Due not found!!!')
else:
        #Acquisition
        print('Starting Acquisition for ',Tmeas,'sec');


        ser = serial.Serial(COMport)  # open serial port
        print(ser.name)         # check which port was really used

        fid = open('test.bin','wb')

        ser.flushInput();
        ser.write(b'd');     # Start acquisition
        data=ser.read(8192);

        t0=time();
        while time()-t0<Tmeas:
                t1=time();
                data=ser.read(8192);
                fid.write(data);
                t2=time();
                print('Time: ',round(t2-t0,2),'Photons per sec: ',round(2048.0/(t2-t1),0),end="\r")


        ser.write(b'd')     # Stop Acquisition
        ser.close()     #Closing serial connection
        fid.close();    #Closing file

        if filename!='test.bin':
                copyfile('test.bin', filename);
                print('Data saved as ',filename);
