%function [cal_freq,cal_mag,cal_phi]=CalibSpkFreqNoise(filename,atten,So_file,gain)
%
% So is sensitivity of mic
%   a scalar mV/pa for B&K, or
%   a filename for knowles generated from calibrate_mic
%
% gain is the amplification of the mic
% atten is how much to attenuate the output signal, to stop clipping
%
% output is the sensitivity of the speaker, in Hz, m/s per V, and radians
%
%freq=[40 80 160 logspace(log10(250),log10(4000),13)];
%calibrate_spk('f6_swan_12inch_v',freq,40,'08.10.31/blue_nows',10);
%
%freq=logspace(log10(2e3),log10(64e3),11);
%calibrate_spk('optimus401221_12inch_p',freq(1:end-1),40,0.367,100);


function [cal_freq,cal_mag,cal_phi]=CalibSpkFreqNoise(filename,atten,So_file,gain)

global Fs;

hardware='ni';  % or 'tdt'
Fs=10000;
ramp=0.05;  % all in sec
pre=0.1;
len=5;
post=0.1;
shift=0.00;
nfft_sec=0.1;
atten_step=16;
atten_acc=2;
%snr_crit=100;
thdn_crit=0.01;
%highpass=10;
%lowpass=5000;
highpass=[];
lowpass=[];
winsor=0;
mic_clip=1.75;
input_channel=0;
output_channel=0;
input_range=2;
output_range=1;

if strcmp(hardware,'ni')
  if(atten>0)
    warning(['loosing ' num2str(log2(10^(atten/20))) ' bits of D/A resolution']);
  end
else
  if((atten>120)|(atten<0))
    error('atten is not between 0 and 120 dB');
  end
end

if(~isempty(filename))
  if(exist([filename '_spkfreqnoise.mat'],'file'))
    error([filename ' already exists']);
  end
end

if strcmp(hardware,'ni')
  global BOARDS SESSION

  BOARDS=daq.getDevices;
  BOARDS=BOARDS(1);
  SESSION=daq.createSession('ni');
  SESSION.addAnalogInputChannel(BOARDS.ID,input_channel,'voltage');
  SESSION.Channels(1).InputType='SingleEndedNonReferenced';
  SESSION.Channels(1).Range=[-input_range input_range];
  SESSION.addAnalogOutputChannel(BOARDS.ID,output_channel,'voltage');
  SESSION.Channels(2).Range=[-output_range output_range];
  SESSION.Rate=Fs;
else
  global ZBUS RP2_1 RP2_2 PA5L PA5R;
  tdt_init('stereo_record_play25k.rcx','',97656.25/4);
  %tdt_init('stereo_record_play100k.rcx','',97656.25);
end

[So PVo]=CalibLoadMic(So_file);
nfft=round(nfft_sec*Fs);

time=clock;

out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);

out=output_range.*apply_envelope(rand(1,round(len*Fs)),'cosine',ramp,ramp,Fs);
out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];

[in, ~, clip, ~]=CalibPlay(out,out_idx,[],atten,'L',highpass,lowpass,mic_clip);
in = in .* 10^(atten/20);
[coh,calib_freq]=mscohere(out,in,[],[],nfft,Fs);
[tf,calib_freq]=tfestimate(out,in,[],[],nfft,Fs);
So1=interp1(So(:,1),So(:,2),calib_freq,'linear','extrap');
So1(So1<=0)=nan;

%calib_zero=atten+20*log10(abs(tf)./gain./So1./PVo);
calib_mag=abs(tf)./gain./So1;  % m/s / V
calib_phi=angle(tf)-So1;  % m/s / V

if(~isempty(filename))
  save([filename '_spkfreqnoise'],'atten','So_file','gain',...
      'hardware','Fs','ramp','pre','len','post','shift','nfft_sec',...
      'highpass','lowpass','winsor','mic_clip',...
      'input_channel','output_channel','input_range','output_range',...
      'So','time','in','clip','coh','calib_freq','calib_mag','calib_phi');
end

CalibSpkFreqNoisePlot(calib_freq, calib_mag, calib_phi, clip, coh);

if strcmp(hardware,'ni')
else
  tdt_halt;
end
