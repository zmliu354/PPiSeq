### Check the normalized fitness values for these PPIs
setwd("~/Desktop/PPiSeq_additional_data/")
source("function.R") # Load commonly used functions
#Commonly used colors
apple_colors = c("#5AC8FA", "#FFCC00", "#FF9500", "#FF2D55", "#007AFF", "#4CD964", "#FF3B30",
                 "#8E8E93", "#EFEFF4", "#CECED2", "#000000", "007AFF")
################################
# Figure S5A mean fitness for each stability bin
vScore = dataFrameReader_T("Datasets_generated_by_preprocessing/Variation_score_PPI_environment_neg_zero_SD_merge_filter.csv")
count_summary = csvReader_T("Datasets_generated_by_preprocessing/PPI_environment_count_summary_SD_merge_filter.csv")
vScore_fit = vScore[,4:ncol(vScore)]
### Take the mean fitness for all the positive PPIs
mean_fitness_pos = rep(0, nrow(vScore))
for(i in 1:length(mean_fitness_pos)){
        pos_env_index = which(count_summary[i,3:ncol(count_summary)] == "1")
        pos_env_index_fit = pos_env_index + 3
        mean_fitness_pos[i] = mean(as.numeric(vScore[i, pos_env_index_fit]))
}
min(mean_fitness_pos) # 0.1121392
fitness_count = data.frame(mean_fitness_pos, count_summary[,2])
colnames(fitness_count) = c("Mean_fitness", "Env_count")
library(ggplot2)
ggplot() +
        geom_boxplot(aes(x = Env_count, y = Mean_fitness), fitness_count, outlier.shape=NA) +
        geom_dotplot(aes(x = Env_count, y = Mean_fitness), fitness_count, 
                     binaxis="y",stackdir="center",binwidth=0.002, alpha=0.2, col = apple_colors[8]) +
        xlab("Number of environments in which a PPI is identified") +
        ylab("Mean fitness of a PPI across different environments") +
        theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
              panel.background = element_blank(), axis.line = element_line(colour = "black")) +
        theme(axis.text.x = element_text(size = 10, color = "black"),
              axis.text.y.left = element_text(size = 10, color = "black")) 
#theme(plot.margin = unit(c(1,1,2,1), "cm"))
ggsave("Figures/SFigures/SFigure6/FigureS6A_Mean_fitness_PPI_each_stability_bin.pdf", width=5, height =5)

##### Separate reported and unreported PPIs
################# Figure S5B can be directly Figure 3B
### Make barplot to show the percentage
### put the reported and unreported on to the same figure
rep_PPI_matrix = dataFrameReader_T("Growth_curve_validation_data/Reported_validation_matrix_SD_merge.csv")
unrep_PPI_matrix = dataFrameReader_T("Growth_curve_validation_data/Unreported_validation_matrix_SD_merge.csv")
ratio_rep = rep_PPI_matrix[4,-1]
ratio_unrep = unrep_PPI_matrix[4,-1]
ratio_all = as.numeric(c(ratio_rep[1], ratio_unrep[1], ratio_rep[2], ratio_unrep[2], 
                         ratio_rep[3], ratio_unrep[3], ratio_rep[4], ratio_unrep[4],
                         ratio_rep[5], ratio_unrep[5], ratio_rep[6], ratio_unrep[6],
                         ratio_rep[7], ratio_unrep[7], ratio_rep[8], ratio_unrep[8],
                         ratio_rep[9], ratio_unrep[9]))


rep_PPI_matrix[1,] #   0       0       5       7      14      15      22      41      16
rep_PPI_matrix[3,] #   5       1       6       9      19      18      27      44      16
unrep_PPI_matrix[1,]# 55      22      21      13      28      37      30      37      26
unrep_PPI_matrix[3,]#99      32      31      20      33      45      32      38      27
counts_label = c("0/5", "55/99", "0/1", "22/32", "5/6", "21/31",
                 "7/9", "13/20", "14/19", "28/33", "15/18", "37/45",
                 "22/27", "30/32", "41/44", "37/38", "16/16", "26/27")
library(RColorBrewer)
#col_chosen = brewer.pal(3,"Dark2")[1:2]
col_chosen = apple_colors[c(1,4)]
pdf("Figures/SFigures/SFigure6/FigureS6B_Validation_bar_plot_merge_reported_unreported.pdf", 
    width= 6, height=5)
barCenter = barplot(ratio_all*100, horiz=F, beside=F, ylim=c(0,100), ylab="Validation rate (%)",
                    space= c(0.4, 0.15, 0.4, 0.15, 0.4, 0.15, 0.4, 0.15, 0.4, 0.15,
                             0.4, 0.15, 0.4, 0.15, 0.4, 0.15, 0.4, 0.15),
                    col= col_chosen , axisnames=F, border=NA, cex.axis=0.8)
legend(-0.5,120, legend=c("Previously reported", "Previously unreported"),fill=col_chosen, cex=0.8, bty="n",
       border=FALSE, xpd = TRUE)
text(x= barCenter, y = ratio_all*100 + 2, labels = counts_label, cex=0.5, xpd = TRUE)
env_num_loc = rep(0, 9)
for(i in 1:9){
        env_num_loc[i] = mean(barCenter[(2*i-1):(2*i)])
}
text(x = env_num_loc, y = -8, labels = as.character(1:9), xpd = TRUE)
text(median(barCenter), y = -16, labels = "Number of environments in which a PPI is identified", xpd = TRUE)
dev.off()
