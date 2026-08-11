function AmbientTake(filename,nreps)

global Fs;

So_file='cmp3';
gain=1000;
hardware='ni';  % or 'tdt'
Fs=10000;
pre=0.5;
len=1;
post=0.5;
%ramp=0.05;
%isi=5;
mic_clip=0.1;
input_range=0.2;
output_range=1;

if(~isempty(filename))
  if(exist([filename '_ambient.mat'],'file'))
    error([filename ' already exists']);
  end
end

if strcmp(hardware,'ni')
  global BOARDS SESSION

  BOARDS=daq.getDevices;
  BOARDS=BOARDS(1);
  SESSION=daq.createSession('ni');
  SESSION.addAnalogInputChannel(BOARDS.ID,0,'voltage');
  SESSION.Channels(1).InputType='SingleEndedNonReferenced';
  SESSION.Channels(1).Range=[-input_range input_range];
  SESSION.addAnalogOutputChannel(BOARDS.ID,0,'voltage');
  SESSION.Channels(2).Range=[-output_range output_range];
  SESSION.Rate=Fs;
else
  global ZBUS RP2_1 RP2_2 PA5L PA5R;

  tdt_init('stereo_record_play25k.rcx','',97656.25/4);
end

if(~isempty(filename))
  if(exist([filename '_ambient.m'])>0)
    error([filename ' already exists']);
  end
end

disp(['estimated time = ' num2str(nreps*2*(pre+len+post)/60) ' min']);

%tdt_set_atten(120,120);
out=zeros(1,round(pre*Fs)+round(len*Fs)+round(post*Fs));
%out_idx=ceil((pre+2*ramp)*Fs):floor((pre+len-2*ramp)*Fs);
out_idx=ceil(pre*Fs):floor((pre+len)*Fs);

time=clock;

%tic;
for(i=1:nreps)
  disp(['rep=' num2str(i)]);
  %in(i,:)=tdt_record_play(1,length(out),out,out);
  [in(i,:) ~]=CalibPlay(out,out_idx,60,0,'L',[],[],mic_clip);

%  a=toc;  while(a<isi)  a=toc;  end;  tic;
%  if(a>1.1*isi)  disp(['isi=' num2str(a) 's']);  end
end

if strcmp(hardware,'ni')
else
  tdt_halt();
end

if(~isempty(filename))
  %save_as_text([filename '_ambient.m'],nreps,pre,len,post,ramp,isi,gain,So_file,Fs,time,in);
  save([filename '_ambient'],'nreps',...
      'So_file','gain','hardware','Fs','pre','len','post','mic_clip','input_range','output_range',...
      'time','in');
end

AmbientPlot(So_file, gain, Fs, pre, len, in);

if strcmp(hardware,'ni')
else
  tdt_halt;
end

