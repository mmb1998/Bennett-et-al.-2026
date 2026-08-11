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

%version of calibrate_mic that saves raw mic output without calculating
%calibration values--Han

function [freqs,So2]=calibrate_mic(filename,freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press)

global Fs pv_usb_samp_rate SESSION pv_usb_mic; %Fs = B&K mic & speaker output sampling frequency
global ZBUS RP2_1 RP2_2 PA5L PA5R; %relics of TDT board control?
Fs = 16000; %Hz
pv_usb_samp_rate = 8000; %Hz, need to be 1000-8000 Hz & multiple of 1000
pv_usb_port = "COM1"; %check with serialportlist()
nidaq_device = "Dev2"; %change to device name
nidaq_ai_channel = "ai1";
nidaq_ai_channel2 = "ai2"; %if using a second mic connected to NIDAQ
nidaq_ao_channel = "ao0";

%create NIDAQ session
SESSION = daq.createSession("ni");
addAnalogInputChannel(SESSION, nidaq_device, nidaq_ai_channel, "Voltage");
addAnalogOutputChannel(SESSION, nidaq_device, nidaq_ao_channel, "Voltage");
SESSION.Rate = Fs;

PA5R=[];

if(sum((attens>120)|(attens<0))>0)
    disp('ERROR: some amps are not between 0 and 120 dB');
    %tdt_halt;
    return;
end

if(max(freqs)>(Fs/2)) || max(freqs)> pv_usb_samp_rate/2
    disp('ERROR: freq is greater than the Nyquist frequency');
    %tdt_halt;
    return;
end

if((~strcmp(type1,'p')) & (~strcmp(type1,'pv')))
    error('invalid mic1 type');
end
if((~strcmp(type2,'p')) & (~strcmp(type2,'pv')) & (~strcmp(type2,'pvusb')))
    error('invalid mic2 type');
end

%create PV USB mic instance
if strcmp(type2,'pvusb')
    pv_usb_samp_rate = round(pv_usb_samp_rate, -3);
    pv_usb_mic = PvMicUSB(pv_usb_port,pv_usb_samp_rate);
    %pv_buffer_clear_thres = 20000;
    %configureCallback(pv_usb_mic.SerialPortObject,"byte",pv_buffer_clear_thres,@clear_pv_mic_buffer);
    %flush buffered data every now and then
    %byte count threshold to flush should be larger than any capture duration you use
    %(ugly workaround)
    %do not use flush()! Can mess up 2-byte integer stream
    pv_usb_mic.On();
elseif strcmp(type2,'pv') || strcmp(type2,'p')
    addAnalogInputChannel(SESSION, nidaq_device, nidaq_ai_channel2, "Voltage");
end

if(~isempty(filename))
    if exist(strcat(filename,'_mic_raw.mat'),"file")
        error(strcat(filename,' already exists'));
    end
end

%[So1 foo]=calibrate_load_mic(So1);
[So1 foo]=CalibLoadMic(So1);

ramp=0.05;
pre=0.1;
len=2; %duration of sound delivery
post=0.1;
nreps=5; %need 2 or more reps for winsormean() to function properly
snr_crit=1;
shift=0.001; %change depending on distance to mic
highpass=20;
lowpass=1500;
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

attens=[120 attens]; %if attens is 120, play no sound

disp(['estimated time = ' num2str(nreps*length(freqs)*length(attens)*2*(pre+len+post)/60) ' min']);

time=clock;

in1=zeros(length(attens),length(freqs),nreps,round(pre*Fs)+round(len*Fs)+round(post*Fs));
if strcmp(type2,'pvusb')
    in2=zeros(length(attens),length(freqs),nreps,round(pre*pv_usb_samp_rate)+round(len*pv_usb_samp_rate)+round(post*pv_usb_samp_rate));
elseif strcmp(type2,'pv') || strcmp(type2,'p')
    in2=zeros(length(attens),length(freqs),nreps,round(pre*Fs)+round(len*Fs)+round(post*Fs));
end

out_idx=ceil((shift+pre+2*ramp+0.25*len)*Fs):floor((shift+pre+len-2*ramp-0.25*len)*Fs); %more wiggle room for software timed input (for pv usb mic)
if strcmp(type2,'pvusb')
    out_idx2=ceil((shift+pre+2*ramp+0.25*len)*pv_usb_samp_rate):floor((shift+pre+len-2*ramp-0.25*len)*pv_usb_samp_rate);
else
    out_idx2 = [];
end

for(j=1:length(freqs))
    for(k=1:nreps)
        disp(['rep=' num2str(k)]);
        disp(['freq=' num2str(round(freqs(j)))]);
        out=10.*my_env(sin(2*pi*freqs(j)*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs); %convert freq to radians per sec, then multiply with an array of time points (from sampling frequency)
        out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];
        %out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);
        
        if((freqs(j)<min(So1(:,1))) | (freqs(j)>max(So1(:,1))))
            warning(['extrapolating So for ' num2str(freqs(j)) ' Hz from ' num2str(min(So1(:,1))) ' Hz to ' num2str(max(So1(:,1))) ' Hz dataset']);
        end
        
        foo=zeros(1,length(out)); %blank output for atten = 120
        i=1;
        while(i<=length(attens))
            if(attens(i)==120) %if attens is 120, play no sound
                %[in1(i,j,k,:) in2(i,j,k,:)]=calibrate_play(foo,out_idx,freqs(j),attens(i),'L',highpass,lowpass,mic_clip);
                [in1(i,j,k,:) in2(i,j,k,:)]=CalibPlay(foo,out_idx,freqs(j),attens(i),'L',highpass,lowpass,mic_clip,out_idx2);
            else
                [in1(i,j,k,:) in2(i,j,k,:)]=CalibPlay(out,out_idx,freqs(j),attens(i),'L',highpass,lowpass,mic_clip,out_idx2);
            end
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

if type2 == "pvusb"
    pv_usb_mic.delete();
end

%this doesnt work well for PV USB mics which are software timed
%in1=squeeze(winsormean(in1,winsor,3));
%in2=squeeze(winsormean(in2,winsor,3));

% skip the below because we are saving raw data
%for PV USB mic, calculate individually for each replicate
% for k = 1:nreps
%     for(j=1:length(freqs))
%         for(i=1:length(attens))
%             %%[amp1(i,j) phi1(i,j) snr1(i,j) amp2(i,j) phi2(i,j) snr2(i,j)]=calibrate_fit(squeeze(in1(i,j,:)),squeeze(in2(i,j,:)),out_idx,freqs(j),winsor,shift+2*ramp);
%             [amp1(i,j,k) phi1(i,j,k) snr1(i,j,k) amp2(i,j,k) phi2(i,j,k) snr2(i,j,k)]=CalibFit(squeeze(in1(i,j,k,:)),squeeze(in2(i,j,k,:)),out_idx,out_idx2,freqs(j),winsor,shift+2*ramp,mic_clip);
%             %%this needs mic_clip, and also needs to know that sample rate of the
%             %%mics are different
%             tmpMf=interp1(So1(:,1),So1(:,2),freqs(j),'linear','extrap');
%             tmpPf=interp1(So1(:,1),So1(:,3),freqs(j),'linear','extrap');
%             amp1(i,j,k)=amp1(i,j,k)/gain1/tmpMf;
%             amp2(i,j,k)=amp2(i,j,k)/gain2;
%             phi1(i,j,k)=mod(phi1(i,j,k)-tmpPf,2*pi);
%         end
%     end
% end
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
    if(strcmp(type2,'pv')) || strcmp(type2,'pvusb')  su=rho*c;  end
    if(strcmp(type2,'p'))   su=1/(rho*c);  end
else
    su=1;
end

%code below calculates sensitivity of second mic
%skip because we are saving raw data
%probably need to calculate average of amp1(i,j,:) and amp2(") here

% So2=zeros(length(freqs),3);
% for(j=1:length(freqs))
%   idx=find((snr1(2:end,j)>snr_crit) & (snr2(2:end,j)>snr_crit));
%   if(length(idx)>1)
%     So2(j,1:2)=regress(amp2(1+idx,j),[amp1(1+idx,j)'./su; ones(1,length(1+idx))]');
%   elseif(length(idx)==1)
%     So2(j,1:2)=[amp2(1+idx,j) / amp1(1+idx,j)./su 0];
%   else
%     So2(j,1:2)=[nan nan];
%   end
%   if(length(idx)>0)
%     So2(j,3)=mod(mean(unwrap(phi2(1+idx,j)-phi1(1+idx,j))),2*pi);
%   else
%     So2(j,3)=nan;
%   end
% end

if(~isempty(filename))
    %save_as_text([filename '_mic_raw.m'],freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press,Fs,ramp,pre,len,post,nreps,snr_crit,shift,highpass,lowpass,winsor,mic_clip,time,in1,in2,amp1,phi1,snr1,amp2,phi2,snr2,rho,c,So2);
    %variables from function's inputs: freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press
    save(strcat(filename,'_mic_raw.mat'),'freqs','attens','So1','gain1','type1','gain2','type2','temp','humid','press','Fs','pv_usb_samp_rate','ramp','pre','len','post','nreps','snr_crit','shift','highpass','lowpass','winsor','mic_clip','time','in1','in2','rho','c');
end

%calibrate_mic_plot(freqs,attens,type1,type2,mic_clip,snr_crit,in1,in2,amp1,phi1,snr1,amp2,phi2,snr2,rho,c,So2);




    function selcbk(source,eventdata)
        %global but_accept but_reject;
        
        if(strcmp(get(eventdata.NewValue,'string'),'query'))
            set(but_accept,'visible','on');
            set(but_reject,'visible','on');
        else
            set(but_accept,'visible','off');
            set(but_reject,'visible','off');
        end
    end

    function clear_pv_mic_buffer(src, event)
        read(pv_usb_mic.SerialPortObject,floor(pv_buffer_clear_thres/2),"int16");
    end
end