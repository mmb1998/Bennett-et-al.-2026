function CalibSpkFreqNoisePlot(varargin)

if(nargin==5)
  calib_freq  =varargin{1};
  calib_mag   =varargin{2};
  calib_phi   =varargin{3};
  clip        =varargin{4};
  coh         =varargin{5};
elseif(nargin==1)
  load([varargin{1} '_spkfreqnoise']);
  %filename=[varargin{1} '_spk.m'];
  %load_as_text;
  %%run(filename);
%  if(exist('mic_clip')~=1)
%    mic_clip=2;
%  end
else
  error('bad input arguments');
end

figure;
plot(calib_freq,20*log10(calib_mag),'k-');
v=axis;  axis([min(calib_freq) max(calib_freq) v(3) v(4)]);
xlabel('frequency (Hz)');
ylabel('(m/s) / V (dB)');
grid on;
if(nargin==1)
  title(strrep(varargin{1},'_',' '));
end

figure;
plot(calib_freq,coh,'k-');
v=axis;  axis([min(calib_freq) max(calib_freq) v(3) v(4)]);
xlabel('frequency (Hz)');
ylabel('coherence (%)');
title([num2str(clip,3) '% clipping']);
grid on;
if(nargin==1)
  title(strrep(varargin{1},'_',' '));
end
