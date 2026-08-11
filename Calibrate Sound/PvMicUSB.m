classdef PvMicUSB
% Han's custom particle velocity microphone that uses a USB serial port
% settings as per Steve Sawtelle
% These need to be sent to the Mic board via write(s,x,"char") where s is a
% serialport() object and x is one of the characters below

% O – turn the battery power
% F – turn of the battery power
% S – start streaming data
% E – end streaming
% R – sampling rate
% A – send data in ASCII (may cause overruns)
% B – send data as 2 byte integer values
% 1 through 8 – set sample rate in kHz
% ? – see current setup
%  
% Default setup is 6000 samples per sec, ASCII, battery off, streaming off.
% Only use output as 2 byte integers as ASCII has issues


    properties
        SamplingRate = '8'; %in KHz
        SerialPortID; %string that identifies the serial port to connect to
        SerialPortObject;
    end
    methods
        function obj = PvMicUSB(Port,varargin)
            narginchk(1, 2)
            obj.SerialPortID = Port;
            obj.SerialPortObject = serialport(Port,9600);
            if nargin > 1
                   if varargin{1} <= 8000 && varargin{1} > 0
                       obj.SamplingRate = num2str(ceil(varargin{1}/1000));
                       %disp(strcat(obj.SamplingRate, "000 Hz PV USB sampling rate"))
                   else
                       error("PV USB sampling rate must be between 0 and 8000 Hz")
                   end
            end
            write(obj.SerialPortObject,strcat(obj.SamplingRate,"BO"),"string");
            pause(0.5);
            flush(obj.SerialPortObject, "input");
        end
        function On(obj)
            write(obj.SerialPortObject,"S","char");
            pause(2); %let mic readings stabilize
            %need to periodically clear old samples in buffer
        end
        function Samples = Record(obj, NumSamples)
            %time in seconds
            %dump old samples
            read(obj.SerialPortObject,floor(obj.SerialPortObject.NumBytesAvailable/2),"int16");
            %NumSamples = ceil(Time*uint32(str2num(obj.SamplingRate))*1000);
            %write(obj.SerialPortObject,"S","char");
            Samples = read(obj.SerialPortObject,NumSamples,"int16");
            %write(obj.SerialPortObject,"E","char");
        end
        function Samples = RecordPrecise(obj, NumSamples,NumToDump)
            %time in seconds
            %dump old samples
            read(obj.SerialPortObject,floor((NumToDump+obj.SerialPortObject.NumBytesAvailable/2)/2),"int16");
            Samples = read(obj.SerialPortObject,NumSamples,"int16");
        end
        function Samples = RecordNoFlush(obj, NumSamples)
            Samples = read(obj.SerialPortObject,NumSamples,"int16");
        end
        function FlushBuffer(obj)
            %dump old samples
            read(obj.SerialPortObject,floor(obj.SerialPortObject.NumBytesAvailable/2),"int16");
        end
        function State = CurrentState(obj)
            write(obj.SerialPortObject,"?","char");
            State = char();
            for i = 1:3
                State = strcat(State, readline(obj.SerialPortObject));
            end
            flush(obj.SerialPortObject, "input");
        end
        function delete(obj)
            write(obj.SerialPortObject,"EF","string");
            pause(0.5);
            flush(obj.SerialPortObject);
            %write(obj.SerialPortObject,"F","char"); %power off
            obj.SerialPortObject.delete();
        end
    end
end
            
                    
        