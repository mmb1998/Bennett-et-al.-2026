function sound_startle_experiment_nidaq_ctrl(amp_mult, nreps, stimulus, delay_enable, filename)
if amp_mult> 1 || amp_mult<1
    warning("amp_mult needs to be between 0 and 1");
    if (amp_mult> 1)
        amp_mult = 1;
    else
        amp_mult = 0;
    end
end

global Fs;
Fs = 16000; %Hz

camera_trig_frame_rate = 200; %Hz
camera_nidaq_do_channel_trig = "port0/line2";

nidaq_device = "Dev2"; %change to device name
nidaq_ai_channel = "ai0"; %not used currently
nidaq_ao_channel = "ao0"; %sound generation
nidaq_do_channel_start = "port0/line1"; %imaging acquisition start trigger e.g. for triggering 2p acquisition
nidaq_do_channel_stimulus = "port0/line0"; %stimulus (e.g. red light for CsChrimson)
nidaq_samp_rate = Fs;
pv_mic_serial_port = "COM3"; %not used

%temporary furtherdelay
furtherdelay = 45;
%delay_enable = 1;

freqs = 300;
pre=30; %was 5
len=0.25; %duration of sound delivery, was 0.5
ramp=len/10; %was 0.05
post=0; %was 0.1
last= 60; %time to continue camera acquisition after last sound delivery
%nreps=1;
amp = 0.173*amp_mult; %multiplier for daq output, sound amp needs to be at this V or less (better to use a hardware attenuator?)

stimulus_pre_delay = 0;
stimulus_length = 60;




SESSION = daq.createSession("ni"); %these should be set in calibrate_mic instead
%addAnalogInputChannel(SESSION, nidaq_device, nidaq_ai_channel, "Voltage");
addAnalogOutputChannel(SESSION, nidaq_device, nidaq_ao_channel, "Voltage");
addDigitalChannel(SESSION, nidaq_device, nidaq_do_channel_start, "OutputOnly");
addDigitalChannel(SESSION, nidaq_device, camera_nidaq_do_channel_trig, "OutputOnly");

%sound signal
out=10.*my_env(sin(2*pi*freqs*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
%out=10.*sin(2*pi*freqs*(1:round(len*Fs))/Fs);
%max of 10 volts
out=[zeros(1,round(pre*Fs)), out, zeros(1,round(post*Fs))];
%out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);
%repeat signal given number of times
out = repmat(out, 1, nreps);
out= [out, zeros(1,round(last*Fs))];
out_idx = size(out, 2);

start_trigger_data = ones(1, floor(0.2*Fs));
start_trigger_data = [start_trigger_data, zeros(1, out_idx - size(start_trigger_data,2))];

camera_out = square(2*pi*camera_trig_frame_rate*((1/Fs):(1/Fs):(out_idx/Fs)));
camera_out = (camera_out+1)/2;

if stimulus == true
    addDigitalChannel(SESSION, nidaq_device, nidaq_do_channel_stimulus, "OutputOnly");
    if stimulus_pre_delay > 0
        stimulus_data = zeros(1,round(stimulus_pre_delay*Fs));
    else
        stimulus_data = [];
    end
    
    stim_idx = round(stimulus_length*Fs);
    if (stim_idx + size(stimulus_data,1)) > out_idx
        stimulus_data = [stimulus_data, ones(1, out_idx - size(stimulus_data,1) - 1), 0];
    else
        stimulus_data = [stimulus_data, ones(1,stim_idx), zeros(1,(out_idx - stim_idx - size(stimulus_data,1)))];
    end
end
    
%global SESSION pv_usb_mic;

%pv_mic = PvMicUSB(pv_mic_serial_port,8000);
%pv_mic.On();

in1 = [];

%out=out./(10^(atten/20));
%out=out.*0.174; %for now (testing, just scale output to max level possible for output to a +4 dbu amp
out = out.*amp; %0.005 for 100 Hz, 0.035 for 50 Hz
%preload(SESSION,transpose(out));

if delay_enable
    furtherdelay_data = zeros(1, round(furtherdelay*Fs));
    out = [furtherdelay_data, out];
    start_trigger_data = [furtherdelay_data, start_trigger_data];
    if stimulus == true
        %not entirely correct
        stimulus_data = [ones(1, size(out, 2) - 1), 0];
    end
end

if stimulus == true
    queueOutputData(SESSION,[out',start_trigger_data',camera_out',stimulus_data'])
else
    queueOutputData(SESSION,[out',start_trigger_data',camera_out'])
end
SESSION.Rate = nidaq_samp_rate
%session_listener = SESSION.addlistener('DataAvailable',@save_data);
%startBackground(SESSION);

disp('Starting experiment');
startForeground(SESSION);
disp('Done!');
save(strcat(filename,'_startle_metadata.mat'),'amp_mult','nreps','stimulus','delay_enable','freqs','len','pre','post','last','out','Fs','start_trigger_data','camera_trig_frame_rate','camera_out');

    function save_data(src, event)
        %plot(event.TimeStamps,event.Data)
        in1 = [in1;event.Data];
    end

end