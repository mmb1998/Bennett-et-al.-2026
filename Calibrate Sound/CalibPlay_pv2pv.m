function [in1, in2, clip1, clip2]=CalibPlay_pv2pv(out,idx,freq,atten,side_out,highpass,lowpass,mic_clip,idx2,type1,type2)
%idx is only used for plotting

global Fs pv_usb_samp_rate;
in1 = [];
in2 = [];

hardware='ni';  % or 'tdt'
plot_flag=1;  % =0 is don't plot
pv_usb_bit_to_voltage = 2.5/2^16; %conversion factor in bits per voltage (can be optional)

if strcmp(hardware,'ni')
    global SESSION pv_usb_mic pv_usb_mic0;
else
    global ZBUS RP2_1 RP2_2 PA5L PA5R;
end

if strcmp(hardware,'ni')
    out=out.*(0.173/(10^(atten/10)));
    %multiply by 0.173 for a +4 dbu amp output,
    %this is assuming we dont have an actual attenuator unit in between DAQ and amp
    queueOutputData(SESSION,out')
    if strcmp(type1, 'p') || strcmp(type1, 'pv')
        session_listener = SESSION.addlistener('DataAvailable',@save_data);
    end
    
    %precompute these things to save time
    pv_usb_len_to_record = ceil(length(out)*pv_usb_samp_rate/Fs);
    %pv_usb_curr_samps = floor(pv_usb_mic.SerialPortObject.NumBytesAvailable/2);
    
    startBackground(SESSION);
    if strcmp(type1, 'pvusb') && strcmp(type2, 'pvusb')
        pv_usb_mic0.FlushBuffer(); %workaround to recording simultaneously
        in2 = pv_usb_mic.Record(pv_usb_len_to_record);
        in1 = pv_usb_mic0.RecordNoFlush(pv_usb_len_to_record); %its possible for data to be lost because it was overwritten in the buffer
        in2 = in2.*pv_usb_bit_to_voltage;
        in1 = in1.*pv_usb_bit_to_voltage;
    elseif strcmp(type2, 'pvusb')
        in2 = pv_usb_mic.Record(pv_usb_len_to_record);
        in2 = in2.*pv_usb_bit_to_voltage;
    end
    
    %wait for acquisition to finish
    while ~SESSION.IsDone
        pause(0.1);
    end
    pause(1);
    
    if strcmp(type1, 'p') || strcmp(type1, 'pv')
        delete(session_listener);
    end
    
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
    if strcmp(type1, 'pvusb')
        [b,a]=butter(4,[highpass lowpass]./(pv_usb_samp_rate/2));
        in1=filtfilt(b,a,in1);
    else
        [b,a]=butter(4,[highpass lowpass]./(Fs/2));
        in1=filtfilt(b,a,in1);
    end
    if strcmp(type2, 'pvusb')
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
if((clip1>0) || (clip2>0))
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
    if strcmp(type2, 'pvusb')
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
    if strcmp(type1, 'pvusb')
        plot(in1(idx(1):round(idx(1)+3*pv_usb_samp_rate/freq)));
    else
        plot(in1(idx(1):round(idx(1)+3*Fs/freq)));
    end
    axis tight;
    subplot(3,2,6);  cla;  hold on;
    if ~isempty(idx2)
        plot(in2(idx2(1):round(idx2(1)+3*pv_usb_samp_rate/freq)));
    else
        plot(in2(idx(1):round(idx(1)+3*Fs/freq)));
    end
    axis tight;
end

    function save_data(src, event)
        %plot(event.TimeStamps,event.Data)
        in1 = [in1;event.Data(:,1)];
        if isempty(idx2)
            in2 = [in2;event.Data(:,2)];
        end
    end
end
