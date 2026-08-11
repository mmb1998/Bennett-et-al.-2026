%function [freqs,So2]=calibrate_mic(filename,freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press)
%
% calibrate_mic('blk_1m_a400',[125 500 2000],20:2:80,3.47,10,'p',10,'p',14,60,1007);
% freqs=logspace(log10(125/4),log10(2000),25);
% calibrate_mic('blk_1m_f',freqs(3:end),30:10:60,3.47,10,'p',10,'p',14,60,1007);
%
% So1 is sensitivity of the calibrated mic (in mV/Pa or mV/(m/s), and internally converted to V)
%   phase assumed to be flat
% type = 'p' or 'pv' for pressure or particle velocity
% ref mic in left channel, (optional) mic to be calibrated in right
%   leave gain2,type2 = [] to just test linearity of speaker with amplitude
%   set gain2,type2 != [] to calibrate 2nd mic as well
% temp, humid, & press are in C, %, and mbar, respectively
%   if set to [], assumed to be STP
% So2 is sensitivity of the calibrated mic (in V/Pa or V/(m/s), and radians)


function [freqs,So2]=calibrate_mic(filename,freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press, varargin)

global Fs pv_usb_samp_rate; %Fs = sampling frequency? where is this set?
global ZBUS RP2_1 RP2_2 PA5L PA5R;
pv_usb_samp_rate = 6000; %Hz

%tdt_init('stereo_record_play25k.rcx','',97656.25/4);
%tdt_init('stereo_record_play50k.rcx','',97656.25/2);
%tucker-davis technology board that needs to be replaced with nidaq
%need 1-2 analog ins (for mics) and one analog out (for speaker)

PA5R=[];

if(sum((attens>120)|(attens<0))>0)
  disp('ERROR: some amps are not between 0 and 120 dB');
  tdt_halt;
  return;
end

if(max(freqs)>(Fs/2))
  disp('ERROR: freq is greater than the Nyquist frequency');
  tdt_halt;
  return;
end

if((~strcmp(type1,'p')) & (~strcmp(type1,'pv')))
  error('invalid mic1 type');
end
if((~strcmp(type2,'p')) & (~strcmp(type2,'pv')) & (~strcmp(type2,'pvusb')))
  error('invalid mic2 type');
end

%check that a COM port was provided for USB PV mic --Han
if strcmp(type2,'pvusb') && ~narginchk(11,12))
  error('need to supply virtual serial port for USB PV mic');
end

if(~isempty(filename))
  if(exist([filename '_mic.m'])>0)
    error([filename ' already exists']);
  end
end

%[So1 foo]=calibrate_load_mic(So1);
[So1 foo]=CalibLoadMic(So1);

ramp=0.05;
pre=0.1;
len=1; %duration of sound delivery, was 0.5
post=0.1;
nreps=5;
snr_crit=1;
shift=0.001; %this needs to be in the 100 ms range for wiggle room as the USB PV mic can only be soft triggered
highpass=20;
lowpass=20000;
%highpass=[];
%lowpass=[];
winsor=0.2;
mic_clip=2;

figure(1);

global but_accept but_reject keep_it;  keep_it=0;
my_mode=uibuttongroup('unit','pixels','position',[0 2 170 20],...
   'SelectionChangeFcn',@selcbk);
but_go=uicontrol('parent',my_mode,'style','radiobutton',...
   'string','go','position',[10 2 40 15]);
but_pause=uicontrol('parent',my_mode,'style','radiobutton',...
   'string','pause','position',[50 2 70 15]);
but_query=uicontrol('parent',my_mode,'style','radiobutton',...
   'string','query','position',[110 2 50 15]);
but_accept=uicontrol('style','pushbutton','backgroundColor',[0 1 0],...
   'string','accept','position',[190 5 60 15],'visible','off',...
   'callback', 'global keep_it; keep_it=1;');
but_reject=uicontrol('style','pushbutton','backgroundColor',[1 0 0],...
   'string','reject','position',[260 5 60 15],'visible','off',...
   'callback', 'global keep_it; keep_it=-1;');

attens=[120 attens];

disp(['estimated time = ' num2str(nreps*length(freqs)*length(attens)*2*(pre+len+post)/60) ' min']);

time=clock;

in1=zeros(length(attens),length(freqs),nreps,round(pre*Fs)+round(len*Fs)+round(post*Fs));
in2=zeros(length(attens),length(freqs),nreps,round(pre*pv_usb_samp_rate)+round(len*pv_usb_samp_rate)+round(post*pv_usb_samp_rate)); %changed Fs to pv_usb_samp_rate
for(k=1:nreps)
  disp(['rep=' num2str(k)]);
  for(j=1:length(freqs))
    disp(['freq=' num2str(round(freqs(j)))]);
    out=10.*my_env(sin(2*pi*freqs(j)*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
    out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];
    out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs); 

    if((freqs(j)<min(So1(:,1))) | (freqs(j)>max(So1(:,1))))
      warning(['extrapolating So for ' num2str(freqs(j)) ' Hz from ' num2str(min(So1(:,1))) ' Hz to ' num2str(max(So1(:,1))) ' Hz dataset']);
    end

    i=1;
    while(i<=length(attens))
      if(attens(i)==120)  foo=zeros(1,length(out));  else  foo=out;  end
      %[in1(i,j,k,:) in2(i,j,k,:)]=calibrate_play(foo,out_idx,freqs(j),attens(i),'L',highpass,lowpass,mic_clip);
      [in1(i,j,k,:) in2(i,j,k,:)]=CalibPlay(foo,out_idx,freqs(j),attens(i),'L',highpass,lowpass,mic_clip); %need to send USB PV mic info and output time
      tmp=get(my_mode,'selectedobject');
      while((tmp==but_pause) | ((tmp==but_query) & (keep_it==0)))
        pause(0.1);
        tmp=get(my_mode,'selectedobject');
      end
      if(tmp==but_query)
        if(keep_it==1)  i=i+1;  end
        keep_it=0;
      else
        i=i+1;
      end
    end
  end
end

in1=squeeze(winsormean(in1,winsor,3)); %winsormean is from some dependency?
in2=squeeze(winsormean(in2,winsor,3));

for(j=1:length(freqs))
  for(i=1:length(attens))
    %[amp1(i,j) phi1(i,j) snr1(i,j) amp2(i,j) phi2(i,j) snr2(i,j)]=calibrate_fit(squeeze(in1(i,j,:)),squeeze(in2(i,j,:)),out_idx,freqs(j),winsor,shift+2*ramp);
    [amp1(i,j) phi1(i,j) snr1(i,j) amp2(i,j) phi2(i,j) snr2(i,j)]=CalibFit(squeeze(in1(i,j,:)),squeeze(in2(i,j,:)),out_idx,freqs(j),winsor,shift+2*ramp); %this needs mic_clip
    tmpMf=interp1(So1(:,1),So1(:,2),freqs(j),'linear','extrap');
    tmpPf=interp1(So1(:,1),So1(:,3),freqs(j),'linear','extrap');
    amp1(i,j)=amp1(i,j)/gain1/tmpMf;
    amp2(i,j)=amp2(i,j)/gain2;
    phi1(i,j)=mod(phi1(i,j)-tmpPf,2*pi);
  end
end

if(isempty(temp))   temp=25;  end    % in deg C
if(isempty(humid))  humid=0;  end    % in %, relative humidity
if(isempty(press))  press=1013.25;  end   % in millibars

c = 331.3 + 0.606 * temp;

temp_k = temp + 273.15;
press_pa = press*100;

p_sat = 6.1078 * 10^((7.5*temp_k-2048.625)/(temp_k-35.85));
p_wv = humid * p_sat;
p_da = press_pa - p_wv;
R_da=287.05;  R_wv=461.495;   % specific gas constants, J/(kg.K)
rho=p_da/(R_da*temp_k) + p_wv/(R_wv*temp_k);

if(~strcmp(type1,type2))
  if(strcmp(type2,'pv'))  su=rho*c;  end
  if(strcmp(type2,'p'))   su=1/(rho*c);  end
else
  su=1;
end
So2=zeros(length(freqs),3);
for(j=1:length(freqs))
  idx=find((snr1(2:end,j)>snr_crit) & (snr2(2:end,j)>snr_crit));
  if(length(idx)>1)
    So2(j,1:2)=regress(amp2(1+idx,j),[amp1(1+idx,j)'./su; ones(1,length(1+idx))]');
  elseif(length(idx)==1)
    So2(j,1:2)=[amp2(1+idx,j) / amp1(1+idx,j)./su 0];
  else
    So2(j,1:2)=[nan nan];
  end
  if(length(idx)>0)
    So2(j,3)=mod(mean(unwrap(phi2(1+idx,j)-phi1(1+idx,j))),2*pi);
  else
    So2(j,3)=nan;
  end
end

if(~isempty(filename))
  save_as_text([filename '_mic.m'],freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press,Fs,ramp,pre,len,post,nreps,snr_crit,shift,highpass,lowpass,winsor,mic_clip,time,in1,in2,amp1,phi1,snr1,amp2,phi2,snr2,rho,c,So2);
end

calibrate_mic_plot(freqs,attens,type1,type2,mic_clip,snr_crit,in1,in2,amp1,phi1,snr1,amp2,phi2,snr2,rho,c,So2);

%tdt_halt;



function selcbk(source,eventdata)

global but_accept but_reject;

if(strcmp(get(eventdata.NewValue,'string'),'query'))
  set(but_accept,'visible','on');
  set(but_reject,'visible','on');
else
  set(but_accept,'visible','off');
  set(but_reject,'visible','off');
end
