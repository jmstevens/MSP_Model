%Loads policy solutions (EF MSP plans of aqua development) and calculates sector payoffs in each patch
clear all
close all
tic %start timer

set(0,'defaultfigurecolor',[1 1 1])

Run0_load1_data_and_EFeval=0; %choose (running take several hours; loading many minutes; plotting many minutes)

if Run0_load1_data_and_EFeval==0; %Takes several hours to run
    %Matrix of policy plans
    % rows = i = 1....1061 sites
    % cols = a = 1....279936 unique alpha weighting scenarios
    load('Policy_i_a.mat')

    % Load other key variables
        % X_n_i_p = Matrix of sector unitless value in each patch given policy choices
            % dimension 1 = i = 1....1061 sites
            % dimension 2 = n = 1....7 sectors
            % dimension 3 = p = 1...4 policies:
                %No development (p=1)
                %Mussel development (p=2)
                %Finfish development (p=3)
                %Kelp development (p=4)
        % I = number of sites
    load('TOA_data.mat', 'X_n_i_p','I')

    %Shells for each sector (order: M, F, K, H, V, B, D) for recording values
    % in each site wrt each weighting scenario
    shell=NaN(I,length(Policy_i_a));
    EFPayoff_i_a_M=shell;
    EFPayoff_i_a_F=shell;
    EFPayoff_i_a_K=shell;
    EFPayoff_i_a_H=shell;
    EFPayoff_i_a_V=shell;
    EFPayoff_i_a_B=shell;
    EFPayoff_i_a_D=shell;

    % Evaluate EF solns
    iP_counter=round(linspace(1,length(Policy_i_a),100));
    for iP=1:length(Policy_i_a)  %For each policy choice...
        if isempty(intersect(iP,iP_counter))==0
            disp(['iP = ',num2str(iP)])
        end
        for ii=1:I % ...for each site
            %Determine policy and save sector values
                %No development (p=1)
                %Mussel development (p=2)
                %Finfish development (p=3)
                %Kelp development (p=4)
            p_i=Policy_i_a(ii,iP); %policy choice in site i
            EFPayoff_i_a_M(ii,iP)=X_n_i_p(ii,1,p_i);
            EFPayoff_i_a_F(ii,iP)=X_n_i_p(ii,2,p_i);
            EFPayoff_i_a_K(ii,iP)=X_n_i_p(ii,3,p_i);
            EFPayoff_i_a_H(ii,iP)=X_n_i_p(ii,4,p_i); %static
            EFPayoff_i_a_V(ii,iP)=X_n_i_p(ii,5,p_i);
            EFPayoff_i_a_B(ii,iP)=X_n_i_p(ii,6,p_i);
            EFPayoff_i_a_D(ii,iP)=X_n_i_p(ii,7,p_i);
        end
    end
    %Save values
    EFPayoff_i_a_X=EFPayoff_i_a_M;
    save('EFPayoff_i_a_X.mat','EFPayoff_i_a_M','EFPayoff_i_a_F','EFPayoff_i_a_K','EFPayoff_i_a_H','EFPayoff_i_a_V','EFPayoff_i_a_B','EFPayoff_i_a_D','-v7.3');

%% scale payoffs so ranges ranges 0-1 relative to max and min domain-wide payoff (note, this is not the same as the scaling done in the tradeoff analysis)

    %First, calculate domain-wide value to each sector for each scenario
    EFPayoff_a_M=nansum(EFPayoff_i_a_M,1);
    EFPayoff_a_F=nansum(EFPayoff_i_a_F,1);
    EFPayoff_a_K=nansum(EFPayoff_i_a_K,1);
    EFPayoff_a_H=nansum(EFPayoff_i_a_H,1); %static
    %overwrite halibut with dynamic response
    load Y_NPV_wrt_MSP
    EFPayoff_a_H=Y_NPV_wrt_MSP';
    EFPayoff_a_V=nansum(EFPayoff_i_a_V,1);
    EFPayoff_a_B=nansum(EFPayoff_i_a_B,1);
    EFPayoff_a_D=nansum(EFPayoff_i_a_D,1);

    % Then, scale domain-wide payoff wrt max and min payoff possible, so ranges 0-1
    %max payoff to M if M developed everywhere possible; min if no development
    EFPayoff_a_M_wrt_DM=(EFPayoff_a_M-sum(squeeze(X_n_i_p(:,1,1))))./(sum(squeeze(X_n_i_p(:,1,2)))-sum(squeeze(X_n_i_p(:,1,1))));
    %max payoff to F if F developed everywhere possible, min if no development
    EFPayoff_a_F_wrt_DM=(EFPayoff_a_F-sum(squeeze(X_n_i_p(:,2,1))))./(sum(squeeze(X_n_i_p(:,2,3)))-sum(squeeze(X_n_i_p(:,2,1))));
    %max payoff to K if K developed everywhere possible, min if no development
    EFPayoff_a_K_wrt_DM=(EFPayoff_a_K-sum(squeeze(X_n_i_p(:,3,1))))./(sum(squeeze(X_n_i_p(:,3,4)))-sum(squeeze(X_n_i_p(:,3,1))));
    %max payoff to H if no aqua development, min if full development
    % EFPayoff_a_H_wrt_DM=(EFPayoff_a_H-sum(min(squeeze(X_n_i_p(:,4,:)),[],2)))./(sum(squeeze(X_n_i_p(:,4,1)))-sum(min(squeeze(X_n_i_p(:,4,:)),[],2))); %static
    %Eval halibut dynamically and wrt full domain (not just aqua sites), so ranges min to 1 (not 0-1)
    EFPayoff_a_H_wrt_DM=EFPayoff_a_H./max(EFPayoff_a_H);
    %max payoff to V if no aqua development, min if full development
    EFPayoff_a_V_wrt_DM=(EFPayoff_a_V-sum(min(squeeze(X_n_i_p(:,5,:)),[],2)))./(sum(squeeze(X_n_i_p(:,5,1)))-sum(min(squeeze(X_n_i_p(:,5,:)),[],2)));
    %max payoff to B if no aqua development, min if full development
    EFPayoff_a_B_wrt_DM=(EFPayoff_a_B-nansum(min(squeeze(X_n_i_p(:,6,:)),[],2)))./(nansum(squeeze(X_n_i_p(:,6,1)))-nansum(min(squeeze(X_n_i_p(:,6,:)),[],2)));
    %max payoff to D if no aqua development, min if full development
    EFPayoff_a_D_wrt_DM=(EFPayoff_a_D-nansum(min(squeeze(X_n_i_p(:,7,:)),[],2)))./(nansum(squeeze(X_n_i_p(:,7,1)))-nansum(min(squeeze(X_n_i_p(:,7,:)),[],2)));
    %(Note: For B and D above, nansum used because some sites are NaN bc could never be developed for F)

    %save results
    EFPayoff_a_X_wrt_DM=EFPayoff_a_M_wrt_DM;
    save('EFPayoff_a_X_wrt_DM','EFPayoff_a_M_wrt_DM','EFPayoff_a_F_wrt_DM','EFPayoff_a_K_wrt_DM','EFPayoff_a_H_wrt_DM','EFPayoff_a_V_wrt_DM','EFPayoff_a_B_wrt_DM','EFPayoff_a_D_wrt_DM')
elseif Run0_load1_data_and_EFeval==1
%     disp('Loading EFPayoff_i_a_X')
%     load EFPayoff_i_a_X
    disp('Loading EFPayoff_a_X_wrt_DM')
    load EFPayoff_a_X_wrt_DM
end
%% Plot some results
sectors={'M','F','K','H','V','B','D'};
% Pairwise tradeoffs as full figures
% for f1=1:length(sectors)
%     for f2=1:length(sectors)
%     figure
%     eval(['h=scatter(100.*EFPayoff_a_',sectors{f1},'_wrt_DM,100.*EFPayoff_a_',sectors{f2},'_wrt_DM);'])
%     set(h,'Marker','.')
%     axis([0 100 0 100])
%     xlabel(sectors{f1})
%     ylabel(sectors{f2})
%     end
% end

%Panel plot of tradeoffs
h=figure;
for f1=1:length(sectors)
    for f2=1:length(sectors)
        if f1<f2
            subplot_p=sub2ind([length(sectors) length(sectors)],f1,f2);
            subplot(length(sectors),length(sectors),subplot_p)
            eval(['h=scatter(100.*EFPayoff_a_',sectors{f1},'_wrt_DM,100.*EFPayoff_a_',sectors{f2},'_wrt_DM);'])
            set(h,'Marker','.')
            axis([0 100 0 100])
%             xlabel(sectors{f1})
%             ylabel(sectors{f2})
        end
        if f1==1
            ylabel(sectors{f2})
        end
        if f2==length(sectors)
            xlabel(sectors{f1})
        end
    end
end
set(gcf,'units','normalized','outerposition',[0 0 1 1])
saveas(h,'Fig2Tradeoffs','fig')
saveas(h,'Fig2Tradeoffs','jpg')
beep
disp(['Took ',num2str(toc/60/60),' hours']) %report run time
