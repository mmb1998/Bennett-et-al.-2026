% function ret_val=winsorvar(arg,k,dim)
%
% data is in arg
% compute the variance along dimension dim
% k is the fraction of the extremes on each end to set to the
%     most extreme remaining value

function ret_val=winsorvar(arg,k,dim)

ret_val=var(winsorguts(arg,k,dim),[],dim);
