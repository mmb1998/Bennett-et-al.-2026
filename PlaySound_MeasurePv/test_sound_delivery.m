function test_sound_delivery()
global Fs;
Fs = 16000; %Hz

freqs = 200;
ramp=0.05;
pre=0.1;
len=1; %duration of sound delivery, was 0.5
post=0.1;
nreps=1;
snr_crit=1;
shift=0.001;
highpass=20;
lowpass=15000;
%highpass=[];
%lowpass=[];
winsor=0.2;
mic_clip=2;

out=10.*my_env(sin(2*pi*freqs*(1:round(len*Fs))/Fs),'cosine',ramp,ramp,Fs);
%max of 10 volts
out=[zeros(1,round(pre*Fs)) out zeros(1,round(post*Fs))];
out_idx=ceil((shift+pre+2*ramp)*Fs):floor((shift+pre+len-2*ramp)*Fs);
%CalibPlay(out,out_idx,freqs,1,'L',highpass,lowpass,mic_clip);

nidaq_device = "Dev2"; %change to device name
nidaq_ai_channel = "ai0";
nidaq_ao_channel = "ao0";
nidaq_samp_rate = Fs;
%pv_mic_serial_port = "COM3";

global SESSION pv_usb_mic;

%pv_mic = PvMicUSB(pv_mic_serial_port,8000); %should be in calibrate_mic
%configureCallback(pv_mic.SerialPortObject,"byte",80000,@clear_pv_mic_buffer);
%flush buffered data every now and then
%threshold to flush should be larger than any capture duration you use
%(ugly workaround)
%do not use flush()! Can mess up 2-byte integer stream
%pv_mic.On();

in1 = [];

SESSION = daq.createSession("ni"); %these should be set in calibrate_mic instead
addAnalogInputChannel(SESSION, nidaq_device, nidaq_ai_channel, "Voltage");
addAnalogOutputChannel(SESSION, nidaq_device, nidaq_ao_channel, "Voltage");
%out=out./(10^(atten/20));
out=out.*0.174; %for now (testing, just scale output to max level possible for output to a +4 dbu amp
%preload(SESSION,transpose(out));
queueOutputData(SESSION,out')
SESSION.Rate = nidaq_samp_rate
session_listener = SESSION.addlistener('DataAvailable',@save_data);

%temp = floor(pv_mic.SerialPortObject.NumBytesAvailable/2);
%pv_mic.SerialPortObject.flush();
startBackground(SESSION);
%in2 = pv_mic.RecordPrecise(6000,temp)./3276; %change this time
%in2 = pv_mic.Record(12000)./3276;

%pv_mic.delete();
%figure(1);
%subplot(1,2,1);
plot(linspace(1/numel(out),numel(out)/Fs,numel(out)),in1);
hold on;
%subplot(1,2,2);
plot(linspace(1/12000,1.5,12000),in2);
hold off;

    function save_data(src, event)
        %plot(event.TimeStamps,event.Data)
        in1 = [in1;event.Data];
    end
    %function clear_pv_mic_buffer(src, event)
        %read(pv_mic.SerialPortObject,40000,"int16");
    %end
end