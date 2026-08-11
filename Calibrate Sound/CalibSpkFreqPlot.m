function CalibSpkFreqPlot(varargin)

if(nargin==10)
  mic_clip      =varargin{1};
  calib_freqs   =varargin{2};
  calib_high    =varargin{3};
  calib_zero    =varargin{4};
  raw_high      =varargin{5};
  raw_zero      =varargin{6};
  thdn_high     =varargin{7};
  thdn_zero     =varargin{8};
  clip_high     =varargin{9};
  clip_zero     =varargin{10};
elseif(nargin==1)
  load([varargin{1} '_spkfreq']);
  %filename=[varargin{1} '_spk.m'];
  %load_as_text;
  %%run(filename);
  if(exist('mic_clip')~=1)
    mic_clip=2;
  end
else
  error('bad input arguments');
end

figure;
plot(calib_freqs,calib_high,'r.-');  hold on;
plot(calib_freqs,calib_zero,'k.-');
v=axis;  axis([min(calib_freqs) max(calib_freqs) v(3) v(4)]);
xlabel('frequency (Hz)');
ylabel('amplitude (dB)');
grid on;
if(nargin==1)
  title(strrep(varargin{1},'_',' '));
end

figure;
plot(calib_freqs,thdn_high,'r.-');  hold on;
plot(calib_freqs,thdn_zero,'k.-');
plot(calib_freqs,clip_high,'r.--');
plot(calib_freqs,clip_zero,'k.--');
v=axis;  axis([min(calib_freqs) max(calib_freqs) v(3) v(4)]);
xlabel('frequency (Hz)');
ylabel('THD+N, clip (%)');
grid on;
if(nargin==1)
  title(strrep(varargin{1},'_',' '));
end

figure;
for(i=1:length(calib_freqs))
  subplot('position',[0   (i-1)/length(calib_freqs) 0.5 1/length(calib_freqs)]);
  if((max(raw_high(i,:))>mic_clip)|(min(raw_high(i,:))<-mic_clip))
    disp(['WARNING:  ' num2str(calib_freqs(i)) ' Hz is clipped for high reading.']);
  end
  plot(raw_high(i,:));
  text(0,0,num2str(round(thdn_high(i))));
  axis off;
  subplot('position',[0.5 (i-1)/length(calib_freqs) 0.5 1/length(calib_freqs)]);
  if((max(raw_zero(i,:))>mic_clip)|(min(raw_zero(i,:))<-mic_clip))
    disp(['WARNING:  ' num2str(calib_freqs(i)) ' Hz is clipped for zero reading.']);
  end
  plot(raw_zero(i,:));
  text(0,0,num2str(round(thdn_zero(i))));
  axis off;
end
