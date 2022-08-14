#to search parts of a string and see if any data is available
findCol <- function(string, data, printId = T){
  grep(string, names(data), ignore.case = T, value = printId)
}

#This will find the standard columns that are missing in the dataset
checkColumns <- function(columns, data){
  count <- 1
  print("The following columns are not present:")
  for(i in columns){
    if(!(i %in% names(data))){
      res <- paste(count, "- ", i, sep = "")
      print(res)
      count <- count+1
    }
  }
}

#For displaying the columns that exist
columnExist <- function(columns, data){
  count<-1
  print("The following columns are present:")
  for(i in tolower(columns)){
    if(i %in% tolower(names(data))){
      res <-  paste(count, "- ", i, sep = "")
      print(res)
      count <- count+1
    }
  }
}

#to check the columns that have null values
emptyColumns <- function(data){
  allmisscols <- apply(data,2, function(x)all(is.na(x)))
  colswithallmiss <- names(allmisscols[allmisscols>0])
  View(colswithallmiss)
}

#to compare datapoints with dataset
checkData <- function(data, checkAgaints, ViewResult=T){

  diffSpelling <- data %>% 
    anti_join(., checkAgaints) %>% 
    unique()
  
  print(paste("Number of unique values in the dataset: ", nrow(data)))
  print(paste("Total matched values: ", nrow(data)-nrow(diffSpelling)))
  if(ViewResult){
    View(diffSpelling)
  }
  return(diffSpelling)
}

#to show the null values in each column
numOfNull <- function(data){
  nullNumData <- data.frame()
  
  for (i in 1:ncol(data)){
    nulls <- length(which(is.na(data[i])))
    
    if(nulls > 0){
      nullNumData  <- rbind(nullNumData,c(names(data[i]), nulls))
    }
  }
  names(nullNumData) <- c("Columns", "NumOfMissingValues")
  return(nullNumData)
}

#to ensure data consistency for each column
checkDuplicates <-  function(data, vectorOfColumns, show=F){
  uniqueData <- unique(data[,vectorOfColumns])
  for(i in 1:ncol(uniqueData)){
    num <- length(which(duplicated(uniqueData[i])))
    duplicates <- paste("The number of duplicates in column: (", names(uniqueData[i]), ") are: ",num)
    print(duplicates)
  }
  if(show){
    View(uniqueData)
  }
}

##to compare each row of the tab with the main tab 
checkColumnsInTabs <- function(data, checkAgainst){
  count <- 0
  inconsistentRows <- data.frame()
  
  for(i in 1:nrow(data)){
    siteVisitId <- toString(data[i,1])
    columns <- vector()
    rowCheck <- 0
    
    for(j in 2:ncol(data)){
      columnValue <- toString(data[i,j])
      stdData <- toString(checkAgainst[checkAgainst[[1]] %in% siteVisitId, names(checkAgainst[j])])
      
      if(!(columnValue %in% stdData)){
        rowCheck <- rowCheck+1
        columns <- append(columns, names(data[j]))
      }
    }
    
    if(rowCheck > 0){
      inconsistentRows <- data[i,] %>% 
        mutate(Inconsistent_Column_Name = paste(columns, collapse = ' - ')) %>% 
        rbind(inconsistentRows)
    } else {
      count <- count+1
    }
  }
  
  cat("The number of unique rows in the Tab: ", nrow(data),"\n")
  cat("The number of consistent rows: ", count,"\n")
  return(inconsistentRows)
}

####LOG ####
create_log <- function(raw_data, cleaned_data, col_vec, identifier){
  uuid <- vector()
  question.name <- vector()
  old_val <- vector()
  new_val <- vector()
  
  for(index in 1:length(col_vec)){
    col_name <- col_vec[index]
    
    for(i in 1:length(cleaned_data[[col_name]])) {
      id <- cleaned_data[[identifier]][i]
      newVal <- cleaned_data[[col_name]][i]
      oldVal <- raw_data[raw_data[[identifier]] %in% id, col_name]
      
      if(!(newVal %in% oldVal[[1]])){
        uuid <- c(uuid, id)
        question.name <- c(question.name, col_name)
        old_val <- c(old_val, oldVal[[1]])
        new_val <- c(new_val, newVal)
      }  
    }
  }
  logVal <- data.frame(uuid, question.name, old_val, new_val)
  return(logVal)
}
