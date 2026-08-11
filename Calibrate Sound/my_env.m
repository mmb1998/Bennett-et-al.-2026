function out=my_env(in,type,parm1,parm2,Fs)

switch(type)
  case('trapezoid')  % parm1 = rise time in sec, parm2 = fall time in sec
    rtmp=round(parm1*Fs);
    ftmp=round(parm2*Fs);
    env=[(1:rtmp)./rtmp ones(1,length(in)-rtmp-ftmp) (ftmp:-1:1)./ftmp];
  case('cosine')  % parm1 = rise time in sec, parm2 = fall time in sec
    if((parm1==0) & (parm2==0))
      env=0.5+0.5*cos((1:length(in))./length(in).*2.*pi-pi);
    else
      rtmp=floor(parm1*Fs);
      ftmp=floor(parm2*Fs);
      rtmp=0.5+0.5*cos((1:rtmp)./rtmp.*pi-pi);
      ftmp=0.5+0.5*cos((1:ftmp)./ftmp.*pi);
      env=[rtmp ones(1,length(in)-length(rtmp)-length(ftmp)) ftmp];
    end
  case('sine')  % parm1 = frequency in Hz
    env=0.5+0.5*sin(2*pi*parm1*(1:length(in))./Fs-pi/2);
  case('sineN')  % parm1 = frequency in Hz
    env=sin(pi*parm1*(1:length(in))./Fs);
  case('sineFWR')  % parm1 = frequency in Hz
    env=abs(sin(pi*parm1*(1:length(in))./Fs));
  case('sawtooth')  % parm1 = frequency in Hz, parm2 = the fractional 'width'
    env=0.5+0.5*sawtooth(2*pi*parm1*(1:length(in))./Fs,parm2);
  case('square')  % parm1 = frequency in Hz, parm2 = duty cycle in %, ramp fixed at 10ms
    env=    square(2*pi*parm1*(1:length(in))./Fs,parm2);
    env=env-square(2*pi*parm1*(1:length(in))./Fs-2*pi*0.01*parm1,parm2);
    env=cumsum(env);
    env=env./max(env);
end
out=in.*env;
