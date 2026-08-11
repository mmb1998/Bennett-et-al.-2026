% function [amp,phi] = fit_sin(d,f,Fs)
%
% given vector d, frequency f (Hz), and sampling rate Fs (ticks/sec),
% fit a sinewave of frequency f to d and return the amplitude (ticks)
% and phase (radians).

function [amp,phi,sample_rate] = fit_sin_approx(d,f,Fs)

d=squeeze(d);
if(size(d,1)>1)  d=d';  end

d=d-mean(d);

period = Fs/f;

actual_period = diff(find(diff(sign(d)))); %find zero crossings
t = sum(actual_period);
actual_period = actual_period(actual_period <= period*1.25/2 & actual_period >= period*0.75/2); %tolerance of 25% from the supplied period to try exclude 'false crossings' from dirty data
actual_period = t/(length(actual_period)/2); %find actual number of complete sine cycles and calculate period from it
sample_rate = actual_period*f;
if (sample_rate > Fs*1.01 || sample_rate < Fs*0.99 ) %1% tolerance on actual sampling freq
    warning("Sampling frequency calculated from fit_sin_approx more than 1% different from given sampling frequency");
    if (sample_rate > Fs*1.1 || sample_rate < Fs*0.9 )
        period = actual_period;
    end
else
    period = actual_period;
end

last = floor(period * floor(length(d)/period));

real = mean(d(1:last) .* sin([1:last]*(2*pi/period)));
imag = mean(d(1:last) .* cos([1:last]*(2*pi/period)));

amp = 2*abs(real + i*imag);
phi = angle(real + i*imag);
