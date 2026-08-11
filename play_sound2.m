function play_sound2(freqs, pvs)
Fs = 16000;
pv_per_v_mult = spk_freq_resp_pv(freqs); 
if any(max(pvs)./pv_per_v_mult>1)
    error("Desired particle velocity exceeds sound system capability!");
end

ramp = 0.5;
start_time = 10;              % Start after 10 seconds
first_wave_length = 30;      % Length of the first sine wave
pause_length = 25;           % Length of the pause
second_wave_length = 10;     % Length of the second sine wave
nreps=1;
amp = 0.173; %multiplier for daq output




out = [];
total_length = start_time + first_wave_length + pause_length + second_wave_length; % Total length of the signal
temp_sine_1 = 10 .* my_env(sin(2 * pi * freqs * (1:round(first_wave_length * Fs)) / Fs), 'cosine', ramp, ramp, Fs);
temp_sine_2 = 10 .* my_env(sin(2 * pi * freqs * (1:round(second_wave_length * Fs)) / Fs), 'cosine', ramp, ramp, Fs);
temp_out = zeros(1, round(total_length * Fs));
temp_out(round(start_time * Fs) + (1:length(temp_sine_1))) = temp_sine_1;
temp_out(round((start_time + first_wave_length + pause_length) * Fs) + (1:length(temp_sine_2))) = temp_sine_2;
for k = 1:length(pvs)
    temp_out_scaled = (pvs(k) / pv_per_v_mult(1)) .* temp_out;  % Scale the amplitude
end
out = [out, repmat(temp_out_scaled, 1, nreps)];
out = out.*amp;

nidaq_queue_sound_data(session, nidaq_model, stimulus, out, stimulus_data);

startForeground(session);

end