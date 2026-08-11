%function [max_a max_d min_a]=calibrate_limits(varargin)
%
%[max_a max_d min_a]=calibrate_limits(freqs,filename)

function [max_a max_d min_a]=calibrate_limits(varargin)

if(nargin==4)
  freqs=varargin{1};
  calib_freqs=varargin{2};
  calib_zero=varargin{3};
  calib_high=varargin{4};
elseif(nargin==2)
  freqs=varargin{1};
  if(exist([varargin{2} '_spk.m'])==2)
    run([varargin{2} '_spk']);
  elseif(exist([varargin{2} '_cal.m'])==2)
    run([varargin{2} '_cal']);
  else
    warning([varargin{2} ' not found']);
    max_a=[];  max_d=[];  min_a=[]; 
    return;
  end
else
  error('bad input arguments');
end

if(isempty(freqs))
  freqs=calib_freqs;
end

zero=interp1(calib_freqs,calib_zero,freqs,'linear','extrap');
high=interp1(calib_freqs,calib_high,freqs,'linear','extrap');

max_a=floor(10*zero)/10;
max_d=floor(10*(zero-high))/10;
min_a=ceil(10*(zero-120))/10;

if(nargout==0)
  disp('for the frequencies specified,');
  disp(['  max achievable intensity = ' num2str(min(max_a))]);
  disp(['  max distortion-free intensity = ' num2str(min(max_d))]);
  disp(['  min achievable intensity = ' num2str(max(min_a))]);
end
