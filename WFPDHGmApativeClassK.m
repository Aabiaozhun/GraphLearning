function [unew, energy,residual,errors] = WFPDHGmApativeClassK(FD0,Iset,u00,lambda,dd,mu,tol,W,WT,maxit,FD_ref)
% Jiayong Liu,2017.10.23
% solving follwing problem
% using K labelling functions
% min lambda \sum_i|Wu_i| .s.t u_i=FD0 on Iset; u in Simplex.
% reference: Adaptive primal-dual Hybrid Gradient Method for saddle-pointtic;
[M,K]=size(u00);
d = cell(K,1);
Wu = cell(K,1);
% inititalize d and b, and compute normg
normg = 0;
norm0 = norm(u00,1);
for k=1:K 

    d{k} = W(u00(:,k));
    normg=normg+CoeffOperGraph('norm2',d{k});
end


[r Level] = size(d{1});
Thresh=cell(r,Level);
w=cell(r,Level);
Thresh = w;
for l=1:Level
    for j=1:r
        if (j == Level && j == 1)
            w{j,l} = lambda*4^(-l+1)*dd;
            Thresh{j,l} = w{j,l}/mu;
        else
            w{j,l} = lambda*4^(-l+1)*dd;
            Thresh{j,l}=w{j,l}/mu;
        end
    end
end
% for l = 1:Level
%     for j = 1:r
%         w{j,l} = lambda*4^(-l+1)*dd;
%         Thresh{j,l} = w{j,l};
%     end
% end

energy = zeros(maxit,1);
residual = zeros(maxit,1);
errors = zeros(maxit,1);
uold=zeros(M,K);
WTdelta_d = cell(K,1);
delta_d = cell(K,1);
Wue = cell(K,1);
uold = rand(size(u00));
unew = uold;

theta = 1;
% sigma, tau ,Delta,s,can be tuned
s = 255;
Delta = 1.5;
alpha = 0.5*ones(K,1);
eta = 0.5;

P = ones(K,1); % p_{k} in reference
D = ones(K,1); % d_{k} in reference

sigma = 0.008*ones(K,1);% setpsize for dual variable
tau = 20*ones(K,1);  % setpsize for primal variable



disp(['Initial is ',num2str(100*length(Iset(:))/M),'%'])
for nstep=1:maxit
    ubar = unew + theta*(unew-uold);
    uold = unew;
    % update d and update u
    for k=1:K
        % update d
        Wu{k}=W(ubar(:,k));
        doldk = d{k};
        d{k} = CoeffOperGraph('*+',d{k},Wu{k},1,sigma(k)); % compute d=d+sigma*Wu;
        d{k} = CoeffOperGraph('p',d{k},Thresh); % projection onto l infinity ball with Thresh
        delta_d{k} = CoeffOperGraph('-',doldk,d{k});
        WTdelta_d{k} = WT(delta_d{k});
        
        % update u
        unew(:,k) = uold(:,k)-tau(k)*WT(d{k});
        
        % unew(Iset(:,k),k) = FD0(Iset(:,k),k);
    end
    unew = projl1p_1D(unew,1);
    for k = 1:K
        unew(Iset(:,k),:) = 0; 
    end
    for k = 1:K
        unew(Iset(:,k),k) = FD0(Iset(:,k),k);
        Wue{k} = W(unew(:,k));
    end

    % projection onto l1 ball
    unew = projl1p_1D(unew,1);

    for k = 1:K
        % compute P and D values
        delta_u = uold(:,k) -unew(:,k);
        Wdelta_u = W(delta_u);

        P(k,1) = norm(delta_u/sigma(k) - WTdelta_d{k},1);
        tmp = CoeffOperGraph('*c',delta_d{k},1/tau(k));
        D(k,1) = CoeffOperGraph('norm1',CoeffOperGraph('-',tmp,Wdelta_u));
    end

    
    % update parameters
    if nstep > 0
        for k = 1:K
            if P(k) > s*D(k)*Delta
                tau(k) = tau(k)/(1-alpha(k));
                sigma(k) = sigma(k) * (1-alpha(k));
                alpha(k) = alpha(k) * eta;
            elseif P(k) < s*D(k)*Delta
                tau(k) = tau(k)*(1-alpha(k));
                sigma(k) = sigma(k)/(1-alpha(k));
                alpha(k) = alpha(k) * eta;
            end
        end
    end
    
    % Compute the enery and residual
    residual(nstep)=norm(unew-uold,1)/norm0;
    for k=1:K
        Wue{k}=W(unew(:,k));
        energy(nstep)=energy(nstep)+CoeffOperGraph('wnorm1',Wue{k},w);
    end
    
    % compute the errors if FD_ref is given
    [~,FDr] = max(unew,[],2);
    FDr = FDr-1;FDr(Iset(:)) = FD_ref(Iset(:));
    c = FDr == FD_ref;
    errors(nstep) = 100*(M-sum(c))/(M - length(Iset(:)));%sum(c) contains length(Iset),so not minus length(Iset) on numerator
    if residual(nstep)<tol
        errors = errors(1:nstep)
        residual = residual(1:nstep)
        energy = energy(1:nstep)
        break;
    end
    if mod(nstep,1)==0
        Tm=toc;
        display(['Step = ' num2str(nstep) '; Residual = ' num2str(residual(nstep)) '; Energy = ' num2str(energy(nstep)) '; Accuracy = ' num2str(100-errors(nstep)) '%; Time Elapsed = ' num2str(Tm)]);
    end
end