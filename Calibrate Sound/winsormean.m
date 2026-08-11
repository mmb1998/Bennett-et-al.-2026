% function ret_val=winsormean(arg,k,dim)
%
% data is in arg
% compute mean along dimension dim
% k is the fraction of the extremes on each end to set to the
%     most extreme remaining value

function ret_val=winsormean(arg,k,dim)

ret_val=mean(winsorguts(arg,k,dim),dim);
