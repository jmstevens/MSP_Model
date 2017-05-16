# MATLAB requires 'Mapping Toolbox', 'Bioinformatics', 'Parallel Optimization'
# Set current working directory as a string
# fdirs$home <- "~/MSP_Model/"
# fdirs$scrpdir <- "~/MSP_Model/Scripts/"
# fdirs$inpdatadir <- "~/MSP_Model/Input/Data/"
# fdirs$inpfigdir <- "~/MSP_Model/Input/Figures/"
# fdirs$outdatadir <- "~/MSP_Model/Output/Data/"
# fdirs$outfigdir <- "~/MSP_Model/Output/Figures/"
# Load necessary R libraries. For the function R_Libraries, enter T if this is the first time running the model. This will
# install all of the necessary libraries and load them into the
# current workspace.
# Install R markdown
install.packages("knitr",repos = 'https://cran.mtu.edu/')
library(knitr)
# Set global variables
n.sector <- 7 # Number of sectors
epsilon <- 0.2 # Stepsize of sector weights
t <- 10 # Time Horizon
r <- 0.05 # Discount rate

# Read sector data
sector_data.df <- read.csv(paste0(fdirs$inpdatadir,'SeaGrant_data_complete_2015.csv'))
fulldomain <- sector_data.df$TARGET_FID # Model domain
discount_factor <- 1/((1+r)^c(1:t))
# Make a numeric matrix of the discount_factor with the dimensions of
# rows = 6425 (number of sites in the domain), columns = 10 (time horizon)
r_iy_aqua <- do.call(rbind, replicate(length(fulldomain), discount_factor, simplify=FALSE))

# Calculate the 10-year Net Present Value (NPV) and annuities for each form of aquaculture
# and halibut (the only impacted sector with direct monetary value)
  # Function to calculate the NPV/annuities for Mussel and Kelp
  Value.MK <- function(yield,upfront.cost,annual.cost,price){
    revenue <- do.call(cbind, replicate(t, yield * price, simplify=FALSE))
    cost <- cbind(upfront.cost + annual.cost,
      do.call(cbind, replicate(t - 1, annual.cost, simplify=FALSE)))
    profit <- (revenue - cost) * r_iy_aqua
    profit[profit < 0] <- 0
    NPV <- apply(profit, FUN = sum, MARGIN = 1)
    Annuity = (r*NPV)/(1-((1+r)^-t))
    return(list(NPV = NPV,Annuity = Annuity))
  }
  # Function to calculate the NPV/annuities for Finfish
  Value.F <- function(yield,costs,price){
    revenue <- do.call(cbind, replicate(t, yield * price, simplify=FALSE))
    cost <- sector_data.df$fish.annual.operating.costs
    profit <- (revenue - cost) * r_iy_aqua
    profit[profit < 0] <- 0
    NPV <- apply(profit, FUN = sum, MARGIN = 1)
    Annuity = (r*NPV)/(1-((1+r)^-t))
    return(list(NPV = NPV,Annuity = Annuity))
  }
# Calculate respective NPV/annuities
# Mussel, fixed price of $3.30 per kg
  M <- Value.MK(sector_data.df$mussel.yield,
    sector_data.df$mussel.upfront.cost,
    sector_data.df$mussel.annual.operating.cost,3.3)
# Finfish, fixed price of $8.00 per kg
  F <- Value.F(sector_data.df$fish.yield,
    sector_data.df$fish.upfront.cost,
    unique(sector_data.df$fish.price[sector_data.df$fish.price>0]))
# Kelp, fixed price of $3.00 per kg
  K <- Value.MK(sector_data.df$kelp.yield,
    sector_data.df$kelp.upfront.cost,
    sector_data.df$kelp.annual.operating.cost,3)
# Remove unprofitable sites and generate seperate vectors for
# Those sites in which ventures will be profitable for at least one type
# of aquaculture (var Aqua.Full.Domain),
Aqua.Full.Domain <- data.frame(M$Annuity,F$Annuity,K$Annuity)
Aqua.Full.Domain.Logical <- apply(1 * (Aqua.Full.Domain > 0),FUN=sum,MARGIN=1) > 0
# Sites that will be profitable for mussel (M.V)
M.V <- M$Annuity[Aqua.Full.Domain.Logical]
# Sites that will be profitable for finfish (F.V)
F.V <- F$Annuity[Aqua.Full.Domain.Logical]
# Sites that will be profitable for kelp (K.V)
K.V <- K$Annuity[Aqua.Full.Domain.Logical]

# Run the Halibut fishing model and then load the results
if(readline("Run halibut model or load results Y/N? ") == 'Y'){
  system2(matlab_root,
    args = c('-nodesktop','-noFigureWindows','-nosplash','-r',
    paste0("run\\(\\'",fdirs$scrpdir,"Halibut/Tuner_free_params_v4.m\\'\\)")))
}
H.V  <- (r*read.csv(paste0(fdirs$outdatadir,'Target_FID_and_Yi_fulldomain_NPV_at_MSY_noAqua.csv'),header=FALSE)[,2][Aqua.Full.Domain.Logical])/(1-((1+r)^-t))

# Load Viewshed Data
V_F.V <- (as.numeric(gsub(",", "", sector_data.df$res_views_8k)) + as.numeric(gsub(",", "",sector_data.df$park_views_8k)))[Aqua.Full.Domain.Logical]
V_MK.V  <- (as.numeric(gsub(",", "", sector_data.df$res_views_3k)) + as.numeric(gsub(",", "",sector_data.df$park_view_3k)))[Aqua.Full.Domain.Logical]

# Load Benthic Data, for cells which are not developable for fish aqua set to NA
B.V <- rep(NA,times = length(F.V))
B.V[F.V > 0] <- sector_data.df$TOC.flux[Aqua.Full.Domain.Logical][F.V > 0]

# Run the eigenvector centrality diseaase model in MATLAB and then load the results.
# Write a .mat file with the filtered connectivity matrix
filename <- paste0(fdirs$inpdatadir,"tmp.mat")
writeMat(filename,
eig = readMat(paste0(fdirs$inpdatadir,
  'disease_connect_matrix.mat'))$disease.connect.matrix[F$Annuity > 0,F$Annuity > 0])
# Character vector to send to MATLAB from R. The function eigencentrality is derived from http://strategic.mit.edu/downloads.php?page=matlab_networks
code <- c("cd(strcat(pwd,\'/MSP_Model/Scripts/\'));",paste0('load \'',filename,'\';'),'d = abs(eigencentrality(eig));',
'save(\'tmp.mat\',\'d\')')
# Send arguments to matlab
run_matlab_code(code)
# Read the Mat file and remove the temporary one
D.V <- rep(NA,times = length(F.V))
D.V[F.V > 0] <- readMat(paste0(fdirs$scrpdir,'tmp.mat'))$d
system2('rm',args = paste0(filename))
# Save all of the raw outputs of each sector model in a seperate file --> do later
print('Raw Impacts/Value.....')
Raw_Impacts <- data.frame(Mussel = M.V, Finfish = F.V, Kelp = K.V, Halibut = H.V,
  Viewshed_Mussel_Kelp = V_MK.V, Viewshed_Finfish = V_F.V, Benthic_Impacts = B.V,
  Disease_Risk = D.V) %>% glimpse()
# Make a .mat file of the sector files
writeMat(paste0(fdirs$inpdatadir,'Raw_Impacts.mat'),Raw_Impacts = Raw_Impacts)
## Tradeoff Model
# Define parameters for the model
sector_names <- names(Raw_Impacts)
n <- 7 # Number of sectors
i <- 1061 # Number of sites, nrow(Raw_Impacts)
p <- 4 # Number of management options, 0 = no development, 1 = develop mussel, 2 = develop finfish, 3 = develop kelp, 4 = no development
# Using the definied parameters derive variable V_n_i_p (value to sector n at site i for pursuing development option p)
p_options <- list(c('Halibut'),c('Mussel','Viewshed_Mussel_Kelp'),c('Finfish','Viewshed_Finfish','Benthic_Impacts','Disease_Risk'),c('Kelp','Viewshed_Mussel_Kelp'))
# Make a list of dataframes consiting of the responses for each policy p for each sector n at each site i
R_n_i_p <- setNames(lapply(1:p,df = Raw_Impacts,FUN = function(x,df){
      # Make the dataframe for each policy
      tmp <- setNames(data.frame(t(do.call('rbind',lapply(1:length(sector_names), FUN = function(y){
        if(sector_names[y] %in% p_options[[x]]){
          return(df[[y]])
        }else{
          # For a sector recieving zero value or full impact set sector values to zero unless they were previously set as NA
          df[[y]][!is.na(df[[y]])] <- 0
          return(df[[y]])
        }
        })))),sector_names)
    }),c('No_Development','Develop_Mussel','Develop_Finfish','Develop_Kelp'))
# Add in the ifelse to make it comparable to lines 52 - 88 in CW code
R_n_i_p[[1]] <- R_n_i_p[[1]] %>%
  mutate(Viewshed = 0) %>%
  select(-Viewshed_Finfish,-Viewshed_Mussel_Kelp) %>% select(Mussel,Finfish,Kelp,Halibut,Viewshed,Benthic_Impacts,Disease_Risk)
R_n_i_p[[2]] <- R_n_i_p[[2]] %>%
  mutate(Viewshed = Viewshed_Mussel_Kelp) %>% mutate(Halibut = ifelse(Mussel == 0,Raw_Impacts$Halibut,0)) %>%
  mutate(Viewshed = ifelse(Mussel > 0,Raw_Impacts$Viewshed_Mussel_Kelp,0)) %>%
  select(-Viewshed_Finfish,-Viewshed_Mussel_Kelp) %>% select(Mussel,Finfish,Kelp,Halibut,Viewshed,Benthic_Impacts,Disease_Risk)
R_n_i_p[[3]] <- R_n_i_p[[3]] %>%
  mutate(Viewshed = Viewshed_Finfish) %>% mutate(Halibut = ifelse(Finfish == 0,Raw_Impacts$Halibut,0)) %>%
  mutate(Viewshed = ifelse(Finfish > 0,Raw_Impacts$Viewshed_Finfish,0)) %>%
  select(-Viewshed_Finfish,-Viewshed_Mussel_Kelp) %>% select(Mussel,Finfish,Kelp,Halibut,Viewshed,Benthic_Impacts,Disease_Risk)
R_n_i_p[[4]] <- R_n_i_p[[4]] %>%
  mutate(Viewshed = Viewshed_Mussel_Kelp) %>% mutate(Halibut = ifelse(Kelp == 0,Raw_Impacts$Halibut,0)) %>%
  mutate(Viewshed = ifelse(Kelp > 0,Raw_Impacts$Viewshed_Mussel_Kelp,0)) %>%
  select(-Viewshed_Finfish,-Viewshed_Mussel_Kelp) %>% select(Mussel,Finfish,Kelp,Halibut,Viewshed,Benthic_Impacts,Disease_Risk)
true_sector_names <- names(R_n_i_p[[1]])
# For sectors whose response is negative, calculate R_bar
R_negative_sector_names <- names(R_n_i_p[[1]])[grepl(c('Viewshed|Benthic_|Disease_'),names(R_n_i_p[[1]]))]
R_bar_n <- setNames(data.frame(t(do.call('rbind',lapply(1:length(R_negative_sector_names), data = lapply(R_n_i_p, R_negative_sector_names, FUN = function(x,y){
  apply(x[names(x) %in% R_negative_sector_names],MARGIN = 2, FUN = function(x) max(x,na.rm = T))
  }),FUN = function(x,data){
    max(sapply(data,"[",x),na.rm = T)
    })))),R_negative_sector_names)
# apply(sapply(1:1061,FUN = function(x){apply(data.frame(do.call("rbind",lapply(V_n_i_p,"[",x,))),MARGIN = 2,FUN = sum)}),MARGIN = 1,FUN = sum,na.rm=T)
# Then calculate V_n_i_p based on the response of each sector (Supp. Info, Eq. S26)
V_n_i_p <- setNames(lapply(1:p, df = R_n_i_p, df_bar = R_bar_n, FUN = function(x, df, df_bar){
  setNames(data.frame(t(do.call('rbind',lapply(1:length(names(R_n_i_p[[x]])), FUN = function(y){
    if(names(df[[x]])[y] %in% R_negative_sector_names){
      return(R_bar_n[[names(df[[x]])[y]]] - df[[x]][,y])
    }else{
      return(df[[x]][,y])
    }
    })))),names(R_n_i_p[[x]]))
  }), c('No_Development','Develop_Mussel','Develop_Finfish','Develop_Kelp'))

X_n_i_p <- setNames(lapply(1:p, df = V_n_i_p, FUN = function(p,df){
      return(setNames(data.frame(t(do.call('rbind',lapply(1:length(true_sector_names), FUN = function(n){
        df[[p]][,n] / sum(apply(sapply(df,"[", ,n),MARGIN = 1, FUN = function(z){ifelse(!all(is.na(z)),max(z, na.rm = T),NA)}),na.rm = T)
      })))),true_sector_names))
  }),c('No_Development','Develop_Mussel','Develop_Finfish','Develop_Kelp'))
# Create the sector weights (alpha's)
library(gtools)
epsilon <- .20 # Epsilon step size, default is 0.20
a_values <- seq(from = 0, to = 1, by = epsilon) # The unique values for each sector and site
a <- permutations(n = length(a_values),7,a_values,repeats.allowed=T)
# Find the optimal policy option for each site in a given, alpha
if(readline('Perform Full Analysis? Y/N ') == 'Y'){
  print('Finding optimal solutions.................')
  print_a <- seq(from = 0, to = nrow(a), by = 10000)
  obj_i <- sapply(1:nrow(a), FUN = function(x){
    if(x %in% print_a){print(paste0(x,' iterations'))}
    apply(sapply(1:p, df = X_n_i_p, FUN = function(y,df){
      apply(data.frame(mapply('*',df[[y]],c(a[x,]),SIMPLIFY = FALSE)), MARGIN = 1, FUN = function(z) sum(z,na.rm = T)) # Multiply each i for a given p by the sector specific weight set by a given row of the alpha matrix
      }),MARGIN = 1, which.max) - 1
  })
  # # Save model results
  write.table(x = data.frame(obj_i,stringsAsFactors = F),file = file.path(paste0(fdirs$outdatadir,'MSP_Planning_Results.csv')), sep = ",",quote = FALSE, col.names = FALSE, row.names = FALSE)
}else{
  print('loading planning results')
  obj_i <- read.csv(file.path(paste0(fdirs$outdatadir,'MSP_Planning_Results.csv')))
}
# Convert the plans to actual values1
# Add aquaculture indices information
Aqua_Dev_Indices = which(Aqua.Full.Domain.Logical)
writeMat(paste0(fdirs$inpdatadir,'Aqua_Dev_Indices.mat'),Aqua_Dev_Indices = which(Aqua.Full.Domain.Logical))
# Load Halibut Model
print("Launching MATLAB.....");
system2(matlab_root,
  args = c('-r',
  paste0("run\\(\\'",fdirs$scrpdir,"Dynamic_Evaluation_Files/SCB_MSP_Dynamic.m\\'\\)")))
# # Plot Data
# current.directory.scripts='~/Desktop/Code/MS Figures/'
# setwd(current.directory.scripts)
# theme = theme(plot.margin = unit(c(.2,.2,.2,.2), units = "lines"),
#                 axis.text = element_blank(),
#                 axis.title = element_blank(),
#                 axis.ticks = element_blank(),
#                 axis.ticks.length = unit(0, "lines"),
#                 axis.ticks.margin = unit(0, "lines"),
#                 panel.background=element_rect(fill="white"),
#                 panel.grid=element_blank(),
#                 plot.title=element_text(hjust=0))
#     labs = labs(x = NULL, y = NULL)
# # png(paste0(current.directory.scripts,'MS_Figures.png'),onefile = T,units=units,width=width, height=height, res=res)
# for(itor in 1:2){
# if(itor==1){
#   png(paste0(current.directory.scripts,'PNGs/Fig 1.png'),units=units,width=width, height=height, res=res)
# }else{
#   pdf(paste0(current.directory.scripts,'PDFs/Fig 1.pdf'), width=width, height=height,paper='legal')
# }
#   # img <- readTIFF("fig1_Stevens_v3.tif",native=T,info=T)
#   # g <- rasterGrob(img, interpolate=TRUE)
#   img <- readPNG("~/Desktop/Code/Fig1A Capture.png",native=T,info=T)
#   g <- rasterGrob(img, interpolate=TRUE)
#
#   a<-qplot(1:10, 1:10, geom="blank") + annotation_custom(g, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf) + ggtitle('A') +
#     theme + labs
#
#   img_mussel <- readPNG("~/Desktop/Code/MusselValueApril.png",native=T,info=T)
#   g_mussel <- rasterGrob(img_mussel, interpolate=TRUE)
#
#   foo <- 5.58
#   store <- NULL
#   for(itor in 1:9){
#     foo <- foo - .341
#     store[itor] <- foo
#     # print(a)
#   }
#
#   b <- qplot(1:10, 1:10, geom="blank") + ggtitle('B') + annotation_custom(g_mussel, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf) +
#     theme +
#     # annotate(geom='text',x = c(1.75,1.83,1.83,1.83,1.92,1.92,1.92,1.92,1.89),
#     #   y = store,label=c('0-6','6-6.5','6.5-7','7-7.5','7.5-8.0','8.0-8.5','8.5-9.0','9.0-9.5','9.5-10')) +
#     labs
#   # ggsave(filename = "~/Desktop/Code/MusselValueApril_Edit.png",b,device = 'png',dpi = res)
#
#   foo <- 5.57
#   store <- NULL
#   for(itor in 1:9){
#     foo <- foo - .35
#     store[itor] <- foo
#     # print(a)
#   }
#
#   img_finfish <- readPNG("~/Desktop/Code/FishValueApril.png",native=T,info=T)
#   g_finfish <- rasterGrob(img_finfish, interpolate=TRUE,just='center')
#
#   c<-qplot(1:10, 1:10, geom="blank") + ggtitle('C') + annotation_custom(g_finfish, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf) +
#     theme +
#     # annotate(geom='text',x = c(1.87,1.97,1.92,1.92,1.92,1.92,1.92,1.92,1.92),
#     #   y = store,label=c('0-0.01','0.01-0.4','0.4-0.8','0.8-1.2','1.2-1.6','1.6-2.0','2.0-2.4','2.4-2.8','2.8-3.2')) +
#     labs
#   # ggsave(filename = "~/Desktop/Code/FishValueApril_Edit.png",c,device = 'png',dpi = res)
#
#   img_kelp <- readPNG("~/Desktop/Code/KelpValueApril.png",native=T,info=T)
#   g_kelp <- rasterGrob(img_kelp, interpolate=TRUE, just='center')
#
#   # foo <- 5
#   # store <- NULL
#   # for(itor in 1:9){
#   #   foo <- foo - 0.375
#   #   store[itor] <- foo
#   #   # print(a)
#   # }
#
#   foo <- 5.58
#   store <- NULL
#   for(itor in 1:10){
#     foo <- foo - .315
#     store[itor] <- foo
#     # print(a)
#   }
# # annotate(geom='text',x = c(rep(.75,ts=7),.75+.09,.75+.09)
# # store[length(store) - 2] <- store[length(store) - 2] + .1
# # store[length(store) - 2] <- store[length(store) - 1] + .2
#   d<-qplot(1:10, 1:10, geom="blank") + ggtitle('D') + annotation_custom(g_kelp, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf) +
#     theme +
#     # annotate(geom='text',x = c(1.75,1.83,1.83,1.83,1.92,1.92,1.92,1.92,1.89),
#     #   y = store,label=c('0-3','3-4','4-5','5-6','6-7','7-8','8-9','9-10','10-12'),size = 3.85) +
#      # annotate(geom='text',x = c(1.75,1.75,1.75,1.75,1.75,1.75,1.75,1.75,1.75,1.80),
#      #  y = store,label=c('0-1','1-2','2-3','3-4','4-5','5-6','6-7','7-8','8-9','10-12')) +
#     labs #+
#     # scale_x_continuous(breaks = seq(0, 10, .25)) +
#     # scale_y_continuous(breaks = seq(0, 10, .25)) +
#     # theme(panel.ontop=TRUE,panel.background = element_rect(colour = NA,fill="transparent"),panel.grid.minor = element_blank(),panel.grid.major=element_line(color = 'black'))
#   # ggsave(filename = "~/Desktop/Code/KelpValueApril_Edit.png",d)
#
#   grid.arrange(a,b,c,d,ncol=2,nrow=2)
#                  # bottom = textGrob(expression(bold('Fig 1: ')~plain('Study domain, spatial constraints and potential value for aquaculture development. (A) Spatial constraints to aquaculture development in the Southern California Bight. (B-D) Potential value (10- year NPV) in each developable cell for mussel, finfish, and kelp aquaculture sectors.')),
#                  #                   x=1,just='left'))
#   if(itor == 1){
#       dev.off()
#     }else{
#       dev.off()
#     }
# }
# # Figure 2
# # pdf(paste0(current.directory.scripts,'Fig 2.pdf'),width=8, height=6.4,paper='legal')
# # img_MSP <- readPNG(paste0(current.directory.scripts,'Fig 2.png'),native=T,info=T)
# #   g_MSP <- rasterGrob(img_MSP, interpolate=TRUE, just='center')
# #   qplot(1:10, 1:10, geom="blank") + annotation_custom(g_MSP, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf) +
# #     theme + labs
# # dev.off()
#   # png(paste0(current.directory.scripts,'MS_Figures.png'),onefile = T, width=8, height=6.4,res=res,units=units)
# for(itor in 1){
#   if(itor==1){
#     png(paste0(current.directory.scripts,'PNGs/Fig 2.png'),width=8, height=6.4,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.scripts,'PDFs/Fig 2.pdf'),width=8, height=6.4,paper='legal')
#   }
#   panel.EF<-function (x, y, itor=0, epsilon=.001, bg = NA, pch = 20, cex = .01, ...)
#   {
#     x.MSP=x[color.vector=='coral']
#     y.MSP=y[color.vector=='coral']
#
#     points(x.MSP,y.MSP, pch = 16, col = alpha("dodgerblue",1/75),cex = cex/2)
#     x.U=x[color.vector=='purple']
#     y.U=y[color.vector=='purple']
#     x.S=x[color.vector=='green']
#     y.S=y[color.vector=='green']
#     x.EF=NULL
#     y.EF=NULL
#     alpha.mat.tmp=seq(from=0,by=epsilon,to=1)
#     # MSP
#     for(itor in 1:length(alpha.mat.tmp)){
#       alpha.tmp=alpha.mat.tmp[itor]
#       A=(alpha.tmp*x.MSP)+((1-alpha.tmp)*y.MSP)
#       I=which(A==max(A))
#       x.EF[itor]=max(unique(x.MSP[I]))
#       I.tmp.x=which(x.MSP==max(unique(x.MSP[I])))
#       I.tmp.y=which(y.MSP[I.tmp.x]==max(unique(y.MSP[I.tmp.x])))
#       y.EF[itor]=unique(y.MSP[I.tmp.x[I.tmp.y]])}
#     x.EF.original=x.EF;y.EF.original=y.EF;
#     if(length(unique(x.EF.original))!=1&length(unique(x.EF.original))!=1){
#       EF.inter=approx(x.EF.original,y=y.EF.original,n=length(alpha.mat.tmp))
#       x.EF=EF.inter$x;y.EF=EF.inter$y;
#     }else{
#     }
#     lines(sort(x.EF),y.EF[order(x.EF)],col="midnightblue",lwd=2,lty=1)
#     lines(sort(x.U),y.U[order(x.U)],col = "mediumorchid1",lwd=2,lty=1)
#     lines(sort(x.S),y.S[order(x.S)],col = "coral1",lwd=2,lty=1)
#   }
#   #   pdf.options(width = 8, height = 6.4)
#   source('~/Desktop/Code/pairs2.R')
#   color.vector=color.vector.max
#    # Color Vector For Seperating the MSP from Conventional Solutions
#   # sample <- rbind(MM_test.df %>% filter(Set == 'MSP') %>% sample_n(size = 1000),
#   #   MM_test.df %>% filter(Set == 'U') %>% sample_n(size = 500),
#   #   MM_test.df %>% filter(Set == 'C') %>% sample_n(size = 500))
#   pairs2(100*Master.matrix.max,lower.panel=panel.EF,
#          upper.panel=NULL,col=color.vector,cex=0.8,xlim=c(0,100),
#          ylim=c(0,100),pch=16,font.labels=3,cex.axis=1,las=1,xaxp=c(0,100,4),yaxp=c(0,100,2),
#          gap=1)
#   # title(xlab='% of Maximum',line = 1)
#   title(ylab='% of Maximum')
#   par(xpd=T)
#   l1<-legend(.33,1,
#              legend=c('7D Frontier','2D Frontier'),fill=c("lightblue1","midnightblue"),
#              cex=.75,title=expression(bold('Marine Spatial Planning (MSP)')),
#              title.adj = 0, bty = 'n', adj = 0, text.width=.25)
#   l2<-legend(x = l1$rect$left+.0020, y = with(l1$rect, top - h)-.005,
#              legend=c('Constrained','Unconstrained'),fill=c("coral1","mediumorchid1"),
#              cex=.75,title=expression(bold('Conventional Planning ')),
#              title.adj = 0, bty = 'n', adj = 0, text.width=.25)
#   inset.figure.proportion = 1/3
#   inset.figure.dims = c(rep(width*(inset.figure.proportion),ts = 2))
#   subplot(source(file='~/Desktop/Code/Tradeoff Cartoon.R'),x='topright',size = inset.figure.dims, type='plt', par = list(cex.main=2.5, cex = .45, lwd = 1))
#   par(oma=c(0,2,2,0))
#   title('A', adj = 0, outer = T, cex = .75)
#   title(xlab='% of Maximum',line = 3.5)
#   if(itor == 1){
#     dev.off()
#   }else{
#     dev.off()
#   }
# }
# # Figure 3
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.scripts,'PNGs/Fig 3.png'),width=width, height=height,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.scripts,'PDFs/Fig 3.pdf'),width=width, height=height,paper='legal')
#   }
# # png(paste0(current.directory.scripts,'MS_Figures.png'),onefile = T, width=width, height=height,res=res,units=units)
#
#   img_hot_all <- readPNG("~/Desktop/Code/HotSpots_ALL_Joel.png",native=T,info=T)
#   g_hot_all <- rasterGrob(img_hot_all, interpolate=TRUE)
#
#   a<-qplot(1:10, 1:10, geom="blank") + ggtitle('A') +
#     annotation_custom(g_hot_all, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme + labs
#
#   img_hot_mussel <- readPNG("~/Desktop/Code/HotSpots_Mussels_Joel.png",native=T,info=T)
#   g_hot_mussel <- rasterGrob(img_hot_mussel, interpolate=TRUE)
#
#   b<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_hot_mussel, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme + labs
#
#   img_hot_finfish <- readPNG("~/Desktop/Code/HotSpots_Fish_Joel.png",native=T,info=T)
#   g_hot_finfish <- rasterGrob(img_hot_finfish, interpolate=TRUE,just='center')
#
#   c<-qplot(1:10, 1:10, geom="blank") + ggtitle('C') +
#     annotation_custom(g_hot_finfish , xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme + labs
#
#   img_hot_kelp <- readPNG("~/Desktop/Code/HotSpots_Kelp_Joel.png",native=T,info=T)
#   g_hot_kelp <- rasterGrob(img_hot_kelp, interpolate=TRUE, just='center')
#
#   d<-qplot(1:10, 1:10, geom="blank") + ggtitle('D') +
#     annotation_custom(g_hot_kelp, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme + labs
#   grid.arrange(a,b,c,d,ncol=2,nrow=2,padding=unit(.1,'line'))
#   dev.off()
# }
# #  pdf(paste0(current.directory.scripts,'Fig 4.pdf'),width=width, height=height,paper='legal')
# # img_MSP <- readPNG(paste0(current.directory.scripts,'PNGs/Fig 4.png'),native=T,info=T)
# # g_MSP <- rasterGrob(img_MSP, interpolate=TRUE, just='center')
# # qplot(1:10, 1:10, geom="blank") + annotation_custom(g_MSP, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf) +
# #   theme + labs
# # dev.off()
#
# # Figure 4
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.scripts,'PNGs/Fig 4.png'),width=width, height=height,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.scripts,'PDFs/Fig 4.pdf'),width=width, height=height,paper='legal')
#   }
#   Low.impact.solutions=Static.values.data[I,]
#   LI.names=names(Low.impact.solutions)
#   ID=seq(to=nrow(Low.impact.solutions),from=1,by=1)
#   size.tmp=dim(Low.impact.solutions)
#   Mussel.LI=Low.impact.solutions[,1]
#   Finfish.LI=Low.impact.solutions[,2]
#   Kelp.LI=Low.impact.solutions[,3]
#   Halibut.LI=Low.impact.solutions[,4]
#   View.LI=Low.impact.solutions[,5]
#   Benthic.LI=Low.impact.solutions[,6]
#   Disease.LI=Low.impact.solutions[,7]
#   Sector.LI=c(rep(LI.names[1],ts=size.tmp[1]),
#               rep(LI.names[2],ts=size.tmp[1]),
#               rep(LI.names[3],ts=size.tmp[1]),
#               rep(LI.names[4],ts=size.tmp[1]),
#               rep(LI.names[5],ts=size.tmp[1]),
#               rep(LI.names[6],ts=size.tmp[1]),
#               rep(LI.names[7],ts=size.tmp[1]))
#   for(itor in 1:ncol(Low.impact.solutions)){
#     ID.LI.tmp=1:size.tmp[1]
#     if(itor>1){
#       ID.LI=c(ID.LI,ID.LI.tmp)
#     }else{
#       ID.LI=ID.LI.tmp
#     }
#   }
#   value.LI.tmp=c(Mussel.LI,Finfish.LI,Kelp.LI,Halibut.LI,View.LI,Benthic.LI,Disease.LI)
#   Low.impact.solutions=data.frame(ID.LI,value.LI.tmp,Sector.LI)
#   names(Low.impact.solutions)=c('ID','Value','Sector')
#   Low.impact.solutions$Sector=factor(Low.impact.solutions$Sector, levels=c('Mussel','Finfish','Kelp','Halibut','Viewshed','Benthic','Disease'))
#   p.bar<-ggplot(data = Low.impact.solutions,aes(x=ID,y=Value,fill=Sector,color=Sector))+
#     geom_bar(stat="identity")+facet_grid(.~Sector)+ggtitle('A')+
#     scale_y_continuous(labels = percent,limits=c(0,1))+
#     scale_fill_manual(values=cols)+
#     scale_color_manual(values=cols)+
#     theme(axis.title.x=element_blank(),
#           axis.text.x=element_blank(),
#           axis.ticks.x=element_blank(),
#           panel.background=element_rect(color='white',fill='white'),panel.spacing = unit(.75, "lines"),
#           strip.background=element_rect(fill='white'),strip.text=element_text(size=text.size*.75),
#           panel.grid=element_blank(),axis.title.y=element_text(size=text.size,color="black"),
#           axis.text.y=element_text(size=text.size,color="black"),legend.title=element_text(size=text.size*.75),
#           legend.text=element_text(size=text.size),plot.title=element_text(hjust=0))
#
#   img_case_study_percent <- readPNG("~/Desktop/Code/CaseStudyPercentage_August.png",native=T,info=T)
#   g_case_study_percent <- rasterGrob(img_case_study_percent, interpolate=TRUE,just='center')
#
#   p.map<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_case_study_percent, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme(plot.margin = unit(c(.2,.2,.4,.2), units = "lines"),axis.text.x = element_blank(),axis.text.y = element_blank(),axis.ticks = element_blank(),
#           axis.title=element_blank(),panel.background=element_rect(fill="white"),panel.grid=element_blank(),
#           plot.title=element_text(hjust=0))
#
#   img_case_study_plan <- readPNG("~/Desktop/Code/CaseStudySpecies_August.png",info=T)
#   g_case_study_plan <- rasterGrob(img_case_study_plan, interpolate=TRUE,just='center')
#
#   p.map.case.study<-qplot(1:10, 1:10, geom="blank") + ggtitle('C') +
#     annotation_custom(g_case_study_plan , xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme(plot.margin = unit(c(.2,.2,.4,.2), units = "lines"),axis.text.x = element_blank(),axis.text.y = element_blank(),axis.ticks = element_blank(),
#           axis.title=element_blank(),panel.background=element_rect(fill="white"),panel.grid=element_blank(),
#           plot.title=element_text(hjust=0))
#
#   p.bar.case.study <- ggplot(data = Low.impact.solutions[Low.impact.solutions$ID==576,],
#                              aes(x=ID,y=Value,fill=Sector,color=Sector))+ggtitle('D')+
#     geom_bar(stat="identity")+facet_grid(.~Sector)+
#     scale_y_continuous(labels = percent,limits=c(0,1))+
#     scale_fill_manual(values=cols)+
#     scale_color_manual(values=cols)+
#     theme(axis.ticks.x=element_blank(),axis.title.x=element_blank(),
#           axis.title.y=element_blank(),axis.text.x=element_blank(),
#           panel.background=element_rect(color='white',fill='white'),
#           strip.background=element_rect(fill='white'),strip.text=element_blank(),
#           panel.grid=element_blank(),
#           axis.text.y=element_blank(),axis.ticks=element_blank(),legend.position='none',plot.title=element_text(hjust=0),plot.margin = unit(c(.2,.2,.2,.2), "cm"))
#   g=ggplotGrob(p.bar.case.study)
#   p.map.case.study.full<-p.map.case.study+annotation_custom(grob=g,xmin=5.5,xmax=10.25,ymin=7.5)
#   grid.arrange(p.bar,p.map,p.map.case.study.full,ncol=2,nrow=2,layout_matrix = rbind(c(1,1),c(2,3)))
#   dev.off()
# }
#   # pdf.options(width = 9.5, height = 7)
# # Figure 5
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.scripts,'PNGs/Fig 5.png'),width=8, height=8,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.scripts,'PDFs/Fig 5.pdf'),width=8, height=8,paper='legal')
#   }
#   source('~/Desktop/Code/value.of.MSP.loop_interpol.R')
#   source('~/Desktop/Code/value.of.MSP.fx_2_interpol.R')
#   source('~/Desktop/Code/figure_5_code.R')
#   MSP.value.data=rbind(Mussel.value.tmp,Finfish.value.tmp,Kelp.value.tmp)
#   MSP.value.data.points=rbind(Mussel.value.tmp.points,Finfish.value.tmp.points,Kelp.value.tmp.points)
#   names(MSP.value.data)=c('Aquaculture.Value','Value.of.MSP','Group','Sector.Name','Sector.Type','Type.of.Conventional')
#   names(MSP.value.data.points)=c('Aquaculture.Value','Value.of.MSP','Group','Sector.Name','Sector.Type','Type.of.Conventional')
#   MSP.value.data$Sector.Name=factor(MSP.value.data$Sector.Name,levels=c('Mussel','Finfish','Kelp','Halibut','Viewshed','Benthic','Disease'))
#   Value.of.MSP.grid.plot<-ggplot(data=MSP.value.data)+
#     geom_point(data=subset(MSP.value.data[as.integer(MSP.value.data$Group)!=as.integer(MSP.value.data$Sector.Name),]),
#                aes(x=Aquaculture.Value,y=Value.of.MSP,shape=Type.of.Conventional,color=Type.of.Conventional),size=1.25)+
#     facet_grid(Sector.Name~Group)+scale_y_continuous(labels = percent,limits=c(0,1),breaks=c(0,.5,1))+
#     scale_x_continuous(labels = percent,breaks=c(0,.5,1))+
#     geom_text(data=subset(MSP.value.data[as.integer(MSP.value.data$Group)==as.integer(MSP.value.data$Sector.Name),]),x=.5,y=.5,size=15,label='NA')+
#     geom_point(data=MSP.value.data.points,aes(x=Aquaculture.Value,y=Value.of.MSP,shape=Type.of.Conventional,color=Type.of.Conventional),size=1.2)+
#     xlab("Aquaculture Value")+ylab("Value of Marine Spatial Planning")+
#     scale_colour_manual(name = "Conventional Planning :",labels=c("Constrained","Unconstrained"),values=c("coral1","mediumorchid1"))+
#     scale_shape_manual(name = "Conventional Planning :",labels=c("Constrained","Unconstrained"),values=c(16,24))+
#     scale_fill_manual(name = "Conventional Planning :",labels=c("Constrained","Unconstrained"),values=c("coral1","mediumorchid1"))+
#     #     geom_line(aes(x=c(0,1),y=c(0,0)),color="grey",linetype='dashed',size=1)+
#     theme_bw(base_size = 15)+theme(panel.grid=element_blank(),legend.position="bottom")
#   Value.of.MSP.grid.plot+theme(axis.title=element_text(size=12),panel.spacing = unit(1, "lines"),
#                                strip.background=element_rect(fill='white'),strip.text=element_text(size=10),axis.ticks.margin=unit(1,'lines'))
#   dev.off()
# }
#
# # ## Combine Figures
# # require(png)
# # require(grid)
# # png(paste0(current.directory.scripts,'/PNGs/MS_Figures.png'))
# # lapply(ll <- list.files(path = '~/Desktop/Code/MS Figures/PNGs',patt='.*[.]png'),function(x){
# #   img <- as.raster(readPNG(paste0('~/Desktop/Code/MS Figures/PNGs/',x)))
# #   grid.newpage()
# #   grid.raster(img, interpolate = FALSE)
#
# # })
# # dev.off()
#
#
#
#
# # plots <- lapply(ll <- list.files(path = paste0(current.directory.scripts,'PNGs/'), patt='.*[.]png'),function(x){
# #   img <- as.raster(readPNG(x))
# #   rasterGrob(img, interpolate = FALSE)
# # })
# # require(ggplot2)
# # require(gridExtra)
# # ggsave("multipage.pdf", marrangeGrob(grobs=plots, nrow=2, ncol=2))
#
#
#
# ## Figure 1
# ## SI Figures
# current.directory.code <- '~/Desktop/Code/SI Figures Code/'
# current.directory.figures <- '~/Desktop/Code/SI Figures/'
# # Coastline.data<-read.csv(file='Coastline.csv',header=F)
# theme_3 = theme(plot.margin = unit(c(.1,.1,.1,.1), units = "lines"),
#               axis.text = element_blank(),
#               axis.title = element_blank(),
#               axis.ticks = element_blank(),
#               # axis.ticks.length = unit(0, "lines"),
#               # axis.ticks.margin = unit(0, "lines"),
#               panel.background=element_rect(fill="white"),
#               panel.grid=element_blank(),
#               plot.title=element_text(hjust =.35,vjust=.1))
#
# theme_2 = theme(plot.margin = unit(c(.1,.1,.1,.1), units = "lines"),
#               axis.text = element_blank(),
#               axis.title = element_blank(),
#               axis.ticks = element_blank(),
#               # axis.ticks.length = unit(0, "lines"),
#               # axis.ticks.margin = unit(0, "lines"),
#               panel.background=element_rect(fill="white"),
#               panel.grid=element_blank(),
#               plot.title=element_text(hjust =.30,vjust=.1))
#
# labs = labs(x = NULL, y = NULL)
# # Figure S1
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.figures,'PNGs/Fig S1.png'),width=width, height=height,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.figures,'PDFs/Fig S1.pdf'),width=width, height=height,paper='legal')
#   }
#   img_s1 <- readPNG(paste0(current.directory.code,'Fig S1.png'),native=T,info=T)
#   g_s1 <- rasterGrob(img_s1, interpolate=TRUE)
#
#   s1<-qplot(1:10, 1:10, geom="blank") +
#     annotation_custom(g_s1, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#   print(s1)
#   dev.off()}
# # Figure S2
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.figures,'PNGs/Fig S2.png'),width=width, height=height,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.figures,'PDFs/Fig S2.pdf'),width=width, height=height,paper='legal')
#   }
#   img_S2A <- readPNG(paste0(current.directory.code,"S2A.png"),native=T,info=T)
#   g_S2A <- rasterGrob(img_S2A, interpolate=TRUE)
#
#   S2A<-qplot(1:10, 1:10, geom="blank") + ggtitle('A') +
#     annotation_custom(g_S2A, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#
#   img_S2B <- readPNG(paste0(current.directory.code,"S2B.png"),native=T,info=T)
#   g_S2B <- rasterGrob(img_S2B, interpolate=TRUE)
#
#   S2B<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_S2B, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#
#   img_S2C <- readPNG(paste0(current.directory.code,"S2C.png"),native=T,info=T)
#   g_S2C <- rasterGrob(img_S2C, interpolate=TRUE)
#
#   S2C<-qplot(1:10, 1:10, geom="blank") + ggtitle('C') +
#     annotation_custom(g_S2C, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#
#   grid.arrange(S2A,S2B,S2C,ncol=1,nrow=3,padding=unit(-.1,'line'))
#   dev.off()}
# # S3
#   for(itor in 1:2){
#     if(itor==1){
#       png(paste0(current.directory.figures,'PNGs/Fig S3.png'),width=width, height=height,res=res,units=units)
#     }else{
#       pdf(paste0(current.directory.figures,'PDFs/Fig S3.pdf'),width=width, height=height,paper='legal')
#     }
#   img_S3A <- readPNG(paste0(current.directory.code,"S3A.png"),native=T,info=T)
#   g_S3A <- rasterGrob(img_S3A, interpolate=TRUE)
#
#   S3A<-qplot(1:10, 1:10, geom="blank") + ggtitle('A') +
#     annotation_custom(g_S3A, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#
#   img_S3B <- readPNG(paste0(current.directory.code,"S3B.png"),native=T,info=T)
#   g_S3B <- rasterGrob(img_S3B, interpolate=TRUE)
#
#   S3B<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_S3B, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#
#   img_S3C <- readPNG(paste0(current.directory.code,"S3C.png"),native=T,info=T)
#   g_S3C <- rasterGrob(img_S3C, interpolate=TRUE)
#
#   S3C<-qplot(1:10, 1:10, geom="blank") + ggtitle('C') +
#     annotation_custom(g_S3C, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#   grid.arrange(S3A,S3B,S3C,ncol=1,nrow=3,padding=unit(-.1,'line'))
#   dev.off()}
# # S4
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.figures,'PNGs/Fig S4.png'),width=width, height=height,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.figures,'PDFs/Fig S4.pdf'),width=width, height=height,paper='legal')
#   }
#   img_s4 <- readPNG(paste0(current.directory.code,"Fig S4.png"),native=T,info=T)
#   g_s4 <- rasterGrob(img_s4, interpolate=TRUE)
#
#   s4<-qplot(1:10, 1:10, geom="blank") +
#     annotation_custom(g_s4, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#   print(s4)
#   dev.off()}
# # S5
#   for(itor in 1:2){
#     if(itor==1){
#       png(paste0(current.directory.figures,'PNGs/Fig S5.png'),width=width, height=height,res=res,units=units)
#     }else{
#       pdf(paste0(current.directory.figures,'PDFs/Fig S5.pdf'),width=width, height=height,paper='legal')
#     }
#
#   img_S5A <- readPNG(paste0(current.directory.code,"S5A.png"),native=T,info=T)
#   g_S5A <- rasterGrob(img_S5A, interpolate=TRUE)
#
#   S5A<-qplot(1:10, 1:10, geom="blank") + ggtitle('A') +
#     annotation_custom(g_S5A, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_2 + labs
#
#   img_S5B <- readPNG(paste0(current.directory.code,"S5B.png"),native=T,info=T)
#   g_S5B <- rasterGrob(img_S5B, interpolate=TRUE)
#
#   S5B<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_S5B, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_2 + labs
#
#   grid.arrange(S5A,S5B,ncol=1,nrow=2,padding=unit(-.1,'line'))
#   dev.off()}
# # S6
# for(itor in 1:2){
#   if(itor==1){
#      png(paste0(current.directory.figures,'PNGs/Fig S6.png'),width=width, height=height,res=res,units=units)
#   }else{
#      pdf(paste0(current.directory.figures,'PDFs/Fig S6.pdf'),width=width, height=height,paper='legal')
#   }
#   img_S6A <- readPNG(paste0(current.directory.code,"S6A.png"),native=T,info=T)
#   g_S6A <- rasterGrob(img_S6A, interpolate=TRUE)
#
#   S6A<-qplot(1:10, 1:10, geom="blank") + ggtitle('A') +
#     annotation_custom(g_S6A, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_2 + labs
#
#   img_S6B <- readPNG(paste0(current.directory.code,"S6B.png"),native=T,info=T)
#   g_S6B <- rasterGrob(img_S6B, interpolate=TRUE)
#
#   S6B<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_S6B, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_2 + labs
#
#   grid.arrange(S6A,S6B,ncol=1,nrow=2,padding=unit(-.1,'line'))
#   dev.off()
# }
# # S7
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.figures,'PNGs/Fig S7.png'),width=width, height=height,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.figures,'PDFs/Fig S7.pdf'),width=width, height=height,paper='legal')
#   }
#   img_S7A <- readPNG(paste0(current.directory.code,"S7A.png"),native=T,info=T)
#   g_S7A <- rasterGrob(img_S7A, interpolate=TRUE)
#
#   S7A<-qplot(1:10, 1:10, geom="blank") + ggtitle('A') +
#     annotation_custom(g_S7A, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs + theme(plot.title=element_text(hjust=0))
#
#   img_S7B <- readPNG(paste0(current.directory.code,"S7B.png"),native=T,info=T)
#   g_S7B <- rasterGrob(img_S7B, interpolate=TRUE)
#
#   S7B<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_S7B, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs + theme(plot.title=element_text(hjust=0))
#
#   img_S7C <- readPNG(paste0(current.directory.code,"S7C.png"),native=T,info=T)
#   g_S7C <- rasterGrob(img_S7C, interpolate=TRUE)
#
#   S7C<-qplot(1:10, 1:10, geom="blank") + ggtitle('C') +
#     annotation_custom(g_S7C, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs + theme(plot.title=element_text(hjust=0))
#
#   img_S7D <- readPNG(paste0(current.directory.code,"S7D.png"),native=T,info=T)
#   g_S7D <- rasterGrob(img_S7D, interpolate=TRUE)
#
#   S7D<-qplot(1:10, 1:10, geom="blank") + ggtitle('D') +
#     annotation_custom(g_S7D, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs + theme(plot.title=element_text(hjust=0))
#
#   grid.arrange(S7A,S7B,S7C,S7D,ncol=2,nrow=2,padding=unit(.5,'line'))
#   dev.off()
# }
# # S8
# for(itor in 1:2){
#   if(itor==1){
#     png(paste0(current.directory.figures,'PNGs/Fig S8.png'),width=width, height=height,res=res,units=units)
#   }else{
#     pdf(paste0(current.directory.figures,'PDFs/Fig S8.pdf'),width=width, height=height,paper='legal')
#   }
#   img_S8A <- readPNG(paste0(current.directory.code,"S8A.png"),native=T,info=T)
#   g_S8A <- rasterGrob(img_S8A, interpolate=TRUE)
#
#   S8A<-qplot(1:10, 1:10, geom="blank") + ggtitle('A') +
#     annotation_custom(g_S8A, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#
#   img_S8B <- readPNG(paste0(current.directory.code,"S8B.png"),native=T,info=T)
#   g_S8B <- rasterGrob(img_S8B, interpolate=TRUE)
#
#   S8B<-qplot(1:10, 1:10, geom="blank") + ggtitle('B') +
#     annotation_custom(g_S8B, xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=Inf)+
#     theme_3 + labs
#
#   grid.arrange(S8A,S8B,ncol=1,nrow=2,padding=unit(.5,'line'))
#   dev.off()
# }
#
# # # setwd('C:/Users/Joel/Desktop/Thesis YTD/Code')
# #   # panel.EF<-function (x, y, itor=0, epsilon=.001, bg = NA, pch = 20, cex = .01, ...)
# #   # {
# #   #   x.MSP=x[color.vector=='coral']
# #   #   y.MSP=y[color.vector=='coral']
# #   #
# #   #   points(x.MSP,y.MSP, pch = 16, col = alpha("dodgerblue",1/75),cex = cex/2)
# #   #   x.U=x[color.vector=='purple']
# #   #   y.U=y[color.vector=='purple']
# #   #   x.S=x[color.vector=='green']
# #   #   y.S=y[color.vector=='green']
# #   #   x.EF=NULL
# #   #   y.EF=NULL
# #   #   alpha.mat.tmp=seq(from=0,by=epsilon,to=1)
# #   #   # MSP
# #   #   for(itor in 1:length(alpha.mat.tmp)){
# #   #     alpha.tmp=alpha.mat.tmp[itor]
# #   #     A=(alpha.tmp*x.MSP)+((1-alpha.tmp)*y.MSP)
# #   #     I=which(A==max(A))
# #   #     x.EF[itor]=max(unique(x.MSP[I]))
# #   #     I.tmp.x=which(x.MSP==max(unique(x.MSP[I])))
# #   #     I.tmp.y=which(y.MSP[I.tmp.x]==max(unique(y.MSP[I.tmp.x])))
# #   #     y.EF[itor]=unique(y.MSP[I.tmp.x[I.tmp.y]])}
# #   #   x.EF.original=x.EF;y.EF.original=y.EF;
# #   #   if(length(unique(x.EF.original))!=1&length(unique(x.EF.original))!=1){
# #   #     EF.inter=approx(x.EF.original,y=y.EF.original,n=length(alpha.mat.tmp))
# #   #     x.EF=EF.inter$x;y.EF=EF.inter$y;
# #   #   }else{
# #   #   }
# #   #   lines(sort(x.EF),y.EF[order(x.EF)],col="midnightblue",lwd=2,lty=1)
# #   #   lines(sort(x.U),y.U[order(x.U)],col = "mediumorchid1",lwd=2,lty=1)
# #   #   lines(sort(x.S),y.S[order(x.S)],col = "coral1",lwd=2,lty=1)
# #   # }
# #   #   pdf.options(width = 8, height = 6.4)
# #
# #   # source('pairs2.R')
# # # for(itor in 1:2){
# # #   if(itor==1){
# #     png('Fig S9.png',width=8, height=6.4,res=res,units=units)
# #   # }else{
# #   #   pdf('Fig S9.pdf',width=8, height=6.4,paper='legal')
# #   # # }
# #   color.vector=color.vector.max # Color Vector For Seperating the MSP from Conventional Solutions
# #   pairs2(100*Master.matrix.max.pure.profit,lower.panel=panel.EF,
# #          upper.panel=NULL,col=color.vector,cex=0.8,xlim=c(0,100),
# #          ylim=c(0,100),pch=16,font.labels=3,cex.axis=1,las=1,xaxp=c(0,100,4),yaxp=c(0,100,2),
# #          gap=1)
# #   par(xpd=T)
# #   l1<-legend(.33,1,
# #              legend=c('7D Frontier','2D Frontier'),fill=c("lightblue1","midnightblue"),
# #              cex=.75,title=expression(bold('Marine Spatial Planning (MSP)')),
# #              title.adj = 0, bty = 'n', adj = 0, text.width=.25)
# #   l2<-legend(x = l1$rect$left+.0020, y = with(l1$rect, top - h)-.005,
# #              legend=c('Constrained','Unconstrained'),fill=c("coral1","mediumorchid1"),
# #              cex=.75,title=expression(bold('Conventional Planning ')),
# #              title.adj = 0, bty = 'n', adj = 0, text.width=.25)
# #   title(xlab='[%] of Maximum',line=1)
# #   title(ylab='[%] of Maximum')
# # dev.off()#}
# # beep()
# #
# # source('figure_S28_code.R')
# #   MSP.value.data=rbind(Mussel.value.tmp,Finfish.value.tmp,Kelp.value.tmp)
# #   MSP.value.data.points=rbind(Mussel.value.tmp.points,Finfish.value.tmp.points,Kelp.value.tmp.points)
# #   names(MSP.value.data)=c('Aquaculture.Value','Value.of.MSP','Group','Sector.Name','Sector.Type','Type.of.Conventional')
# #   names(MSP.value.data.points)=c('Aquaculture.Value','Value.of.MSP','Group','Sector.Name','Sector.Type','Type.of.Conventional')
# #   MSP.value.data$Sector.Name=factor(MSP.value.data$Sector.Name,levels=c('Mussel','Finfish','Kelp','Halibut','Viewshed','Benthic','Disease'))
# #   Value.of.MSP.grid.plot<-ggplot(data=MSP.value.data)+
# #     geom_point(data=subset(MSP.value.data[as.integer(MSP.value.data$Group)!=as.integer(MSP.value.data$Sector.Name),]),
# #                aes(x=Aquaculture.Value,y=Value.of.MSP,shape=Type.of.Conventional,color=Type.of.Conventional),size=1.25)+
# #     facet_grid(Sector.Name~Group)+scale_y_continuous(labels = percent,limits=c(0,1),breaks=c(0,.5,1))+
# #     scale_x_continuous(labels = percent,breaks=c(0,.5,1))+
# #     geom_text(data=subset(MSP.value.data[as.integer(MSP.value.data$Group)==as.integer(MSP.value.data$Sector.Name),]),x=.5,y=.5,size=15,label='NA')+
# #     geom_point(data=MSP.value.data.points,aes(x=Aquaculture.Value,y=Value.of.MSP,shape=Type.of.Conventional,color=Type.of.Conventional),size=1.2)+
# #     xlab("Aquaculture Value")+ylab("Value of MSP")+
# #     scale_colour_manual(name = "Conventional Planning :",labels=c("Constrained","Unconstrained"),values=c("coral1","mediumorchid1"))+
# #     scale_shape_manual(name = "Conventional Planning :",labels=c("Constrained","Unconstrained"),values=c(16,24))+
# #     scale_fill_manual(name = "Conventional Planning :",labels=c("Constrained","Unconstrained"),values=c("coral1","mediumorchid1"))+
# #     #     geom_line(aes(x=c(0,1),y=c(0,0)),color="grey",linetype='dashed',size=1)+
# #     theme_bw(base_size = 15)+theme(panel.grid=element_blank(),legend.position="bottom")
# #   Fig_S10<-Value.of.MSP.grid.plot+theme(axis.title=element_text(size=12),panel.spacing = unit(1, "lines"),
# #                                strip.background=element_rect(fill='white'),strip.text=element_text(size=10),axis.ticks.margin=unit(1,'lines'))
# #
# #   for(itor in 1:2){
# #     if(itor==1){
# #       png('Fig S10.png',width=8, height=8,res=res,units=units)
# #     }else{
# #       pdf('Fig S10.pdf',width=8, height=8,paper='legal')
# #     }
# #     print(Fig_S10)
# #   dev.off()}
