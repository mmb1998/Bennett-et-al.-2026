function AmbientPlot(varargin)

if(nargin==6)
  So_file =varargin{1};
  gain    =varargin{2};
  Fs      =varargin{3};
  pre     =varargin{4};
  len     =varargin{5};
  in      =varargin{6};
elseif(nargin==2)
  load([varargin{1} '_ambient']);
  %tmp=filename;
  %filename=[filename '_ambient.m'];
  %load_as_text;
  %filename =strrep(shortfilename(tmp),'_',' ');
  freqs=varargin{2};
else
  error('bad input arguments');
end

if((exist('freqs')~=1) || (isempty(freqs)))
  freqs=60;
end

winsor=0;

[So PVo]=CalibLoadMic(So_file);
%[So PVo]=calibrate_load_mic(['/Volumes/data_hd/Users/bja/data/mosquito/phys2/' So_file]);

%in=in./gain;
%idx=ceil((pre+ramp)*Fs):floor((pre+len/4-ramp)*Fs);
idx=ceil(pre*Fs):floor((pre+len)*Fs);

figure;

subplot(2,1,1);  hold on;

for(i=1:length(freqs))
  So1=interp1(So(:,1),So(:,2),freqs(i),'linear','extrap');
  if((freqs(i)<min(So(:,1))) | (freqs(i)>max(So(:,1))))
    warning(['extrapolating So for ' num2str(freq) ' Hz from ' num2str(min(So(:,1))) ...
        ' Hz to ' num2str(max(So(:,1))) ' Hz dataset']);
  end
  for(j=1:size(in,1))
    fit_cos(in(j,idx),freqs(i),Fs);
    (ans/gain/So1/PVo)^2;
    IN(i,j)=20*log10(ans);
  end
end

IN(:,end+1)=winsormean(IN,winsor,2);
IN(:,end+1)=winsorerr(IN,winsor,2);

plot(freqs,IN(:,end-1),'k.-');
%errorbar(freqs,IN(:,end-1),IN(:,end),'k.-','markersize',18);
%errorbarlogx(0.01);
%set(gca,'xscale','log');
xlabel('frequency (Hz)');
ylabel('amplitude (dB)');
%title(filename);
axis tight;
grid


subplot(2,1,2);  hold on;

[pab f]=my_pwelch(in(:,idx),length(idx),Fs);
So1=interp1(So(:,1),So(:,2),f,'linear','extrap');
find(So1<=0);  So1(ans)=nan;
pab=pab/gain./repmat(So1,size(pab,1),1)/PVo;
pxx=abs(pab).^2;  % hmm.... pxx=pab.*conj(pab);
%pxx_mean=winsormean(20*log10(pxx/mean(diff(f))./repmat(f,size(pxx,1),1)),winsor,1);
pxx_mean=winsormean(20*log10(pxx/mean(diff(f))),winsor,1);
plot(f(1:round(end/2)),pxx_mean(1:round(end/2)),'k-');
%set(gca,'xscale','log')
xlabel('frequency (Hz)');
ylabel('amplitude (dB)');
axis tight
