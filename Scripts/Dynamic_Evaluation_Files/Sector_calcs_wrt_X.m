function [Halibut_Yi_tmp]=Sector_calcs_wrt_X(X,input_data_dir,target_fid_fulldomain,Aqua_Dev_Indices,SQ_1fishable_0notfishable_for_each_soft_depth_patch_ORIGINAL,Nij_initial_msy_TS,x0_PPUE_msy_TS,Fsum_msy,target_fid_hab_depth,Wij,numpatches,max_age,T,delta,age_legal,age_mature,Dii,alphaCR,beta_i,habitat_area_i,theta,price,gammatmp,distance_to_port_for_each_soft_depth_patch,Mii,age_move,discount_rate_iy);
  X_domain=zeros(size(target_fid_fulldomain));
  X_domain(Aqua_Dev_Indices)=X';
  %% Halibut
  SQ_1fishable_0notfishable_for_each_soft_depth_patch=SQ_1fishable_0notfishable_for_each_soft_depth_patch_ORIGINAL; %Reset fishable vector
  tmp1=X~=0; %find which aqua patches were developed
  tmp2=target_fid_fulldomain(tmp1); %figure out what fid numbers in the full domain represent those patches
  [C, IA, IB]=intersect(tmp2,target_fid_hab_depth); %find fid's in common with those that represent the halibut patches. IB=indices (not fid's) of the halibut patches that are developed by aqua dev
  SQ_1fishable_0notfishable_for_each_soft_depth_patch(IB)=0; %set those patches to not fishable (note: they may already be not fishable due to other constraints)
  %Run TS model
  Nij_initial=Nij_initial_msy_TS; %initial stock status (patch and age class specific)
  x0_PPUE_initial=x0_PPUE_msy_TS;
  Fsum=Fsum_msy; %TAE (fleet model) <-Assuming no change in management, only in fishery distribution.
  BasicSpatialHarvestModel_COREv1_fleet_TS
  Yi_wrt_alpha=sum(Yiy,2); %sum years together to calc NPV for each patch
  Halibut_Yi_tmp=sum(Yi_wrt_alpha);
end
