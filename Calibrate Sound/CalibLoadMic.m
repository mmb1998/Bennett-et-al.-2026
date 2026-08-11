%function [sensitivity reference]=CalibLoadMic(arg);
%
%sensitivity=[freq mag phi]

function [sensitivity reference]=CalibLoadMic(arg);

if(isnumeric(arg))
  sensitivity=[1 100000; arg/1000 arg/1000; 0 0]';
  reference=20e-6;  %Pa
else
  if(exist([arg '_mic.m'])==2)
    freqs=[];
    filename=[arg '_mic.m'];
    load_as_text;
    sensitivity=[freqs' So2(:,1) unwrap(So2(:,3))];
    reference=20e-6/1.2/343;  %m/s
  else
    error('_mic file not found.');
  end
end
