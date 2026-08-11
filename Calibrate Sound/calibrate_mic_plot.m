function calibrate_mic_plot(varargin)

if(nargin==17)
  freqs=varargin{1};
  attens=varargin{2};
  type1=varargin{3};
  type2=varargin{4};
  mic_clip=varargin{5};
  snr_crit=varargin{6};
  in1=varargin{7};
  in2=varargin{8};
  amp1=varargin{9};
  phi1=varargin{10};
  snr1=varargin{11};
  amp2=varargin{12};
  phi2=varargin{13};
  snr2=varargin{14};
  rho=varargin{15};
  c=varargin{16};
  So2=varargin{17};
elseif(nargin==1)
  filename=[varargin{1} '_mic.m'];
  load_as_text;
%  run([varargin{1} '_mic']);
  if(exist('ambient1')==1)
    attens=[120 attens];
    amp1=winsormean(amp1,0.2,3);  amp1=[nan*ones(1,length(freqs)); amp1];
    phi1=winsormean(phi1,0.2,3);  phi1=[nan*ones(1,length(freqs)); phi1];
    snr1=winsormean(snr1,0.2,3);  snr1=[nan*ones(1,length(freqs)); snr1];
    amp2=winsormean(amp2,0.2,3);  amp2=[nan*ones(1,length(freqs)); amp2];
    phi2=winsormean(phi2,0.2,3);  phi2=[nan*ones(1,length(freqs)); phi2];
    snr2=winsormean(snr2,0.2,3);  snr2=[nan*ones(1,length(freqs)); snr2];
  end
  if(exist('mic_clip')~=1)
    mic_clip=2;
  end
else
  error('bad input arguments');
end

%if type is 'pvusb' treat same as 'pv'--Han
if strcmp(type2,'pvusb') type2 = 'pv'; end

if(strcmp(type1,'p'))
  Po1=20e-6;    %Pa
elseif(strcmp(type1,'pv'))
  Po1=20e-6/(rho*c);  %m/s
else
  error('invalid mic1 type');
end

duphi1=unwrap(phi1,[],3)*180/pi;
duphi2=unwrap(phi2,[],3)*180/pi;

if(exist('in1')==1)
h=figure;
foo=get(h,'Position');
set(h,'Position',round(foo.*[1 0.25 1 2]));
tmp=sort(attens);  tmp=tmp(1);  idx=find(attens==tmp);
for(i=1:length(freqs))
  %subplot(length(freqs),2,2*i-1);
  subplot('position',[0.1 (length(freqs)-i)/(length(freqs)+1) 0.4 1/(length(freqs)+1)]);
  foo=mean(in1(idx,i,:));
  if(((max(in1(idx,i,:))-foo)>mic_clip)|((min(in1(idx,i,:))-foo)<-mic_clip))
    disp(['WARNING:  ' num2str(freqs(i)) ' Hz is clipped for high reading.']);
  end
  plot(squeeze(in1(idx,i,:)));
  ylabel([num2str(round(freqs(i))) ' Hz']);
  if(i==1)  title([num2str(tmp) ' dB']);  end
  if(i==length(freqs))  xlabel('time (tics)');  end
  axis tight;

  %subplot(length(freqs),2,2*i);
  subplot('position',[0.6 (length(freqs)-i)/(length(freqs)+1) 0.4 1/(length(freqs)+1)]);
  foo=mean(in2(idx,i,:));
  if(((max(in2(idx,i,:))-foo)>mic_clip)|((min(in2(idx,i,:))-foo)<-mic_clip))
    disp(['WARNING:  ' num2str(freqs(i)) ' Hz is clipped for zero reading.']);
  end
  plot(squeeze(in2(idx,i,:)));
  if(i==1)  title([num2str(tmp) ' dB']);  end
  if(i==length(freqs))  xlabel('time (tics)');  end
  axis tight;
end
end

if(length(freqs)<5)
  for(j=1:length(freqs))

figure;  clf;

if(attens(1)~=120) error();  end

idx=find(snr1(2:end,j)>snr_crit);
if(length(idx)>1)
  So1p=regress(20*log10(amp1(1+idx,j)/Po1),[attens(1+idx); ones(1,length(idx))]');
elseif(length(idx)==1)
  So1p=[(20*log10(amp1(1+idx,j)/Po1) / attens(1+idx)) 0];
else
  So1p=[nan nan];
end

max_att=max(attens(2:end));
min_att=min(attens(2:end));

subplot(3,2,1);  hold on;
plot(attens(2:end),20*log10(amp1(2:end,j)/Po1),'b.-');
plot([min_att max_att],[mean(20*log10(amp1(1,j)/Po1)) mean(20*log10(amp1(1,j)/Po1))],'r.-');
plot([min_att max_att],[min_att max_att].*So1p(1)+So1p(2),'k:');
ylabel('amp (dB SPL)');
title(['freq = ' num2str(freqs(j))]);
axis tight;

subplot(3,2,3);  hold on;
plot(attens(2:end),duphi1(2:end,j),'b.-');
if(length(idx)>1)
  bar=regress(duphi1(1+idx,j),[attens(1+idx); ones(1,length(idx))]');
elseif(length(idx)==1)
  bar=[0 duphi1(1+idx,j)];
else
  bar=[nan nan];
end
plot([min_att max_att],[min_att max_att].*bar(1)+bar(2),'k:');
ylabel('phi (deg)');
axis tight;

subplot(3,2,5);  hold on;
plot(attens(2:end),10*log10(snr1(2:end,j)),'b.-');
plot([min_att max_att],[10*log10(snr_crit) 10*log10(snr_crit)],'k:');
ylabel('SNR (dB)');
xlabel('atten (dB)');
axis tight;

if(~strcmp(type1,type2))
  if(strcmp(type2,'pv'))  tmp=rho*c;  end
  if(strcmp(type2,'p'))   tmp=1/(rho*c);  end
else
  tmp=1;
end
idx=find((snr1(2:end,j)>snr_crit) & (snr2(2:end,j)>snr_crit));
abscissa=log10(amp1(:,j)./tmp);
if(length(idx)>1)
  So2p=regress(log10(amp2(1+idx,j)),[abscissa(1+idx)'; ones(1,length(idx))]');
elseif(length(idx)==1)
  So2p=[(log10(amp2(1+idx,j)) / abscissa(1+idx)) 0];
else
  So2p=[nan nan];
end

max_absc=max(abscissa(2:end));
min_absc=min(abscissa(2:end));

subplot(3,2,2);  hold on;
plot(abscissa(2:end),log10(amp2(2:end,j)),'b.-');
plot([min_absc max_absc],[mean(log10(amp2(1,j))) mean(log10(amp2(1,j)))],'r.-');
plot([min_absc max_absc],[min_absc max_absc].*So2p(1)+So2p(2),'k:');
ylabel('log10(amp) (V)');
title(['So=' num2str(So2(j,1:2))]);
axis tight;

subplot(3,2,4);  hold on;
plot(abscissa(2:end),duphi2(2:end,j),'b.-');
if(length(idx)>1)
  tmp=regress(duphi2(1+idx,j),[abscissa(1+idx)'; ones(1,length(idx))]');
elseif(length(idx)==1)
  tmp=[0 duphi2(1+idx,j)];
else
  tmp=[nan nan];
end
plot([min_absc max_absc],[min_absc max_absc].*tmp(1)+tmp(2),'k:');
ylabel('phi (deg)');
axis tight;

subplot(3,2,6);  hold on;
plot(abscissa(2:end),10*log10(snr2(2:end,j)),'b.-');
plot([min_absc max_absc],[10*log10(snr_crit) 10*log10(snr_crit)],'k:');
ylabel('SNR (dB)');
if(strcmp(type2,'pv'))
  xlabel('log10(p. velocity) (m/s)');
elseif(strcmp(type2,'p'))
  xlabel('log10(pressure) (Pa)');
end
axis tight;

  end
end

if(length(freqs)>1)

figure;  clf;

subplot(3,2,1);
for(i=2:length(attens))
  idx=find(snr1(i,:)>snr_crit);
  if(length(idx)>3)
    semilogx(freqs(idx),20*log10(amp1(i,idx)/Po1),'b.-');  hold on;
  end
end
ylabel('amp (dB SPL)');
if(nargin==1)
  title(strrep(shortfilename(varargin{1}),'_',' '));
end
axis tight

subplot(3,2,3);
for(i=2:length(attens))
  idx=find(snr1(i,:)>snr_crit);
  if(length(idx)>3)
    semilogx(freqs(idx),duphi1(i,idx),'b.-');  hold on;
  end
end
ylabel('phi (deg)');
axis tight

subplot(3,2,5);
for(j=1:length(freqs))
  tmp(j)=sum(snr1(2:end,j)>snr_crit);
end
semilogx(freqs,tmp,'b.-');
ylabel('# SNR > crit');
xlabel('freq (Hz)');
axis tight

subplot(3,2,2);
semilogx(freqs,20*log10(So2(:,1)),'b.-');
ylabel('20*log10(So m)');
title(['mean So = ' num2str(nanmean(So2,1))]);
axis tight

subplot(3,2,4);
semilogx(freqs,unwrap(So2(:,3))*180/pi,'b.-');  hold on;
if(strcmp(type1,'p') & strcmp(type2,'pv'))
  semilogx([min(freqs) max(freqs)],[90 90],'k:');
end
ylabel('phi (deg)');
%semilogx(freqs,So2(:,2),'b.-');
%ylabel('So b');
axis tight

subplot(3,2,6);
tmp=[];
for(j=1:length(freqs))
  tmp(j)=sum((snr1(:,j)>snr_crit) & (snr2(:,j)>snr_crit));
end
semilogx(freqs,tmp,'b.-');
ylabel('# SNR > crit');
xlabel('freq (Hz)');
axis tight

end
