function play_sound(stimulus,freqs,pvs)
Fs = 16000; %Hz

%calibrated pv-specific code
pv_per_v_mult = spk_freq_resp_pv(freqs); 
if any(max(pvs)./pv_per_v_mult>1)
    error("Desired particle velocity exceeds sound system capability!");
end

ramp=0.05; %s, ramp for sound envelope
pre=10; %s
len=10; %s
post=15; %s
nreps=3;
amp = 0.173; %multiplier for daq output

stimulus_pre_delay = 0; %s
stimulus_length = 30; %s
stimulus_freq = 200; %Hz
stimulus_duty_cycle = 0.1; %fraction

[session, nidaq_model] = nidaq_setup(Fs, stimulus);

if stimulus == true
    stimulus_data = (square(2*pi*stimulus_freq.*(0:1/Fs:(stimulus_length-1/Fs)), stimulus_duty_cycle*100)+1)/2;
    if stimulus_pre_delay > 0
        stimulus_data = [zeros(1,round(stimulus_pre_delay*Fs)), stimulus_data];
    end
    out_idx = round(pre*Fs)+round(len*Fs)+round(post*Fs);
    %make length of stim data fit length of one rep of sound data
    if size(stimulus_data,2) > out_idx
        stimulus_data = [stimulus_data(1:(out_idx-1)); 0];
    else
        stimulus_data = [stimulus_data, zeros(1,out_idx-size(stimulus_data,2))];
    end
    %alternate with negative ctrl stim data (zeros) and repeat for
    %nreps--do no stim first then stim
    stimulus_data = repmat([zeros(1,size(stimulus_data,2)), stimulus_data], 1, nreps*length(freqs));
else
    stimulus_data = [];
end

out = [];
for j=1:length(freqs)
    temp_sine = 10.*my_env(sin(2*pi*freqs*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);%max of 10 volts
    for k=1:length(pvs)
        temp_out = (pvs(k)/pv_per_v_mult(j)).*temp_sine;
        temp_out=[zeros(1,round(pre*Fs)), temp_out, zeros(1,round(post*Fs))];
        if (stimulus)
            out = [out, repmat(temp_out, 1, nreps*2)];
        else
            out = [out, repmat(temp_out, 1, nreps)];
        end %if opto stimulus, repeat out for + and - red light
    end
end
out = out.*amp;

nidaq_queue_sound_data(session, nidaq_model, stimulus, out, stimulus_data);

startForeground(session);

end
