function play_sound_arbitrary(wavefile,stimulus)
Fs = 16000; %Hz

[session, nidaq_model] = nidaq_setup(Fs, stimulus);

nreps = 1;

stimulus_pre_delay = 13; %s
stimulus_length = 8; %s
stimulus_freq = 20; %Hz
stimulus_duty_cycle = 0.1; %fraction

%stim and reps dont function yet
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

[y, file_Fs] = audioread(wavefile);
y = 10.*resample(y(:,1), Fs, file_Fs);
%out=10.*my_env(sin(2*pi*freqs*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
out = 10.*(y')/max(y); %only take left channel and normalize

nidaq_queue_sound_data(session, nidaq_model, stimulus, out, stimulus_data);

startForeground(session);

end