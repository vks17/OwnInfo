## All R functions
#rm(list = ls())
library(data.table)
library(stringr)
library(dplyr)
library(plyr)

library(networkD3)
library(dplyr)

load_library <- function(x){
  for( i in x ){
    #  require returns TRUE invisibly if it was able to load package
    if( ! require( i , character.only = TRUE ) ){
      #  If package was not able to be loaded then re-install
      install.packages( i , dependencies = TRUE )
      #  Load package after installing
      require( i , character.only = TRUE )
    }
  }
}

#load_library("rvest")
#for copying in clipboard
write.excel <- function(x,row.names=FALSE,col.names=TRUE,...) {
  write.table(x,"clipboard",sep=",",row.names=row.names,col.names=col.names,...)
}

# dummy_creation
#cat_vars = c("Dominant Weekday_Weekend(MediaReady)",
#             "Dominant TimeSlot(MediaReady)" , "Dominant Kids(MediaReady)",
#             "Dominant SBU(MediaReady)" ,"Dominant Genre" ,
#             "Age Bucket","Gender")

dummy_creation = function(mydata, cat_vars){
  invisible(sapply(cat_vars, FUN = function(x){
    cats = sort(unique(mydata[, x]))
    cats = cats[2:length(cats)]
    cat_vars = paste(x, cats, sep = "_")
    for(k in 1:length(cats)){
      mydata[, paste0(cat_vars[k])] <<- ifelse(mydata[, x] == cats[k], 1, 0)
    }
  }))
  return(mydata)
}


### Data Quality
#### Can further modify to conditional format the correlation table

import_dataQuality <- function (data,excel_name,numeric.cutoff = -1,overwrite = TRUE) #, out.file.num, out.file.cat,
{ if(!require(e1071)){install.packages("e1071");library(e1071)}
  if(!require(openxlsx)){install.packages("openxlsx");library(openxlsx)}
  wb <- createWorkbook()
  addWorksheet(wb, "Correlation",gridLines = FALSE)
  addWorksheet(wb, "Numeric_Summary",gridLines = FALSE)
  addWorksheet(wb, "Categorical_Summary",gridLines = FALSE)
  options(scipen = 999)
  start.time <- Sys.time()
  cols <- 1:ncol(data)
  cats <- sapply(cols, function(i) is.factor(data[, i]) ||
                   is.character(data[, i]) || length(unique(data[, i])) <=
                   numeric.cutoff)
  cats <- which(cats == TRUE)
  nums <- sapply(cols, function(i) is.numeric(data[, i]) &
                   length(unique(data[, i])) > numeric.cutoff)
  nums <- which(nums == TRUE)

  # Correlation Matrix
  m2 <- cor(data[,nums])
  m2[lower.tri(m2)] <- NA
  writeDataTable(wb, 'Correlation', as.data.frame(m2),
                 startCol = 1, startRow = 1,
                 xy = NULL,
                 colNames = TRUE, rowNames = TRUE,
                 tableStyle = "TableStyleLight15", sep = ", ")

  maxNA <- function(x) {
    if (all(is.na(x))) {
      return(NA)
    }
    else return(max(x, na.rm = TRUE))
  }
  minNA <- function(x) {
    if (all(is.na(x))) {
      return(NA)
    }
    else return(min(x, na.rm = TRUE))
  }
  if (length(nums) > 0) {
    num.data <- data[, nums]
    n.non.miss <- colSums(!is.na(num.data))
    n.miss <- colSums(is.na(num.data))
    n.miss.percent <- 100 * n.miss/nrow(num.data)
    n.unique <- apply(num.data, 2, unique)
    n.unique <- simplify2array(lapply(n.unique, length))
    n.mean <- apply(num.data, 2, mean, na.rm = TRUE)
    n.min <- apply(num.data, 2, minNA)
    n.max <- apply(num.data, 2, maxNA)
    n.quant <- apply(num.data, 2, quantile, probs = c(0.01,
                                                      0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), na.rm = TRUE)
    n.skewness <- apply(num.data,2,skewness)
    n.kurtosis <- apply(num.data,2,kurtosis)

    n.output <- rbind(n.non.miss, n.miss, n.miss.percent,
                      n.unique, n.mean, n.min, n.quant, n.max,n.skewness,n.kurtosis)
    n.output <- data.frame(t(n.output))
    n.output <- round(n.output, 2)
    names(n.output) <- c("non-missing", "missing", "missing percent",
                         "unique", "mean", "min", "p1", "p5", "p10", "p25",
                         "p50", "p75", "p90", "p95", "p99", "max","Skewness","Kurtosis")
#    write.csv(n.output, out.file.num, row.names = TRUE)
    writeDataTable(wb, 'Numeric_Summary', n.output, startCol = 1, startRow = 1, xy = NULL,
                   colNames = TRUE, rowNames = TRUE, tableStyle = "TableStyleLight15",
                   tableName = NULL, headerStyle = NULL, withFilter = TRUE,
                   keepNA = FALSE, sep = ", ")
        cat("Check for numeric variables completed")
    cat(" // ")
    cat("Results saved to disk")
  }
  end.time <- Sys.time()
  time.taken <- end.time - start.time
  cat(" // ")
  print(time.taken)
  start.time <- Sys.time()
  if (length(cats) > 0) {
    cat.data <- data[, cats]
    cat.data[, 1:ncol(cat.data)] <- lapply(cat.data[, 1:ncol(cat.data)],
                                           as.character)
    cat.data[, 1:ncol(cat.data)] <- lapply(cat.data[, 1:ncol(cat.data)],
                                           function(x) {
                                             ifelse(x == "", NA, x)
                                           })
    n.non.miss <- colSums(!is.na(cat.data))
    n.miss <- colSums(is.na(cat.data))
    n.miss.percent <- 100 * n.miss/nrow(cat.data)
    n.unique <- apply(cat.data, 2, unique)
    n.unique <- simplify2array(lapply(n.unique, length))
    n.output <- rbind(n.non.miss, n.miss, n.miss.percent,
                      n.unique)


    n.output <- data.frame(t(n.output))
    n.output <- round(n.output, 2)
    n.categories <- apply(cat.data, 2, function(x) sort(table(x),
                                                        decreasing = TRUE))
    max.cat <- max(unlist(lapply(n.categories, length)))
    if (max.cat > 10)
      max.cat <- 10
    cat.names <- paste(rep(c("cat", "freq"), max.cat), rep(1:max.cat,
                                                           each = 2), sep = "_")
    n.output[, cat.names] <- ""
    n.output <- lapply(row.names(n.output), function(x) {
      tmp <- n.output[row.names(n.output) == x, ]
      freqs <- length(n.categories[[x]])
      freqs <- pmin(10, freqs)
      if (length(freqs) == 1 & freqs[1] == 0) {
        tmp[, paste("cat", 1:10, sep = "_")] <- NA
        tmp[, paste("freq", 1:10, sep = "_")] <- NA
      }
      else {
        tmp[, paste("cat", 1:freqs, sep = "_")] <- names(n.categories[[x]])[1:freqs]
        tmp[, paste("freq", 1:freqs, sep = "_")] <- unclass(n.categories[[x]])[1:freqs]
      }
      tmp
    })

    n.output <- data.frame(do.call("rbind", n.output))
    names(n.output)[1:4] <- c("non-missing", "missing", "missing percent","unique")
    writeDataTable(wb, 'Categorical_Summary', n.output, startCol = 1, startRow = 1, xy = NULL,
                   colNames = TRUE, rowNames = TRUE, tableStyle = "TableStyleLight15",
                   tableName = NULL, headerStyle = NULL, withFilter = TRUE,
                   keepNA = FALSE, sep = ", ")
    # write.csv(n.output, out.file.cat, row.names = TRUE)
    cat("Check for categorical variables completed")
    cat(" // ")
    cat("Results saved to disk")
  }
  end.time <- Sys.time()
  time.taken <- end.time - start.time
  cat(" // ")
  print(time.taken)
  saveWorkbook(wb,file = excel_name,overwrite = overwrite)
}


mape <- function(y, yhat)
mean(abs((y - yhat)/y))


normalizedGini <- function(aa, pp) {
  Gini <- function(a, p) {
    if (length(a) !=  length(p)) stop("Actual and Predicted need to be equal lengths!")
    temp.df <- data.frame(actual = a, pred = p, range=c(1:length(a)))
    temp.df <- temp.df[order(-temp.df$pred, temp.df$range),]
    population.delta <- 1 / length(a)
    total.losses <- sum(a)
    null.losses <- rep(population.delta, length(a)) # Hopefully is similar to accumulatedPopulationPercentageSum
    accum.losses <- temp.df$actual / total.losses # Hopefully is similar to accumulatedLossPercentageSum
    gini.sum <- cumsum(accum.losses - null.losses) # Not sure if this is having the same effect or not
    sum(gini.sum) / length(a)
  }
  Gini(aa,pp) / Gini(aa,aa)
}


rbind.all.columns <- function(x, y) {

    x.diff <- setdiff(colnames(x), colnames(y))
    y.diff <- setdiff(colnames(y), colnames(x))

    x[, c(as.character(y.diff))] <- NA

    y[, c(as.character(x.diff))] <- NA

    return(rbind(x, y))
}




# The function used to create the plots
sanktify <- function(x) {

  # Create nodes DF with the unique sources & targets from input

  #  ***** changing this is the key***********************************************************
  x <- as.data.frame(x)
  x$source <- as.character(x$source)
  x$target <- as.character(x$target)

  nodes <- data.frame(unique(c(x$source,x$target)),stringsAsFactors=FALSE)
  # ************************************************************************************************
  nodes$ID <- as.numeric(rownames(nodes)) - 1 # sankeyNetwork requires IDs to be zero-indexed
  names(nodes) <- c("name", "ID")

  # use dplyr join over merge since much better; in this case not big enough to matter
  # Replace source & target in links DF with IDs
  links <- inner_join(x, nodes, by = c("source"="name")) %>%
    rename(source_ID = ID) %>%
    inner_join(nodes, by = c("target"="name")) %>%
    rename(target_ID = ID)

  # Create Sankey Plot
  sank <- sankeyNetwork(
    Links = links,
    Nodes = nodes,
    Source = "source_ID",
    Target = "target_ID",
    Value = "value",
    NodeID = "name",
    units = "Users",
    fontSize = 12,
    nodeWidth = 15
  )

  return(sank)

}



#
# # use data_frame to avoid tbl_df(data.frame(
# z1 <- data_frame(
#   source = c("A", "A", "B", "B"),
#   target = c("Cardiovascular", "Neurological", "Cardiovascular", "Neurological"),
#   value = c(5, 8, 2, 10)
# )
# z2 <- data_frame(
#   source = c("Cardiovascular", "Cardiovascular", "Neurological", "Neurological"),
#   target = c("IP Surg", "IP Med", "IP Surg", "IP Med"),
#   value = c(3, 7, 6, 1)
# )
#
# z3 <- bind_rows(z1,z2)
# sanktify(z3)
