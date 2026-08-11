%function atten=calibrate_get(freq,amp,calib_freqs,calib_zero,calib_high,calib_low)
%
% calib_zero is the attenuator setting needed to give 0 dB at calib_freqs
% calib_high is the lowest attenuator setting _not_ causing distortion
% calib_low is the highest attenuator setting above the noise floor

function atten=calibrate_get(freq,amp,calib_freqs,calib_zero,calib_high,calib_low)

zero=interp1(calib_freqs,calib_zero,freq,'linear','extrap');
atten=round(10*(-amp+zero))/10;

if(atten<0)
  error(['TOO LOUD FOR PA5s.  max is ' num2str(-zero,'%.1f') ' dB SPL at ' num2str(round(freq)) ' Hz.']);
end

tmp=interp1(calib_freqs,calib_high,freq,'linear','extrap');
if(atten<round(10*tmp)/10)
  disp(['WARNING:  TOO LOUD FOR ACCEPTABLE DISTORTION.  max is ' num2str(zero-tmp,'%.1f') ' dB SPL at ' num2str(round(freq)) ' Hz.']);
end

if(atten>120)
  error(['TOO QUIET FOR PA5s.  min is ' num2str(zero-120,'%.1f') ' dB SPL at ' num2str(round(freq)) ' Hz.']);
end

if((freq<0.9*min(calib_freqs)) | (freq>1.1*max(calib_freqs)))
  disp('WARNING:  EXTRAPOLATING.  calib data only goes from %d to %d Hz.',min(calib_freqs),max(calib_freqs));
end
