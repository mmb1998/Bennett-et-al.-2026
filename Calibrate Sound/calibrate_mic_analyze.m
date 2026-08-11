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

function [freqs,So2]=calibrate_mic_analyze(filename)

%load the microphone calibration .mat file containing these variables: 
%'freqs','attens','So1','gain1','type1','gain2','type2','temp','humid',
%'press','Fs','pv_usb_samp_rate','ramp','pre','len','post','nreps',
%'snr_crit','shift','highpass','lowpass','winsor','mic_clip','time',
%'in1','in2','rho','c'

global Fs pv_usb_samp_rate;

load(filename, '-mat');

out_idx=ceil((shift+pre+2*ramp+0.25*len)*Fs):floor((shift+pre+len-2*ramp-0.25*len)*Fs);
if strcmp(type2,'pvusb')
    out_idx2=ceil((shift+pre+2*ramp+0.25*len)*pv_usb_samp_rate):floor((shift+pre+len-2*ramp-0.25*len)*pv_usb_samp_rate);
else
    out_idx2 = [];
end

%this doesnt work well for PV USB mics which are software timed
%in1=squeeze(winsormean(in1,winsor,3));
%in2=squeeze(winsormean(in2,winsor,3));

%for PV USB mic, calculate individually for each replicate
%first calculate 'correct' pv_usb_sample rate from highest amplitude and second highest frequency recordings,
%since it deviates slightly from expected
est_pv_usb_sample_rate = zeros(nreps, 1);
for k = 1:nreps
    [~, ~, est_pv_usb_sample_rate(k)] = fit_sin_approx(squeeze(in2(2, end-1, k, out_idx2)), freqs(end-1), pv_usb_samp_rate);
end
pv_usb_samp_rate = mean(est_pv_usb_sample_rate);
for k = 1:nreps
    for(j=1:length(freqs))
        for(i=1:length(attens))
            %%[amp1(i,j) phi1(i,j) snr1(i,j) amp2(i,j) phi2(i,j) snr2(i,j)]=calibrate_fit(squeeze(in1(i,j,:)),squeeze(in2(i,j,:)),out_idx,freqs(j),winsor,shift+2*ramp);
            %CalibFit currently only works for PV USB!!
            [amp1(i,j,k), phi1(i,j,k), snr1(i,j,k), ~, amp2(i,j,k), phi2(i,j,k), snr2(i,j,k), ~]=CalibFit(squeeze(in1(i,j,k,:)),squeeze(in2(i,j,k,:)),out_idx,out_idx2,freqs(j),winsor,shift+2*ramp,mic_clip);
            tmpMf=interp1(So1(:,1),So1(:,2),freqs(j),'linear','extrap');
            tmpPf=interp1(So1(:,1),So1(:,3),freqs(j),'linear','extrap');
            amp1(i,j,k)=amp1(i,j,k)/gain1/tmpMf;
            amp2(i,j,k)=amp2(i,j,k)/gain2;
            phi1(i,j,k)=mod(phi1(i,j,k)-tmpPf,2*pi);
        end
    end
end

amp1 = squeeze(mean(amp1, 3)); %this should take the mean over replicates (k), should check that it actually does that
amp2 = squeeze(mean(amp2, 3));
snr1 = squeeze(mean(snr1, 3));
snr2 = squeeze(mean(snr2, 3));
phi1 = squeeze(mean(phi1, 3));  %we don't care about phi
phi2 = squeeze(mean(phi2, 3));  %this is not meaningful (as PV USB is software timed) but necessary for calibrate_mic_plot to function

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
    %save_as_text([filename '_mic_raw.m'],freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press,Fs,ramp,pre,len,post,nreps,snr_crit,shift,highpass,lowpass,winsor,mic_clip,time,in1,in2,amp1,phi1,snr1,amp2,phi2,snr2,rho,c,So2);
    %variables from function's inputs: freqs,attens,So1,gain1,type1,gain2,type2,temp,humid,press
    save(strcat(filename,'_calibrated.mat'),'freqs','attens','So1','gain1','type1','So2','gain2','type2','temp','humid','press','Fs','pv_usb_samp_rate','ramp','pre','len','post','nreps','snr_crit','shift','highpass','lowpass','winsor','mic_clip','time','in1','in2','rho','c', 'amp1', 'amp2');
end

calibrate_mic_plot(freqs,attens,type1,type2,mic_clip,snr_crit,in1,in2,amp1,phi1,snr1,amp2,phi2,snr2,rho,c,So2);


end