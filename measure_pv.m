%measure particle velocity using calibrated pv mic
function [test_freqs,test_attens,pv]=measure_pv(pv_calib_filename,test_freqs,test_attens,temp,humid,press)

if(~isempty(pv_calib_filename))
    if ~exist(strcat(pv_calib_filename,'.mat'),"file")
        error(strcat(pv_calib_filename,' does not exist'));
    else
        load(pv_calib_filename, '-mat', 'So2','freqs');
    end
else
    error('need to specify mat file for pv mic calibration data');
end

global Fs pv_usb_samp_rate SESSION pv_usb_mic; %Fs = B&K mic & speaker output sampling frequency
Fs = 16000; %Hz
pv_usb_samp_rate = 7000; %Hz, need to be 1000-8000 Hz & multiple of 1000
pv_usb_port = "COM6"; %check with serialportlist()
nidaq_device = "Dev2"; %change to device name
nidaq_ai_channel = "ai0"; %this is here just to reuse CalibPlay, will ignore
nidaq_ai_channel2 = "ai1"; %not used
nidaq_ao_channel = "ao1";

%create NIDAQ session
SESSION = daq.createSession("ni");
addAnalogInputChannel(SESSION, nidaq_device, nidaq_ai_channel, "Voltage");
addAnalogOutputChannel(SESSION, nidaq_device, nidaq_ao_channel, "Voltage");
SESSION.Rate = Fs;

PA5R=[];

if(sum((test_attens>120)|(test_attens<0))>0)
    disp('ERROR: some amps are not between 0 and 120 dB');
    return;
end

if(max(test_freqs)>(Fs/2)) || max(test_freqs)> pv_usb_samp_rate/2
    disp('ERROR: freq is greater than the Nyquist frequency');
    return;
end

%create PV USB mic instance
pv_usb_samp_rate = round(pv_usb_samp_rate, -3);
pv_usb_mic = PvMicUSB(pv_usb_port,pv_usb_samp_rate);
pv_usb_mic.On();

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

test_attens=[120 test_attens]; %if attens is 120, play no sound

disp(['estimated time = ' num2str(nreps*length(test_freqs)*length(test_attens)*2*(pre+len+post)/60) ' min']);

time=clock;

%ignore in1
in1=zeros(length(test_attens),length(test_freqs),nreps,round(pre*Fs)+round(len*Fs)+round(post*Fs));
in2=zeros(length(test_attens),length(test_freqs),nreps,round(pre*pv_usb_samp_rate)+round(len*pv_usb_samp_rate)+round(post*pv_usb_samp_rate));


out_idx=ceil((shift+pre+2*ramp+0.25*len)*Fs):floor((shift+pre+len-2*ramp-0.25*len)*Fs); %more wiggle room for software timed input (for pv usb mic)
out_idx2=ceil((shift+pre+2*ramp+0.25*len)*pv_usb_samp_rate):floor((shift+pre+len-2*ramp-0.25*len)*pv_usb_samp_rate);


for(j=1:length(test_freqs))
    for(k=1:nreps)
        disp(['rep=' num2str(k)]);
        disp(['freq=' num2str(round(test_freqs(j)))]);
        out=10.*my_env(sin(2*pi*test_freqs(j)*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs); %convert freq to radians per sec, then multiply with an array of time points (from sampling frequency)
        out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];
        
        foo=zeros(1,length(out)); %blank output for atten = 120
        i=1;
        while(i<=length(test_attens))
            if(test_attens(i)==120) %if attens is 120, play no sound
                %[in1(i,j,k,:) in2(i,j,k,:)]=calibrate_play(foo,out_idx,freqs(j),attens(i),'L',highpass,lowpass,mic_clip);
                [in1(i,j,k,:) in2(i,j,k,:)]=CalibPlay(foo,out_idx,test_freqs(j),test_attens(i),'L',highpass,lowpass,mic_clip,out_idx2);
            else
                [in1(i,j,k,:) in2(i,j,k,:)]=CalibPlay(out,out_idx,test_freqs(j),test_attens(i),'L',highpass,lowpass,mic_clip,out_idx2);
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

pv_usb_mic.delete();

%first calculate 'correct' pv_usb_sample rate from highest amplitude and
%highest frequency recordings,
%since it deviates slightly from expected
%now change to fit all freqs >100 Hz and max amplitude <= 0.8 & >=0.02 (avoid distorted/clipped recordings & weak recordings)
%est_pv_usb_sample_rate = zeros(nreps, 1);
est_pv_usb_sample_rate = 0;
counter = 1;
for(j=1:length(test_freqs))
    if test_freqs(j) > 100
        for k = 1:nreps
            for(i=1:length(test_attens))
                if test_attens(i) < 120 && max(in2(i, j, k, out_idx2)) <= 0.8 && max(in2(i, j, k, out_idx2)) >= 0.02
                    [~, ~, est_pv_usb_sample_rate(counter)] = fit_sin_approx(squeeze(in2(i, j, k, out_idx2)), test_freqs(j), pv_usb_samp_rate);
                    counter = counter+1;
                end
            end
        end
    end
end
if (counter == 1) error("Cannot estimate pv sample rate as there were no pv readings within reasonable range"); end
pv_usb_samp_rate = mean(est_pv_usb_sample_rate);
%for PV USB mic, calculate individually for each replicate
for k = 1:nreps
    for(j=1:length(test_freqs))
        for(i=1:length(test_attens))
            %CalibFit currently only works for PV USB!!
            [~, ~, ~, ~, amp2(i,j,k), phi2(i,j,k), snr2(i,j,k), ~]=CalibFit(squeeze(in1(i,j,k,:)),squeeze(in2(i,j,k,:)),out_idx,out_idx2,test_freqs(j),winsor,shift+2*ramp,mic_clip);
        end
    end
end

amp2 = squeeze(mean(amp2, 3));
snr2 = squeeze(mean(snr2, 3));
%phi2 = squeeze(mean(phi2, 3));  %this is not meaningful (as PV USB is software timed) but necessary for calibrate_mic_plot to function

%currently temp, humidity and pressure arent actually used to adjust
%readings
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

% if(~strcmp(type1,type2))
%     if(strcmp(type2,'pv')) || strcmp(type2,'pvusb')  su=rho*c;  end
%     if(strcmp(type2,'p'))   su=1/(rho*c);  end
% else
%     su=1;
% end

%code below calculates pv from second mic readings
pv=zeros(length(test_attens)-1,length(test_freqs));
for(j=1:length(test_freqs))
  idx=find(snr2(2:end,j)>snr_crit); %find indices for all non-zero attens that are above snr_crit
  if(length(idx)>1)
    pv(:,j)= amp2(1+idx,j)/interp1(freqs, So2(:,1), test_freqs(j), 'makima', 'extrap'); %divide amplitude by mic sensitivity to get pv in m/s
  elseif(length(idx)==1)
    pv(1,j)= amp2(1+idx,j)/interp1(freqs, So2(:,1), test_freqs(j), 'makima', 'extrap'); %divide amplitude by mic sensitivity to get pv in m/s
  else
    pv(1,j)=nan;
  end
end


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