% function ret_val=winsorerr(arg,k,dim)
%
% data is in arg
% compute the standard error along dimension dim
% k is the fraction of the extremes on each end to set to the
%     most extreme remaining value

function ret_val=winsorerr(arg,k,dim)

n=size(arg,dim);
ret_val=std(winsorguts(arg,k,dim),[],dim).*(n-1)./(n-2*k-1)./sqrt(n);
