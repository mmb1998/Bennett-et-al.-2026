000000000000000000000000000000000function nidaq_queue_sound_data(session, nidaq_model, opto_stim, sound_data, stimulus_data)
if opto_stim == true
    if isempty(stimulus_data) 
        error("must supply stimulus data if opto_stim is true") 
    end 
end

if strcmp(nidaq_model, "USB-6211")
    if opto_stim == true
        all_out_data = [sound_data', 5.*stimulus_data']; %assume stimulus_data is digital pulses with max of 1, but we are outputting on analog channel with max voltage of 5
    else
        all_out_data = sound_data';
    end
else
    start_trigger_data = ones(1, min(1000, size(sound_data, 2)));
    start_trigger_data = [start_trigger_data, zeros(1, size(sound_data, 2) - size(start_trigger_data,2))];
    if opto_stim == true
        all_out_data = [sound_data', start_trigger_data', stimulus_data'];
    else
        all_out_data = [sound_data', start_trigger_data'];
    end
end

queueOutputData(session,all_out_data)
session