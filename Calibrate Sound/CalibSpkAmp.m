%function [calib_freqs,calib_zero,calib_high]=CalibSpkAmp(filename,freq,attens,So_file,gain)
%
% So is sensitivity of mic
%   a scalar mV/pa for B&K, or
%   a filename for knowles generated from calibrate_mic
%
% calib_zero is atten needed to give 0 dB SPL or 1 mm/s at calib_freq
% calib_high is lowest atten _not_ causing distortion
%
%freq=[40 80 160 logspace(log10(250),log10(4000),13)];
%calibrate_spk('f6_swan_12inch_v',freq,40,'08.10.31/blue_nows',10);
%
%freq=logspace(log10(2e3),log10(64e3),11);
%calibrate_spk('optimus401221_12inch_p',freq(1:end-1),40,0.367,100);


function [calib_freqs,calib_zero,calib_high]=CalibSpkAmp(filename,freq,attens,So_file,gain)

global Fs;

hardware='ni';  % or 'tdt'
Fs=10000;
ramp=0.05;  % all in sec
pre=0.1;
len=0.5;
post=0.1;
shift=0.001;
nreps=10;
%atten_step=16;
%atten_acc=2;
%snr_crit=100;
thdn_crit=0.01;
%highpass=10;
%lowpass=5000;
highpass=[];
lowpass=[];
mic_clip=1.75;
input_range=2;
output_range=1;

if strcmp(hardware,'ni')
%  if(atten_init>0)
%    warning(['loosing ' num2str(log2(10^(atten_init/20))) ' bits of D/A resolution']);
%  end
else
  if((max(attens)>120)|(min(attens)<0))
    error('some attens are not between 0 and 120 dB');
  end
end

if(~isempty(filename))
  if(exist([filename '_spkamp'],'file'))
    error([filename ' already exists']);
  end
end

if strcmp(hardware,'ni')
  global BOARDS SESSION

  BOARDS=daq.getDevices;
  BOARDS=BOARDS(1);
  SESSION=daq.createSession('ni');
  SESSION.addAnalogInputChannel(BOARDS.ID,0,'voltage');
  SESSION.Channels(1).InputType='SingleEndedNonReferenced';
  SESSION.Channels(1).Range=[-input_range input_range];
  SESSION.addAnalogOutputChannel(BOARDS.ID,0,'voltage');
  SESSION.Channels(2).Range=[-output_range output_range];
  SESSION.Rate=Fs;
else
  global ZBUS RP2_1 RP2_2 PA5L PA5R;
  tdt_init('stereo_record_play25k.rcx','',97656.25/4);
  %tdt_init('stereo_record_play100k.rcx','',97656.25);
end

%if(sum(3.*freq>(Fs/2))>0)
%  error('some needed harmonics are greater than the Nyquist frequency');
%  tdt_halt;
%  return;
%end

%disp(['estimated minimum time = ' num2str(length(freq)*(1+3+log2(atten_step/atten_acc))*nreps*2*(pre+len+post)/60) ' min']);
disp(['estimated minimum time = ' num2str(length(freq)*nreps*2*(pre+len+post)/60,3) ' min']);

time=clock;

out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);

for(j=1:nreps)
  disp(['rep=' num2str(j)]);
  for(i=1:length(attens))
    out=output_range.*apply_envelope(cos(2*pi*freq*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
    out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];

    %atten_use=calib_high(i)+atten_step;
    if(j==1)
      disp(['freq=' num2str(round(freq)) ';  amp=' num2str(attens(i))]);
    end

    [raw(i,j,:) ~]=CalibPlay(out,out_idx,freq,attens(i),'L',highpass,lowpass,mic_clip);
  end
end
%raw_zero=squeeze(winsormean(raw_zero,winsor,2));
%raw_zero=reshape(raw_zero,size(raw_zero,1),size(raw_zero,2),size(raw_zero,4));

calib_freqs=freq;

if(~isempty(filename))
  %save_as_text([filename '_spk.m'],freq,atten_init,So_file,gain,ramp,pre,len,post,shift,nreps,atten_step,atten_acc,snr_crit,highpass,lowpass,winsor,mic_clip,So,time,raw_high,raw_zero,snr_high,thdn_zero,calib_freqs,calib_zero,calib_high);
  save([filename '_spkamp'],'freq','attens','So_file','gain',...
      'hardware','Fs','ramp','pre','len','post','shift','nreps',...
      'thdn_crit','highpass','lowpass','mic_clip','input_range','output_range',...
      'time','raw');
end

CalibSpkAmpPlot(freq, attens, So_file, gain, Fs, ramp, pre, len, post, shift, mic_clip, raw);

if strcmp(hardware,'ni')
else
  tdt_halt;
end
