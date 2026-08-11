function [amp1 phi1 thdn1 clip1 amp2 phi2 thdn2 clip2]=CalibFit_pv2pv(in1,in2,idx,idx2,freq,winsor,phi_comp,mic_clip,type1,type2)
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

if strcmp(type1,'pv') || strcmp(type1,'p')
    [amp1,phi1]=fit_sin(in1(idx),freq,Fs);
    F1=amp1*cos(2*pi*freq*(1:length(idx))'/Fs+phi1);
elseif strcmp(type1,'pvusb')
    [amp1,phi1]=fit_sin(in1(idx),freq,pv_usb_samp_rate);
    F1=amp1*cos(2*pi*freq*(1:length(idx))'/pv_usb_samp_rate+phi1);
end
if(~isempty(in2))
  if strcmp(type1,'pv') || strcmp(type1,'p')
    [amp2, phi2]=fit_sin(in2(idx2),freq,Fs);
    F2=amp2*cos(2*pi*freq*(1:length(idx2))'/Fs+phi2);
  elseif strcmp(type2,'pvusb')
    [amp2, phi2]=fit_sin(in2(idx2),freq,pv_usb_samp_rate);
    F2=amp2*cos(2*pi*freq*(1:length(idx2))'/pv_usb_samp_rate+phi2);
  end
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