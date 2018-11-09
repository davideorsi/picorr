import numpy as np  
cimport numpy as np
from itertools import accumulate

def process_photons(list times, long long offset, float crossover,float clock,list arrival_times,list time_between_photons):
	cdef int i;
	cdef float v,x;

	time_between_photons.extend(times);
	cumul=list(accumulate(times));
	cumul[:]=[x+offset for x in cumul];
	arrival_times.extend(cumul);
	offset=arrival_times[-1];
	
	timeraw=list(accumulate(time_between_photons));
	timeraw[:]=[float(x)/clock for x in timeraw];
	if len(timeraw)>0:
		tvec=np.arange(0,timeraw[-1],crossover/float(4.0));
		frames=np.histogram(timeraw,tvec)[0].tolist();
		limit=next((i for i,v in enumerate(timeraw) if v > tvec[-1]),None);
		if limit:
			del time_between_photons[:limit];
		else: 
			time_between_photons=[];
	return [arrival_times,time_between_photons,frames]
		
def post_process_photons(list arrival_times,int indx):
	cdef int x;
	first=arrival_times[indx];
	del arrival_times[:indx];
	arrival_times[:] = [x - first for x in arrival_times];
	offset=arrival_times[-1];
	return [arrival_times,offset]

cdef class bin_and_correlate:
	"""A class for the bin & correlate algorithm, to be used for 'slow' correlation times"""
	cdef float dt;
	cdef int nobuf, nolev;
	cdef list buf,cts,cur,num,g2,time,G,IntPast,IntFuture
	
	def __init__(self, float dt, int nobuf, int nolev):
		self.dt = dt; 
		self.nolev=nolev;
		self.nobuf=nobuf;
		
		
		#BUFFERS initialization
		self.buf=zeros = [ [0.0] * nolev for _ in range(nobuf)] #matrix of buffers
		self.cts=[0.0] * nolev;
		self.cur=[nobuf] * nolev;
		self.num=[0.0]*nolev;
		self.g2  =[0.0]*((nolev+1)*nobuf//2);
		self.time=[0.0]*((nolev+1)*nobuf//2); 
		self.G=[0.0]*((nolev+1)*nobuf//2);
		self.IntPast=[0.0]*((nolev+1)*nobuf//2);
		self.IntFuture=[0.0]*((nolev+1)*nobuf//2);
		
		self.delays(); #generating the array of time delays
		
		
	def delays(self):
		"""Generating the array of time delays"""
		cdef int i, imin
		for i in range(0,self.nolev):
			if i==0:
				imin=1;
			else:
				imin=self.nobuf//2; 
			for j in range(imin,self.nobuf):
				ptr=i*self.nobuf//2+j;
				self.time[ptr]= self.dt*(j * 2**(i));
				
	def correlate(self, frames):
		for jframe in range(0,len(frames)):
			self.add_frame_and_correlate(int(frames[jframe]));
		
	def add_frame_and_correlate(self,float frame):
		cdef int i, imin, lev, prev, ptr, delayno ;
		cdef float norm;
		
		self.cur[0]=1+ self.cur[0] % self.nobuf;  #increment self.buffer
		
		self.buf[self.cur[0]-1][0]=frame; # addinself.G intensity to the self.buffer
		
		lev=1;
		self.num[lev-1]+=1; # one more in averaself.Ge
		for i in range(1,int(1+min(self.num[lev-1],self.nobuf))): #loop over delays
			ptr=int((lev-1)*self.nobuf/2+i);
			delayno=int(1+ (self.cur[lev-1]-i+self.nobuf) % self.nobuf); #cyclic self.buffers
			norm=float(self.num[lev-1]-i+1);
			self.G[ptr-1]  += (self.buf[self.cur[lev-1]-1][lev-1] * self.buf[delayno-1][lev-1] - self.G[ptr-1]) /norm; #runninself.G averaself.Ge updated
			self.IntPast[ptr-1] += (self.buf[delayno-1][lev-1] -self.IntPast[ptr-1]) / norm;
			self.IntFuture[ptr-1] += (self.buf[self.cur[lev-1]-1][lev-1]-self.IntFuture[ptr-1]) / norm;
		
		imin=1+self.nobuf//2;
		
		for lev in range(2,int(self.nolev+1)):
			
			if (self.cts[lev-1]==1):
				prev=1+ (self.cur[lev-2]-2+self.nobuf) % self.nobuf;
				self.cur[lev-1]=1+ self.cur[lev-1] % self.nobuf;
				self.buf[self.cur[lev-1]-1][lev-1] = ( self.buf[prev-1][lev-2]+self.buf[self.cur[lev-2]-1][lev-2] )/2;
				self.cts[lev-1]=0;
				self.num[lev-1]+=1; # one more in averaself.Ge
				for i in range(imin,int(1+min(self.num[lev-1],self.nobuf))): #loop over delays
					ptr=int((lev-1)*self.nobuf//2+i);
					delayno=int(1+ (self.cur[lev-1]-i+self.nobuf) % self.nobuf); #cyclic self.buffers
					norm=float(self.num[lev-1]-i+1);
					self.G[ptr-1]  += (self.buf[self.cur[lev-1]-1][lev-1] * self.buf[delayno-1][lev-1] - self.G[ptr-1]) /norm; #runninself.G averaself.Ge updated
					self.IntPast[ptr-1] += (self.buf[delayno-1][lev-1] -self.IntPast[ptr-1]) / norm;
					self.IntFuture[ptr-1] += (self.buf[self.cur[lev-1]-1][lev-1]-self.IntFuture[ptr-1]) / norm;
			else:
				self.cts[lev-1]=1; # set flag to process next time
				break;

	def	normalize(self):		
		for i in range(0,len(self.g2)):
			if self.IntPast[i]>0 and self.IntFuture[i]>0:
				self.g2[i]=self.G[i]/self.IntPast[i]/self.IntFuture[i];
		return [self.time[4:],self.g2[4:]];
		

cdef class time_of_arrival:
	"""A class for the correlator algorithm that works on the arrival time of photons, to be used for 'fast' correlation times"""
	cdef float clock,maxt,tpn,ttm
	cdef list time_clock,time,norm,v,kj,g2
	 
	def __init__(self, float clock, float maxt):
		cdef int i;
		self.maxt=maxt;
		self.clock=clock;
		
		self.time_clock=self.delays();
		self.norm  = [0.0]*(len(self.time_clock)-1);
		self.time  = [0.0]*(len(self.time_clock)-1);
		
		for i in range(0,len(self.time_clock)-1):
			self.norm[i]=float(self.time_clock[i+1])-float(self.time_clock[i]);
			self.time[i]=self.time_clock[i+1]/clock;
		
		self.tpn=0.0; 
		self.ttm=0.0; 
		self.v  = [0.0]*len(self.time_clock);
		self.kj = [0.0]*len(self.time_clock);
		self.g2 =[0.0]*(len(self.time_clock)-1);
		
		
	def delays(self):
		"""Generating the array of time delays"""
		cdef int i;
		cdef float casc,t0;
		cdef list time_clock;
		
		t0=7; #dead time of the phototube
		casc=float(0.16);
		time_clock=[1]; 
		i=0;
		while time_clock[-1] <self.maxt*self.clock:
			i+=1;
			time_clock+=[(time_clock[i-1]+2**round((i+1)*casc))];
		time_clock[:]=[x+t0 for x in time_clock];
		limit=next((i for i,v in enumerate(time_clock) if v/self.clock > 3e-6),None);		
		del time_clock[:limit];
		return time_clock;

	
	def correlate_photons(self,data):
		cdef int iii,j,k,maxt1
			
		maxt1=data[-1]-self.time_clock[-1]-1;
		v1=[0.0]*len(self.time_clock);
		
		iii=0;
		while (data[iii]<=maxt1):
			
			
			for j in range(0,len(self.time_clock)):
				k=self.kj[j];
				shf=data[iii]+self.time_clock[j];
				
				if data[iii+k]<=shf:
					while iii+k<len(data) and data[iii+k]<=shf:
						k+=1;
					if iii+k>len(data):
						break;
					k-=1;
				else:
					while data[iii+k]>shf:
						k-=1;
					
				self.kj[j]=k;
				
			for j in range(0,len(v1)):	
				v1[j]+=self.kj[j];
			iii+=1;

		self.tpn+=iii;
		self.ttm+=float(data[iii]);
		
		for j in range(0,len(self.v)):	
			self.v[j]+=v1[j];

		return(iii);
		
		
			
	def normalize(self):
		for j in range(0,len(self.v)-1):
			if self.tpn>0:	
				self.g2[j]=(self.v[j+1]-self.v[j])/self.norm[j]*self.ttm /self.tpn**2;	
		return [self.time,self.g2,self.tpn];
