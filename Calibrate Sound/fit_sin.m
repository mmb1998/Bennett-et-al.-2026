% function [amp,phi] = fit_sin(d,f,Fs)
%
% given vector d, frequency f (Hz), and sampling rate Fs (ticks/sec),
% fit a sinewave of frequency f to d and return the amplitude (ticks)
% and phase (radians).

function [amp,phi] = fit_sin(d,f,Fs)

d=squeeze(d);
if(size(d,1)>1)  d=d';  end

d=d-mean(d);

period = Fs/f;
last = floor(period * floor(length(d)/period));

real = mean(d(1:last) .* sin([1:last]*(2*pi/period)));
imag = mean(d(1:last) .* cos([1:last]*(2*pi/period)));

amp = 2*abs(real + i*imag);
phi = angle(real + i*imag);
