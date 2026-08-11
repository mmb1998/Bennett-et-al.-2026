function play_sound(stimulus,delay_enable)
global Fs;
Fs = 16000; %Hz

%stimulus = false; %whether to stim or not
nidaq_device = "Dev2"; %change to device name
nidaq_ai_channel = "ai0"; %not used currently
nidaq_ao_channel = "ao0"; %sound generation
nidaq_do_channel_start = "ao1"; %imaging acquisition start trigger
nidaq_do_channel_stimulus = "port1/line0"; %stimulus (e.g. red light for CsChrimson)
nidaq_samp_rate = Fs;
pv_mic_serial_port = "COM3";

%temporary furtherdelay
furtherdelay = 45;
%delay_enable = 1;

freqs = 200;
ramp=0.05; %was 0.05
pre=15; %was 5
len=15; %duration of sound delivery, was 0.5
post=15; %was 0.1
nreps=1;
amp = 0.173; %multiplier for daq output

stimulus_pre_delay = 0;
stimulus_length = 60;


SESSION = daq.createSession("ni"); %these should be set in calibrate_mic instead
%addAnalogInputChannel(SESSION, nidaq_device, nidaq_ai_channel, "Voltage");
addAnalogOutputChannel(SESSION, nidaq_device, nidaq_ao_channel, "Voltage");
addAnalogOutputChannel(SESSION, nidaq_device,  nidaq_do_channel_start, "Voltage");


out=10.*my_env(sin(2*pi*freqs*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
%max of 10 volts
out=[zeros(1,round(pre*Fs)), out, zeros(1,round(post*Fs))];
%out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);
out_idx = size(out, 2);
start_trigger_data = 5.*ones(1, floor(0.2*Fs));
start_trigger_data = [start_trigger_data, zeros(1, out_idx - size(start_trigger_data,2))];

if stimulus == true
    addDigitalChannel(SESSION, nidaq_device, nidaq_do_channel_stimulus, "OutputOnly");
    if stimulus_pre_delay > 0
        stimulus_data = zeros(1,round(stimulus_pre_delay*Fs))
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
    queueOutputData(SESSION,[out',start_trigger_data',stimulus_data'])
else
    queueOutputData(SESSION,[out',start_trigger_data'])
end
SESSION.Rate = nidaq_samp_rate
%session_listener = SESSION.addlistener('DataAvailable',@save_data);

%temp = floor(pv_mic.SerialPortObject.NumBytesAvailable/2);
%pv_mic.SerialPortObject.flush();
%startBackground(SESSION);

startForeground(SESSION);

%in2 = pv_mic.RecordPrecise(6000,temp)./3276; %change this time
%in2 = pv_mic.Record(12000)./3276;

%pv_mic.delete();
%figure(1);
%subplot(1,2,1);
%plot(linspace(1/numel(out),numel(out)/Fs,numel(out)),in1);
%hold on;
%subplot(1,2,2);
%plot(linspace(1/12000,1.5,12000),in2);
%hold off;

    function save_data(src, event)
        %plot(event.TimeStamps,event.Data)
        in1 = [in1;event.Data];
    end
    function clear_pv_mic_buffer(src, event)
        read(pv_mic.SerialPortObject,40000,"int16");
    end
end