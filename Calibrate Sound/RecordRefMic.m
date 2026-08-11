function RecordRefMic(t, filename, freq)
%length of recording is in seconds

nidaq_device = "Dev2"; %change to device name
nidaq_ai_channel = "ai0";

global Fs SESSION;
Fs = 16000; %Hz


%create NIDAQ session
SESSION = daq.createSession("ni");
addAnalogInputChannel(SESSION, nidaq_device, nidaq_ai_channel, "Voltage");
SESSION.Rate = Fs;
SESSION.DurationInSeconds = t

hardware='ni';  % or 'tdt' -- tdt currently doesn't work
plot_flag=1;  % =0 is don't plot


in1 = [];

if strcmp(hardware,'ni')
    session_listener = SESSION.addlistener('DataAvailable',@save_data); 
    startBackground(SESSION);

    %wait for acquisition to finish
    while ~SESSION.IsDone
        pause(0.1);
    end
    pause(1);
    
    delete(session_listener);

    
else
    if(side_out=='L')
        tdt_set_atten(atten,120);
        [in1,in2]=tdt_record_play(0,length(out),out,zeros(1,length(out)));
    end
    if(side_out=='R')
        tdt_set_atten(120,atten);
        [in1,in2]=tdt_record_play(0,length(out),zeros(1,length(out)),out);
    end
end

if(~isempty(filename))
    save(strcat(filename,'_refmic.mat'),'in1','t','freq');
end

if(plot_flag>0)
    figure(plot_flag);
    subplot(1,2,1);  cla;
    plot(in1);  title([num2str(freq) ' Hz']);
    axis tight;
    subplot(1,2,2);  cla;  hold on;
    plot(in1(floor(length(in1)/4):round(floor(length(in1)/4)+3*Fs/freq)));
    axis tight;

end

    function save_data(src, event)
        %plot(event.TimeStamps,event.Data)
        in1 = [in1;event.Data(:,1)];
    end
end
