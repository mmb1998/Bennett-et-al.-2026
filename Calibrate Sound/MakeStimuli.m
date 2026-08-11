function MakeStimuli(song_file, ...
    microphone_calibration_file, speaker_calibration_file, tau, medianfiltN)

% generate a calibrated stimulus from either a recording or synthetic
% stimulus.  optionally create a noise stimulus whose envelope matches that
% of the stimulus.
%
% if microphone_calibration_file is not empty it is used to convert
% song_file from volts to particle velocity.  otherwise, song_file is taken
% to be the desired particle velocity.  in either case,
% speaker_calibration_file is used to convert from particle velocity to
% volts.
%
% tau, if not empty, specifies the time constant in seconds over which the
% noise stimulus tracks the amplitude modulations of song_file
%
% medianfiltN if not empty applies a median filter of order medianfiltN to
% the calibration data before using them to compensate for the transfer
% functions


mic_amplifier_gain=1000;

[song,fs,nbits]=wavread(song_file);
SONG=fft(song);
SONG_MAG=abs(SONG);
SONG_PHI=angle(SONG);
nfft=length(song);
if(rem(nfft,2))  % odd
  tmp=(1:(nfft+1)/2);
  f=(tmp-1)*fs/nfft;
  f=[f f(end:-1:2)];
else
  tmp=(1:nfft/2+1);
  f=(tmp-1)*fs/nfft;
  f=[f f((end-1):-1:2)];
end
f=f';
idxF=find((f<57) | (f>1000));  % untrustworthy region of calibration

% V to m/s
if ~isempty(microphone_calibration_file)
  [sensitivity ~]=CalibLoadMic(microphone_calibration_file);
  mic_calib_mag=interp1(sensitivity(:,1),sensitivity(:,2),f,'linear',1);
  mic_calib_mag=medfilt1(mic_calib_mag,medianfiltN);
  mic_calib_phi=interp1(sensitivity(:,1),unwrap(sensitivity(:,3)),f,'linear',3*2*pi/4);
  SONG_MAG=SONG_MAG./mic_calib_mag./mic_amplifier_gain;
  SONG_MAG(idxF)=0;
  SONG_PHI=SONG_PHI-(mic_calib_phi-3*2*pi/4);
end

% % scale
% SONG_M_PER_S=SONG_MAG.*(cos(SONG_PHI)+sqrt(-1).*sin(SONG_PHI));
% song_m_per_s=ifft(SONG_M_PER_S,'symmetric');
% %[ss,sf,st,sp]=spectrogram(song_m_per_s,hamming(1024),[],[],fs);
% %scale = prctile(reshape(sp,1,numel(sp)),99) / 0.05e-3;
% %scale=max(abs(song_m_per_s))/0.05e-3;
% scale=10;
% SONG_MAG=SONG_MAG/scale;

% noise
if ~isempty(tau)
  NOISE_MAG=ones(length(SONG_M_PER_S),1);
  NOISE_MAG(idxF)=0;
  NOISE_PHI=2*pi*rand(length(SONG_M_PER_S),1);
  if(rem(nfft,2))  % odd
    NOISE_PHI(end:-1:((end+1)/2+1))=NOISE_PHI(2:((end+1)/2));
  else
    NOISE_PHI(end:-1:(end/2+2))=NOISE_PHI(2:(end/2));
  end
  SONG_M_PER_S=SONG_MAG.*(cos(SONG_PHI)+sqrt(-1).*sin(SONG_PHI));
  song_m_per_s=ifft(SONG_M_PER_S,'symmetric');
  NOISE_M_PER_S=NOISE_MAG.*(cos(NOISE_PHI)+sqrt(-1)*sin(NOISE_PHI));
  noise_m_per_s=ifft(NOISE_M_PER_S,'symmetric');
  noise_m_per_s=noise_m_per_s-mean(noise_m_per_s);
  noise_m_per_s=noise_m_per_s./sqrt(mean(noise_m_per_s.^2));
  window=ones(round(tau*fs),1);
  rms=sqrt( conv(song_m_per_s.^2,window,'same') ./ conv(ones(length(song_m_per_s),1),window,'same') );
  noise_m_per_s=rms.*noise_m_per_s;
  NOISE=fft(noise_m_per_s);
  NOISE_MAG=abs(NOISE);
%   NOISE_MAG=NOISE_MAG/scale;
  NOISE_PHI=angle(NOISE);
end

% m/s to V
[calib_freq,calib_mag,calib_phi]=CalibLoadSpk(speaker_calibration_file);
spk_calib_mag=interp1(calib_freq,calib_mag,f,'linear',1);
spk_calib_mag=medfilt1(spk_calib_mag,medianfiltN);
spk_calib_phi=interp1(calib_freq,unwrap(calib_phi),f,'linear',0);
find(isnan(spk_calib_phi));  spk_calib_phi(ans)=0;
SONG_MAG=SONG_MAG./spk_calib_mag;
SONG_MAG(idxF)=0;
SONG_PHI=SONG_PHI-spk_calib_phi;
if ~isempty(tau)
  NOISE_MAG=NOISE_MAG./spk_calib_mag;
  NOISE_MAG(idxF)=0;
  NOISE_PHI=NOISE_PHI-spk_calib_phi;
end

SONG_OUT=SONG_MAG.*(cos(SONG_PHI)+sqrt(-1)*sin(SONG_PHI));
song_out=ifft(SONG_OUT,'symmetric');
if ~isempty(tau)
  NOISE_OUT=NOISE_MAG.*(cos(NOISE_PHI)+sqrt(-1)*sin(NOISE_PHI));
  noise_out=ifft(NOISE_OUT,'symmetric');
end

% max(abs(song_out))
% max(abs(noise_out))

[p,n,e]=fileparts(song_file);
wavwrite(song_out,fs,nbits,fullfile(p,[n '_calib' e]));
if ~isempty(tau)
  wavwrite(noise_out,fs,nbits,fullfile(p,[n '_noise_calib' e]));
end
