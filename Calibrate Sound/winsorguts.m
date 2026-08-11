function ret_val=winsorguts(arg,k,dim)

arg=squeeze(arg);
nda=ndims(arg);
n=size(arg,dim);
r=prod(size(arg))/n;
k=round(k*n);

if((dim<0)|(dim>ndims(arg)))  error('bad input value for arg dim');  end
if(2*k>=n)
  k=floor((n-1)/2);
  disp('WARNING: bad input value for k--  using median');
elseif(k==0)
  disp('WARNING: k == 0 points so using mean');
end

idx=1:nda;  idx(dim)=nda;  idx(nda)=dim;  arg=permute(arg,idx);
arg=sort(arg,nda);
s=size(arg);
arg=reshape(arg,1,prod(size(arg)));

for(i=1:k)
  arg((i-1)*r+(1:r))=arg(k*r+(1:r));
  arg((n-i)*r+(1:r))=arg((n-k-1)*r+(1:r));
end

arg=reshape(arg,s);
ret_val=ipermute(arg,idx);
