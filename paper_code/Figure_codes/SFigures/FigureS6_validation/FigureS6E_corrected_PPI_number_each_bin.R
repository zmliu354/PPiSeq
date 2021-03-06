# This script is to use the validation predicting model to generate a more accurate PPI estimation
# Here I use the SD replicates to measure if the model improved the accuracy of PPI calling

### (1) Generate the model
### (2) Predicting positive PPIs in SD and SD replicates, 
###  and finding the optimal predicted accuracy to generate the maximum reproducibility
### (3) Predict validation rate for each PPI in each environment and use the thresholds
###  to generate a "true" PPI in each environment. Then recalculate the variation score
### and check its correlation with other features.

#### Check the fitness of validated PPIs

setwd("~/Desktop/PPiSeq_additional_data/")
source("function.R") # Load commonly used functions
all_Tecan = csvReader_T("Growth_curve_validation_data/SD_environment_validation_summary.csv")
vScore = csvReader_T("Datasets_generated_by_preprocessing/Variation_score_PPI_environment_neg_zero_SD_merge_filter.csv")
count_summary = csvReader_T("Datasets_generated_by_preprocessing/PPI_environment_count_summary_SD_merge_filter.csv")
SD_select = count_summary[which(count_summary[,3] == "1"),]
vScore_select = vScore[which(vScore[,1] %in% SD_select[,1]),]
vScore_select_Tecan = match_both_direction(vScore_select, all_Tecan[,1]) # 502 
#vScore_select_fitness = as.numeric(vScore_select_Tecan[,4]) # 4: DMSO column
fitness_bins = c(0.25, seq(0.26, 0.39, by = 0.01), seq(0.42, 0.66, by = 0.04), c(0.8, 1.0))

### Here I do not need to split the data in to training and test data.
### I split the data into different bins, and obtained a dataframe of fitness, validation rate, and mean evnironment count
### Train the linear model with that data. 
### Will have two test datasets: (1) split data into different bins by stability; 
### (2) directly predict each PPI that was validated by Tecan
### In the end, predict all the PPIs in each environment

## generate test data 1 by splitting data according to their stability
SD_fit_count = data.frame(as.numeric(vScore[,4]), as.numeric(vScore[,2]))
stability_mean = rep(0, 9)
for(i in 1:9){
  index = which(as.numeric(SD_fit_count[,2]) == i)
  stability_mean[i] = mean(SD_fit_count[index,1])
}
count_normal = 1:9/9
# Calculate validation rate
rep_PPI_matrix = dataFrameReader_T("Growth_curve_validation_data/Reported_validation_matrix_SD_merge.csv")
unrep_PPI_matrix = dataFrameReader_T("Growth_curve_validation_data/Unreported_validation_matrix_SD_merge.csv")
merge_validate = rep_PPI_matrix[1, 2:ncol(rep_PPI_matrix)] + unrep_PPI_matrix[1, 2:ncol(rep_PPI_matrix)]
merge_nonvalidate = rep_PPI_matrix[2, 2:ncol(rep_PPI_matrix)] + unrep_PPI_matrix[2, 2:ncol(rep_PPI_matrix)]
merge_sum = merge_validate + merge_nonvalidate
merge_ratio = as.numeric(merge_validate/merge_sum)
external_test = data.frame(val_rate = merge_ratio, bins = stability_mean, env_count_normal= count_normal)

#### Function to prepare the training data
split_data_generation = function(training, environment_loc, bins, all_Tecan){
  val_rate = rep(0, length(bins))
  env_count = rep(0, length(bins))
  PPI_count = rep(0, length(bins))
  fit = rep(0, length(bins))
  for(i in 1:length(bins)){
    if(i == 1){
      fit_bin = c(0, bins[i])
    }
    else{
      fit_bin = c(bins[i-1], bins[i])
    }
    training_fitness = as.numeric(training[,environment_loc])
    index_chosen = which(training_fitness > fit_bin[1] & training_fitness <= fit_bin[2])
    PPI_chosen = training[index_chosen, 1]
    PPI_count[i] = length(which(training_fitness > fit_bin[1] & training_fitness <= fit_bin[2]))
    env_count[i] = mean(as.numeric(training[index_chosen, 2])) ## average environment number within each bin
    fit[i] = mean(as.numeric(training[index_chosen, 4])) ## average fitness within each bin
    Tecan_select = match_both_direction(all_Tecan, PPI_chosen)
    if (length(Tecan_select) > 11){
      validate_PPI_count = length(which(as.numeric(Tecan_select[,11]) <= 0.05))
      val_rate[i] = validate_PPI_count/nrow(Tecan_select)
    }else if(length(Tecan_select) == 11){
      validate_PPI_count = as.numeric(Tecan_select[11]) <= 0.05
      val_rate[i] = validate_PPI_count/1
    }else{
      val_rate[i] = NA
    }
    
  }
  env_count = as.numeric(env_count)
  env_count_normal = env_count/9
  var_matrix = na.omit(data.frame(val_rate, bins= fit, env_count_normal))
  return(var_matrix)
}
training_data = split_data_generation(vScore_select_Tecan, 4, fitness_bins, all_Tecan)
fitmodel = lm(val_rate ~ bins + env_count_normal, training_data)
coeffs = coef(fitmodel)
#(Intercept)             bins env_count_normal 
# 0.5460176     -0.1302505      0.5130320
#predict(fitmodel, data.frame(bins = c(0.2, 0.4), env_count_normal = c(1/9, 5/9)))
#coeffs[1] + coeffs[2]*0.2 + coeffs[3]* 1/9
predict_external_test = predict(fitmodel, external_test, type = "response")

cor(external_test$val_rate, predict_external_test, method = "spearman") # 0.9833333
cor(external_test$val_rate, predict_external_test, method = "pearson") # 0.9768506

pdf("Figures/SFigures/SFigure6/FigureS6E_model_accuracy.pdf", width =5, height =5)
plot(external_test$val_rate, predict_external_test, pch = 16, col = "blue",
     type = "p", xlim = c(0.5, 1), ylim = c(0.5,1), xlab = "Observed validation rate",
     ylab = "Predicted validation rate", bty = "n")
#points(external_test$val_rate, predict_external_test_2, pch =16, col = "red")
lines(seq(0.5, 1, by = 0.1), seq(0.5, 1, by = 0.1), col = "black")
text(0.6, 0.95, labels = expression(paste("Spearman's ", italic(r), " = 0.98")))
dev.off()

############################################################################
## Use this model to predict the validation rate for each PPI in each environment
coeffs = c(0.5460176, -0.1302505, 0.5130320)
PPI_vscore = csvReader_T("Datasets_generated_by_preprocessing/Variation_score_PPI_environment_neg_zero_SD_merge_filter.csv")
PPI_count = csvReader_T("Datasets_generated_by_preprocessing/PPI_environment_count_summary_SD_merge_filter.csv")
matrix_vali = matrix(NA, nrow(PPI_count), ncol(PPI_count))
colnames(matrix_vali) = c("PPI", colnames(PPI_count)[2:ncol(PPI_count)])
matrix_vali[,1] = PPI_count[,1]
matrix_vali[,2] = PPI_count[,2]
for(i in 1:nrow(PPI_count)){
        env = as.numeric(PPI_count[i,2])/9
        for(j in 3:ncol(matrix_vali)){
                fit = as.numeric(PPI_vscore[i, j + 1])
                if(as.numeric(PPI_count[i,j]) == 1){
                        matrix_vali[i,j] = coeffs[1] + coeffs[2]*fit + coeffs[3]*env
                        if (matrix_vali[i,j] > 1){
                                matrix_vali[i,j] = 1
                        }
                }else{
                        matrix_vali[i,j] = NA
                }
        } 
}
#csvWriter(matrix_vali, "Datasets_generate_by_preprocessing/TableS5_validation_rates_PPI_in_each_environment.csv")

env_number_correct = rep(0, nrow(matrix_vali))
for (i in 1:nrow(matrix_vali)){
        env_number_correct[i] = mean(as.numeric(matrix_vali[i,3:ncol(matrix_vali)]), na.rm = T)
}

matrix_vali_add = cbind(matrix_vali[,1:2], env_number_correct, matrix_vali[,3:ncol(matrix_vali)])
env_bins = 1:9
env_count_bar = rep(0, 9)
for(i in 1:length(env_bins)){
        index = which(as.numeric(matrix_vali_add[,2]) == env_bins[i])
        env_count_bar[i] = sum(as.numeric(matrix_vali_add[index,3]))
}

env_count_ori = as.data.frame(table(matrix_vali_add[,2]))$Freq
env_count_ori # 7724         1266        730      579       579       553        497     579       474
env_count_bar # 4284.2773  773.4567  489.7942  421.5497  454.0906  463.7560  443.0204  542.8383  466.8507

#### Plot both the corrected and original PPI counts in each bin
a = env_count_ori
b = env_count_bar
env_count_final = c(a[1], b[1], a[2], b[2], a[3], b[3], a[4], b[4], a[5], b[5],
                    a[6], b[6], a[7], b[7], a[8], b[8], a[9], b[9])

#Commonly used colors
apple_colors = c("#5AC8FA", "#FFCC00", "#FF9500", "#FF2D55", "#007AFF", "#4CD964", "#FF3B30",
                 "#8E8E93", "#EFEFF4", "#CECED2", "#000000", "007AFF")
col_chosen = apple_colors[c(1,4)]
pdf("Figures/SFigures/SFigure6/FigureS6E_Corrected_Validation_bar_plot_comparison.pdf.pdf", width= 5.5, height=5)
barCenter = barplot(env_count_final, horiz=F, beside=F, ylim=c(0,10000), ylab="Number of PPIs",
                    space= c(0.4, 0.15, 0.4, 0.15, 0.4, 0.15, 0.4, 0.15, 0.4, 0.15,
                             0.4, 0.15, 0.4, 0.15, 0.4, 0.15, 0.4, 0.15), axisnames=F, 
                    col= col_chosen, border=NA,  cex.axis=0.8)
legend("topright", legend=c("Primary", "Validated"), fill=col_chosen, cex=0.8, bty="n", border=FALSE, xpd = TRUE)
#text(x= barCenter, y = as.numeric(merge_ratio)*100 + 2, labels = counts_label, cex=0.8, xpd = TRUE)
env_num_loc = rep(0, 9)
for(i in 1:9){
        env_num_loc[i] = mean(barCenter[(2*i-1):(2*i)])
}
text(x = env_num_loc, y = -300, labels = as.character(1:9), xpd = TRUE)
text(median(barCenter), y = -800, labels = "Number of environments in which a PPI is identified", xpd = TRUE)
dev.off()

