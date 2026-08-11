%function [freq,data]=calibrate_check(freq,amp,side_out,side_in,calib)
%
%calibrate_check([100 1000 10000],30,'L','R','calib_file.m');

function [freq,data]=calibrate_check(freq,amp,side_out,side_in,calib)

global Fs;
global ZBUS RP2_1 RP2_2 PA5L PA5R;

tdt_init('stereo_record_play50k.rcx','',97656.25/2);

if(sum(freq>(Fs/2))>0)
  error('some freqs are greater than the Nyquist frequency');
  return;
end

run([calib '_cal']);

ramp=0.005;
pre=0.05;
len=0.1;
post=0.1;
isi=0.5;
nreps=3;

for(i=1:length(freq))
  out=10.*trap_env(sin((1:round(len*Fs))*freq(i)*2*pi/Fs),ramp,ramp,Fs);
  out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];
  out_idx=round(pre*Fs)+(1:len*Fs);
  atten=calibrate_get(freq(i),amp,calib_freqs,calib_zero,calib_high,calib_low);
  for(j=1:nreps)
    if(side_out=='L')
      set_atten(atten,120);
      [in1,in2]=tdt_stereo_record_play(out,[],1);
    end
    if(side_out=='R')
      set_atten(120,atten);
      [in1,in2]=tdt_stereo_record_play([],out,1);
    end
    if(side_in=='L')  in(j,:)=in1;  end
    if(side_in=='R')  in(j,:)=in2;  end
  end
  in=mean(in,1);
  [data(i) foo]=fit_sin(in(out_idx),freq(i),Fs);
end

figure;  clf;
semilogx(freq,20*log10(data),'k.-');
axis tight;
