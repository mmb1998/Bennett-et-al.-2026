function play_sound_pulse_song(stimulus, peak_pv)
Fs = 16000; %Hz

carrier_freq = 220; %hz, 220 Hz as in Zhou 2015
%assuming that peak pv of a gaussian pulse can be determined by its carrier
%frequency, is this true?

%calibrated pv-specific code
pv_per_v_mult = spk_freq_resp_pv(carrier_freq); 
if (peak_pv/pv_per_v_mult>1)
    error("Desired particle velocity exceeds sound system capability!");
end

%freqs = 160; %optimal sine song freq
pre=10; %s
len=10; %s, duration of sound delivery
post=15; %s
nreps=3;
amp = 0.173; %multiplier for daq output

stimulus_pre_delay = 13; %s
stimulus_length = 8; %s
stimulus_freq = 20; %Hz
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
    stimulus_data = repmat([zeros(1,size(stimulus_data,2)), stimulus_data], 1, nreps);
else
    stimulus_data = [];
end

y = (10*amp*peak_pv/pv_per_v_mult).*pulstran(0:1/Fs:len,0:0.035:len,'gauspuls',carrier_freq,0.9); %220 Hz as in Zhou 2015
out=[zeros(1,round(pre*Fs)), y, zeros(1,round(post*Fs))];
if stimulus == true
    out=repmat(out,1,nreps*2);
else
    out=repmat(out,1,nreps);
end
    
nidaq_queue_sound_data(session, nidaq_model, stimulus, out, stimulus_data);

startForeground(session);
end