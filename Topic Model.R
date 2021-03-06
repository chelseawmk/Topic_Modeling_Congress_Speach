# Topic Modeling on Congress speech data

## Import Libraries 

library(rdd)
library(plotrix)
library(maptpx)
library (glmnet)
library(gamlr)
library(cluster)    # clustering algorithms
library(factoextra) # clustering algorithms & visualization
library(gridExtra) #plotting kmeans
library(wordcloud)
library(RColorBrewer)


## Load Data

# load data
load("congress.RData")



## Fit K-means 

#fit k-means cluster with k between 5 - 25 
fs <- scale(as.matrix( congress109Counts/rowSums(congress109Counts) ))
k5 <- kmeans(fs, centers = 5, nstart = 25)
k10 <- kmeans(fs, centers = 10, nstart = 25)
k15 <- kmeans(fs, centers = 15, nstart = 25)
k20 <- kmeans(fs, centers = 20, nstart = 25)
k25 <- kmeans(fs, centers = 25, nstart = 25)
# plots to compare
p1 <- fviz_cluster(k5, geom = "point", data = fs) + ggtitle("k = 5")
p2<-fviz_cluster(k10, geom = "point",  data = fs) + ggtitle("k = 10")
p3 <- fviz_cluster(k15, geom = "point",  data = fs) + ggtitle("k = 15")
p4 <- fviz_cluster(k20, geom = "point",  data = fs) + ggtitle("k = 20")
p5 <- fviz_cluster(k25, geom = "point",  data = fs) + ggtitle("k = 25")
grid.arrange(p1, p2, p3, p4, p5, nrow = 3)


## plot AICC and Elbow rule to choose best optimal k for the cluster

kfit <- lapply(1:25, function(k) kmeans(fs,k,nstart=25))
kic <- function(fit, rule=c("A","B")){
  df <- length(fit$centers) # K*dim
  n <- sum(fit$size)
  
  D <- fit$tot.withinss # deviance
  rule=match.arg(rule)
  if(rule=="A")
    return(D + 2*df*n/(n-df-1))
  else
    return(D + log(n)*df)
}
kaicc <- sapply(kfit, kic)
kbic <- sapply(kfit, kic, "B")
## plot
plot(kaicc, xlab="K", ylab="IC", 
     ylim=range(c(kaicc,kbic)), # get them on same page
     bty="n", type="l", lwd=2)
abline(v=which.min(kaicc))
text(15,500000,'AICc')
lines(kbic, col=4, lwd=2)
abline(v=which.min(kbic),col='blue')
text(15,600000,'BIC',col='blue')



## elbow rule
set.seed(123)
deviance <- lapply(1:25, function(k) kmeans(fs, k)$tot.withinss)
plot(1:25, deviance)

#The AICC plot and elbow plot yield the same results where as the number of k increases, the cluster shows better results. Thus, among the k within the range 5,10,15,20,25, 25 clusters will have the least deviance. 



## Fit topic model. 
### The Bayes factors to choose the number of topics as 10.

x <- as.simple_triplet_matrix(congress109Counts)
tpcs <- topics(x, K=5*(1:5), verb=10)
summary(tpcs, n=10)
#rank terms by probability within topics
rownames(tpcs$theta)[order(tpcs$theta[,1], decreasing=TRUE)[1:10]]
rownames(tpcs$theta)[order(tpcs$theta[,2], decreasing=TRUE)[1:10]]


## Generate Word Cloud

par(mfrow=c(1,2))
wordcloud(row.names(tpcs$theta), 
          freq=tpcs$theta[,1], min.freq=0.004, col="maroon")
wordcloud(row.names(tpcs$theta), 
          freq=tpcs$theta[,2], min.freq=0.004, col="navy")


## Tabulate party membership for the topics by K-means. 

table(party = congress109Ideology$party, cluster = k25$cluster)
print(apply(k25$centers,1,function(c) colnames(fs)[order(-c)[1:10]]))



## Evaluate Model Result

## we'll regress repshare onto it
xrepshare<-congress109Ideology[,'repshare']
tpcreg<-gamlr(tpcs$omega,xrepshare)
# Percentage changes in repshare for moving up 10% weight in that topic
drop(coef(tpcreg))*0.1
regtopics.cv <- cv.glmnet(tpcs$omega,xrepshare)
## give it the word %s as inputs
x <- 100*(congress109Counts)/rowSums(congress109Counts)
regwords.cv <- cv.glmnet(x,xrepshare)
par(mfrow=c(1,2))
plot(regtopics.cv)
mtext("topic regression", font=2, line=2)
plot(regwords.cv)
mtext("bigram regression", font=2, line=2)
# max OOS R^2s
max(1-regtopics.cv$cvm/regtopics.cv$cvm[1])
max(1-regwords.cv$cvm/regwords.cv$cvm[1])

############### For Republic party:
row_R <- c(1:529)[congress109Ideology$party == 'R']
omega_R <- tpcs$omega[row_R,]
## we'll regress repshare onto it
party_R <- subset(congress109Ideology, party == 'R')
tpcreg_R <- gamlr(omega_R, party_R$repshare)
# Percentage changes in repshare for moving up 10% weight in that topic
drop(coef(tpcreg_R))*0.1
regtopics.cv_R <- cv.glmnet(omega_R, party_R$repshare)
## give it the word %s as inputs
x_R <- 100*(congress109Counts[row_R,])/rowSums(congress109Counts[row_R,])
regwords.cv_R <- cv.glmnet(x_R, party_R$repshare)
par(mfrow=c(1,2))
plot(regtopics.cv_R)
mtext("topic regression", font=2, line=2)
plot(regwords.cv_R)
mtext("bigram regression", font=2, line=2)
# max OOS R^2s
max(1-regtopics.cv_R$cvm/regtopics.cv_R$cvm[1])
max(1-regwords.cv_R$cvm/regwords.cv_R$cvm[1])





############## For Demography party:
row_D <- c(1:529)[congress109Ideology$party == 'D']
omega_D <- tpcs$omega[row_D,]
## we'll regress repshare onto it
party_D <- subset(congress109Ideology, party == 'D')
tpcreg_D <- gamlr(omega_D, party_D$repshare)
# Percentage changes in repshare for moving up 10% weight in that topic
drop(coef(tpcreg_D))*0.1
regtopics.cv_D <- cv.glmnet(omega_D, party_D$repshare)
## give it the word %s as inputs
x_D <- 100*(congress109Counts[row_D,])/rowSums(congress109Counts[row_D,])
regwords.cv_D <- cv.glmnet(x_D, party_D$repshare)
par(mfrow=c(1,2))
plot(regtopics.cv_D)
mtext("topic regression", font=2, line=2)
plot(regwords.cv_D)
mtext("bigram regression", font=2, line=2)
# max OOS R^2s
max(1-regtopics.cv_D$cvm/regtopics.cv_D$cvm[1])
max(1-regwords.cv_D$cvm/regwords.cv_D$cvm[1])
