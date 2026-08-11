function [amp1 phi1 thdn1 clip1 amp2 phi2 thdn2 clip2]=CalibFit(in1,in2,idx,idx2,freq,winsor,phi_comp,mic_clip)
%need 2 indices as pv usb has different sample rate

global Fs pv_usb_samp_rate;

clip1=100*sum(sum(in1>mic_clip))./prod(size(in1));
%in1=winsormean(in1,winsor,1); %already inputting a single replicate, don't
%%need to do winsormean
in1=in1-mean(in1);
if(~isempty(in2))
  clip2=100*sum(sum(in1>mic_clip))./prod(size(in1));
  %in2=winsormean(in2,winsor,1);
  in2=in2-mean(in2);
else
  clip2=nan;
end

%[amp1 phi1]=fit_cos(in1(idx),freq,Fs);  %% used to be fit_sin
[amp1,phi1]=fit_sin(in1(idx),freq,Fs);
F1=amp1*cos(2*pi*freq*(1:length(idx))'/Fs+phi1);
if(~isempty(in2))
  %[amp2 phi2]=fit_cos(in2(idx),freq,Fs);
  %F2=amp2*cos(2*pi*freq*(1:length(idx))/Fs+phi2);
  [amp2 phi2]=fit_sin(in2(idx2),freq,pv_usb_samp_rate); %should check if pv usb mic is actually used
  F2=amp2*cos(2*pi*freq*(1:length(idx2))'/pv_usb_samp_rate+phi2);
else
  amp2=nan;  phi2=nan;
end

noise1=in1(idx)-F1;
%snr1=mean(F1.^2)/mean(noise1.^2);
thdn1=100*std(noise1)/std(F1); %total harmonic distortion + noise
if(~isempty(in2))
  noise2=in2(idx2)-F2;
  %snr2=mean(F2.^2)/mean(noise2.^2);
  thdn2=100*std(noise2)/std(F2);
else
  thdn2=nan;
end

phi1=phi1-phi_comp*2*pi.*freq;
if(~isempty(in2))
  phi2=phi2-phi_comp*2*pi.*freq;
end