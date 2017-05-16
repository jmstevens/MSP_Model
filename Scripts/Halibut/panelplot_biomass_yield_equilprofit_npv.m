% panelplot_biomass_yield_equilprofit_npv
%Generate a panel plot of biomass, yield, equilbrium profit and npv in each patch

patchmarkersize=3;

figure
subplot(2,2,1)
metric_to_plot=sum(Bij,2);
scatter(lat_lon_habitat_patches(metric_to_plot==0,1),lat_lon_habitat_patches(metric_to_plot==0,2),patchmarkersize,[0.5 0.5 0.5],'s','filled')%
hold on
scatter(lat_lon_habitat_patches(metric_to_plot>0,1),lat_lon_habitat_patches(metric_to_plot>0,2),patchmarkersize,metric_to_plot(metric_to_plot>0),'s','filled')%
scatter(lat_lon_leftmapedge(1),lat_lon_leftmapedge(2),0.1,'.','k')
colorbar
axis tight
% xlabel('Latitude')
% ylabel('Longitude')
title('Biomass [kg]')
<<<<<<< HEAD
set(gcf,'color','white');
=======
set(gcf,'color','white'); 
>>>>>>> e9a6acd68e4a0fd08b18829858208289c9350661
plot(msp_domain(:,1),msp_domain(:,2),'k','linewidth',coastlinewidth) %coastline
set(gca,'XTickLabel','')
set(gca,'YTickLabel','')

subplot(2,2,2)
metric_to_plot=Yi;
scatter(lat_lon_habitat_patches(metric_to_plot==0,1),lat_lon_habitat_patches(metric_to_plot==0,2),patchmarkersize,[0.5 0.5 0.5],'s','filled')%
hold on
scatter(lat_lon_habitat_patches(metric_to_plot>0,1),lat_lon_habitat_patches(metric_to_plot>0,2),patchmarkersize,metric_to_plot(metric_to_plot>0),'s','filled')%
scatter(lat_lon_leftmapedge(1),lat_lon_leftmapedge(2),0.1,'.','k')
colorbar
axis tight
% xlabel('Latitude')
% ylabel('Longitude')
title('Yield [kg]')
<<<<<<< HEAD
set(gcf,'color','white');
=======
set(gcf,'color','white'); 
>>>>>>> e9a6acd68e4a0fd08b18829858208289c9350661
plot(msp_domain(:,1),msp_domain(:,2),'k','linewidth',coastlinewidth) %coastline
set(gca,'XTickLabel','')
set(gca,'YTickLabel','')

subplot(2,2,3)
metric_to_plot=Payoff;
scatter(lat_lon_habitat_patches(metric_to_plot==0,1),lat_lon_habitat_patches(metric_to_plot==0,2),patchmarkersize,[0.5 0.5 0.5],'s','filled')%
hold on
scatter(lat_lon_habitat_patches(metric_to_plot>0,1),lat_lon_habitat_patches(metric_to_plot>0,2),patchmarkersize,metric_to_plot(metric_to_plot>0),'s','filled')%
scatter(lat_lon_leftmapedge(1),lat_lon_leftmapedge(2),0.1,'.','k')
colorbar
axis tight
% xlabel('Latitude')
% ylabel('Longitude')
title('Equil. profit [$]')
<<<<<<< HEAD
set(gcf,'color','white');
=======
set(gcf,'color','white'); 
>>>>>>> e9a6acd68e4a0fd08b18829858208289c9350661
plot(msp_domain(:,1),msp_domain(:,2),'k','linewidth',coastlinewidth) %coastline
set(gca,'XTickLabel','')
set(gca,'YTickLabel','')

<<<<<<< HEAD
savefig(strcat(output_figure_dir,'Biomass_Yield_Profit_panelplot'))
=======
savefig('Biomass_Yield_Profit_panelplot')
>>>>>>> e9a6acd68e4a0fd08b18829858208289c9350661
