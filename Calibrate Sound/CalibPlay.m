function [in1, in2, clip1, clip2]=CalibPlay(out,idx,freq,atten,side_out,highpass,lowpass,mic_clip,idx2)
%idx is only used for plotting
%if idx2 is empty, don't capture from pv usb mic

global Fs pv_usb_samp_rate;
in1 = [];
in2 = [];

hardware='ni';  % or 'tdt'
plot_flag=1;  % =0 is don't plot
pv_usb_bit_to_voltage = 2.5/2^16; %conversion factor in bits per voltage (can be optional)

if strcmp(hardware,'ni')
    global SESSION pv_usb_mic;
else
    global ZBUS RP2_1 RP2_2 PA5L PA5R;
end

if strcmp(hardware,'ni')
    %out=out./(10^(atten/20)); %why divide by 20? is this a typo
    out=out.*(0.173/(10^(atten/10)));
    %multiply by 0.173 for a +4 dbu amp output,
    %this is assuming we dont have an actual attenuator unit in between DAQ and amp
    queueOutputData(SESSION,out')
    session_listener = SESSION.addlistener('DataAvailable',@save_data);
    
    %precompute these things to save time
    pv_usb_len_to_record = ceil(length(out)*pv_usb_samp_rate/Fs);
    %pv_usb_curr_samps = floor(pv_usb_mic.SerialPortObject.NumBytesAvailable/2);
    
    startBackground(SESSION);
    if ~isempty(idx2)
        in2 = pv_usb_mic.Record(pv_usb_len_to_record);
        %in2 = pv_usb_mic.RecordPrecise(pv_usb_len_to_record,pv_usb_curr_samps);
        in2 = in2.*pv_usb_bit_to_voltage;
    end
    
    %wait for acquisition to finish
    while length(in1) < length(out)
        pause(0.1);
    end
    pause(1);
    
    delete(session_listener);
    
    % for DAQs without hardware timing capability
    %   i = 1;
    %   t = timer('TimerFcn',@SoftwareTimedAo,'Period',0.001,'TasksToExecute',numel(out),'ExecutionMode','fixedRate');
    %   start(t);
    
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
if(~isempty(highpass))
    [b,a]=butter(4,[highpass lowpass]./(Fs/2));
    in1=filtfilt(b,a,in1);
    if ~isempty(idx2)
        [b,a]=butter(4,[highpass lowpass]./(pv_usb_samp_rate/2));
        in2=filtfilt(b,a,in2);
    else
        [b,a]=butter(4,[highpass lowpass]./(Fs/2));
        in2=filtfilt(b,a,in2);
    end
end

clip1=100*sum(sum(in1>mic_clip))./prod(size(in1));
clip2=100*sum(sum(in2>mic_clip))./prod(size(in2));
%if(((max(abs(in1))-mean(in1))>mic_clip) | ((max(abs(in2))-mean(in2))>mic_clip))
if((clip1>0) | (clip2>0))
    warning(['MIC CLIPPING: ' num2str(clip1,3) '%, ' num2str(clip2,3) '%']);
end

if(plot_flag>0)
    figure(plot_flag);
    tmp1=mean(in1);  tmp2=mean(in2);
    subplot(3,2,1);  cla;
    plot(out);  title([num2str(freq) ' Hz, -' num2str(atten) ' dB']);
    axis tight;
    subplot(3,2,3);  cla;  hold on;
    plot(in1);
    plot([min(idx) max(idx)],[tmp1 tmp1],'r-');
    axis tight;
    subplot(3,2,5);  cla;  hold on;
    if ~isempty(idx2)
        plot(in2);
        plot([min(idx2) max(idx2)],[tmp2 tmp2],'r-');
    else
        plot(in2);
        plot([min(idx) max(idx)],[tmp2 tmp2],'r-');
    end
    axis tight;
    if(isempty(freq) || isnan(freq) || (freq==0))  freq=60;  end
    subplot(3,2,2);  cla;
    plot(out(idx(1):round(idx(1)+3*Fs/freq)));
    axis tight;
    subplot(3,2,4);  cla;  hold on;
    plot(in1(idx(1):round(idx(1)+3*Fs/freq)));
    axis tight;
    subplot(3,2,6);  cla;  hold on;
    if ~isempty(idx2)
        plot(in2(idx2(1):round(idx2(1)+3*pv_usb_samp_rate/freq)));
    else
        plot(in2(idx(1):round(idx(1)+3*Fs/freq)));
    end
    axis tight;
end

    function SoftwareTimedAo(src,event)
        write(SESSION, out(i));
        i = i + 1;
    end
    function save_data(src, event)
        %plot(event.TimeStamps,event.Data)
        in1 = [in1;event.Data(:,1)];
        if isempty(idx2)
            in2 = [in2;event.Data(:,2)];
        end
    end
end
