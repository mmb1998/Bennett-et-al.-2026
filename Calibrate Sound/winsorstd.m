% function ret_val=winsorstd(arg,k,dim)
%
% data is in arg
% compute the standard deviation along dimension dim
% k is the fraction of the extremes on each end to set to the
%     most extreme remaining value

function ret_val=winsorstd(arg,k,dim)

ret_val=std(winsorguts(arg,k,dim),[],dim);
