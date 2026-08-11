function CalibSpkAmpPlot(varargin)

if(nargin==12)
  freq    =varargin{1};
  attens  =varargin{2};
  So_file =varargin{3};
  gain    =varargin{4};
  Fs      =varargin{5};
  ramp    =varargin{6};
  pre     =varargin{7};
  len     =varargin{8};
  post    =varargin{9};
  shift   =varargin{10};
  mic_clip=varargin{11};
  raw     =varargin{12};
elseif(nargin==1)
  load([varargin{1} '_spkamp']);
  %filename=[varargin{1} '_spk.m'];
  %load_as_text;
  %%run(filename);
  if(exist('mic_clip')~=1)
    mic_clip=2;
  end
else
  error('bad input arguments');
end

winsor=0;

out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);

[So PVo]=CalibLoadMic(So_file);

So1=interp1(So(:,1),So(:,2),freq,'linear','extrap');
if((freq<min(So(:,1))) | (freq>max(So(:,1))))
  warning(['extrapolating So for ' num2str(freq) ' Hz from ' num2str(min(So(:,1))) ...
      ' Hz to ' num2str(max(So(:,1))) ' Hz dataset']);
end
for(i=1:length(attens))
  [amp(i),~,thdn(i),clip(i),~,~,~,~]=...
      CalibFit(squeeze(raw(i,:,:)),[],out_idx,freq,winsor,shift+2*ramp,mic_clip);
  %if(thdn_zero(i)>thdn_crit) warning('atten for zero results in high THD+N.');  end
  %atten_use=calib_high(i)+atten_step;
  %disp(['zero=' num2str(calib_zero(i))]);
end
calib=attens+20*log10(amp/gain/So1/PVo);

figure;
plot(attens,calib,'k.-');
%v=axis;  axis([min(calib_freqs) max(calib_freqs) v(3) v(4)]);
axis tight;
xlabel('attenuation (dB)');
ylabel('amplitude (dB)');
grid on;
if(nargin==1)
  title(strrep(varargin{1},'_',' '));
end

figure;
plot(attens,thdn,'k.-');  hold on;
plot(attens,clip,'k.--');
%v=axis;  axis([min(calib_freqs) max(calib_freqs) v(3) v(4)]);
axis tight;
xlabel('attenuation (dB)');
ylabel('THD+N, clip (%)');
grid on;
if(nargin==1)
  title(strrep(varargin{1},'_',' '));
end
