function [session, nidaq_model] = nidaq_setup(nidaq_samp_rate, opto_stim)

%assume nidaq_config.txt is in the same folder as this function
[setup_data, ~, ~] = fileparts(mfilename("fullpath"));
setup_data = readtable(fullfile(setup_data, "nidaq_config usb-6211.txt"), ...
    delimitedTextImportOptions('Delimiter', ' = '), 'ReadRowNames', true, 'ReadVariableNames', false);
nidaq_model = string(setup_data{"nidaq_model", 2});
nidaq_device = string(setup_data{"nidaq_device", 2});
nidaq_ao_channel = string(setup_data{"nidaq_ao_channel", 2}); %sound generation
nidaq_do_channel_start = string(setup_data{"nidaq_do_channel_start", 2}); %imaging acquisition start trigger
nidaq_do_channel_stimulus = string(setup_data{"nidaq_do_channel_stimulus", 2}); %opto stim
nidaq_external_trig = string(setup_data{"nidaq_external_trig", 2}); %TRUE/FALSE whether to wait for external trigger
nidaq_di_channel_trig = string(setup_data{"nidaq_di_channel_trig", 2}); %channel for external trigger

session = daq.createSession("ni");
addAnalogOutputChannel(session, nidaq_device, nidaq_ao_channel, "Voltage");
if strcmpi(nidaq_model, 'USB-6211')
    addCounterOutputChannel(session, nidaq_device, nidaq_do_channel_start,"PulseGeneration");
else
    addDigitalChannel(session, nidaq_device, nidaq_do_channel_start, "OutputOnly");
end
if opto_stim == true
    if strcmpi(nidaq_model, 'USB-6211')
        addAnalogOutputChannel(session, nidaq_device, nidaq_do_channel_stimulus, "Voltage");
    else
        addDigitalChannel(session, nidaq_device, nidaq_do_channel_stimulus, "OutputOnly");
    end
end
if strcmpi(nidaq_external_trig, 'TRUE')
    addTriggerConnection(session,'external',nidaq_device+'/'+nidaq_di_channel_trig,'StartTrigger');
    session.ExternalTriggerTimeout = 300; %s
    disp("Device "+nidaq_device+" will wait for trigger input on channel "+nidaq_di_channel_trig);
end

session.Rate = nidaq_samp_rate;