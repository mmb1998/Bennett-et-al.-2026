function [calib_freq calib_mag calib_phi]=CalibLoadSpk(filename)

load([filename '_spkfreqnoise']);
%run([filename '_spk']);
