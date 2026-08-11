%function [calib_freqs,calib_zero,calib_high]=CalibSpkFreq(filename,freqs,atten_init,So_file,gain)
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


function [calib_freqs,calib_zero,calib_high]=CalibSpkFreq(filename,freqs,atten_init,So_file,gain)

global Fs;

hardware='ni';  % or 'tdt'
Fs=10000;
ramp=0.05;  % all in sec
pre=0.1;
len=0.5;
post=0.1;
shift=0.001;
nreps=10;
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
input_range=2;
output_range=1;

if strcmp(hardware,'ni')
  if(atten_init>0)
    warning(['loosing ' num2str(log2(10^(atten_init/20))) ' bits of D/A resolution']);
  end
else
  if((atten_init>120)|(atten_init<0))
    error('atten is not between 0 and 120 dB');
  end
end

if(~isempty(filename))
  if(exist([filename '_spkfreq.mat'],'file'))
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

[So PVo]=CalibLoadMic(So_file);

%disp(['estimated minimum time = ' num2str(length(freq)*(1+3+log2(atten_step/atten_acc))*nreps*2*(pre+len+post)/60) ' min']);
disp(['estimated minimum time = ' num2str(length(freqs)*nreps*2*(pre+len+post)/60,3) ' min']);

time=clock;

out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);

flag=ones(size(freqs));
raw_high=zeros(length(freqs),nreps,round(pre*Fs)+round(len*Fs)+round(post*Fs));
calib_high=atten_init*ones(size(freqs));
thdn_high=nan*ones(size(freqs));
clip_high=nan*ones(size(freqs));
low=nan*ones(size(freqs));
high=nan*ones(size(freqs));

if(0)

pass=1;
while(sum(flag==3)<length(freq))
  disp(['pass=' num2str(pass)]);
  for(j=1:nreps)
    disp(['rep=' num2str(j)]);
    for(i=1:length(freq))
      if(flag(i)==3)  continue;  end

      out=10.*apply_envelope(cos(2*pi*freq(i)*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
      out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];

      [raw_high(i,j,:) foo]=calibrate_play(out,out_idx,freq(i),calib_high(i),'L',highpass,lowpass,mic_clip);
    end
  end

  raw_high=squeeze(winsormean(raw_high,winsor,2));
  %raw_high=reshape(raw_high,size(raw_high,1),size(raw_high,2),size(raw_high,4));

  for(i=1:length(freq))
    if(flag(i)==3)  continue;  end
    [foo foo snr_high(i) foo foo foo]=calibrate_fit(squeeze(raw_high(i,:)),[],out_idx,freq(i),winsor,shift+2*ramp);
    disp(['freq=' num2str(round(freq(i))) ';  atten=' num2str(calib_high(i)) ';  snr=' num2str(snr_high(i))]);

    if(flag(i)==1)
      if(snr_high(i)>snr_crit)
        if(calib_high(i)==0)
          flag(i)=3;
        else
          low(i)=calib_high(i);
          if(isnan(high(i)))
            calib_high(i)=max(calib_high(i)-atten_step,0);
          else
            calib_high(i)=mean([low(i) high(i)]);
          end
        end
      else
        if(calib_high(i)==120)
          flag(i)=3;
        else
          high(i)=calib_high(i);
          if(isnan(low(i)))
            calib_high(i)=min(calib_high(i)+atten_step,120);
          else
            calib_high(i)=mean([low(i) high(i)]);
          end
        end
      end
      if((low(i)-high(i))<=atten_acc)
        flag(i)=2;
      end
    elseif(flag(i)==2)
      flag(i)=3;
    end
  end
  pass=pass+1;
end

end


for(j=1:nreps)
  disp(['rep=' num2str(j)]);
  for(i=1:length(freqs))
    out=output_range.*apply_envelope(cos(2*pi*freqs(i)*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
    out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];

    %atten_use=calib_high(i)+atten_step;
    atten_use=atten_init;
    if(j==1)
      disp(['freq=' num2str(round(freqs(i))) ';  amp=' num2str(atten_use)]);
    end

    [raw_zero(i,j,:) ~]=CalibPlay(out,out_idx,freqs(i),atten_use,'L',highpass,lowpass,mic_clip);
  end
end
%raw_zero=squeeze(winsormean(raw_zero,winsor,2));
%raw_zero=reshape(raw_zero,size(raw_zero,1),size(raw_zero,2),size(raw_zero,4));
for(i=1:length(freqs))
  So1=interp1(So(:,1),So(:,2),freqs(i),'linear','extrap');
  [amp,~,thdn_zero(i),clip_zero(i),~,~,~,~]=...
      CalibFit(squeeze(raw_zero(i,:,:)),[],out_idx,freqs(i),winsor,shift+2*ramp,mic_clip);
  %if(thdn_zero(i)>thdn_crit) warning('atten for zero results in high THD+N.');  end
  if((freqs(i)<min(So(:,1))) | (freqs(i)>max(So(:,1))))
    warning(['extrapolating So for ' num2str(freqs(i)) ' Hz from ' num2str(min(So(:,1))) ' Hz to ' num2str(max(So(:,1))) ' Hz dataset']);
  end
  %atten_use=calib_high(i)+atten_step;
  atten_use=atten_init;
  calib_zero(i)=atten_use+20*log10(amp/gain/So1/PVo);
  %disp(['zero=' num2str(calib_zero(i))]);
end

calib_freqs=freqs;

if(~isempty(filename))
  %save_as_text([filename '_spk.m'],freq,atten_init,So_file,gain,ramp,pre,len,post,shift,nreps,atten_step,atten_acc,snr_crit,highpass,lowpass,winsor,mic_clip,So,time,raw_high,raw_zero,snr_high,thdn_zero,calib_freqs,calib_zero,calib_high);
  save([filename '_spkfreq'],'freqs','atten_init','So_file','gain',...
      'hardware','Fs','ramp','pre','len','post','shift','nreps',...
      'atten_step','atten_acc','thdn_crit','highpass','lowpass','winsor','mic_clip','input_range','output_range',...
      'So','time','raw_high','raw_zero','thdn_high','thdn_zero','clip_high','clip_zero','calib_freqs','calib_zero','calib_high');
end

CalibSpkFreqPlot(mic_clip, calib_freqs, calib_high, calib_zero, raw_high, raw_zero,...
    thdn_high, thdn_zero, clip_high, clip_zero);

if strcmp(hardware,'ni')
else
  tdt_halt;
end
