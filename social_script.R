rm(list=ls())
#all finished and log generated!
############# install necessary packages #############
if(!require("tidyverse")) install.packages("tidyverse")
if(!require("fs")) install.packages("fs")
if(!require("readxl")) install.packages("readxl")
if(!require("writexl")) install.packages("writexl")
if(!require("dplyr")) install.packages("dplyr")
if(!require("xlsx")) install.packages("xlsx")
if(!require("openxlsx")) install.packages("openxlsx")
if(!require("lubridate")) install.packages("lubridate")

############# load libraries #############
library(readxl)
library(writexl)
library(dplyr)
library(summarytools)
library(tidyverse)
library(xlsx)
library(openxlsx)

############# Standard Columns #############
source("functions/functions.R")
stdColumns = c(
  "Surveyor_Name",
  "Surveyor_Id",
  "Surveyor_Gender",
  "Site_Visit_Id",
  "Province",
  "District",
  "Line_Ministry_Name",
  "Line_Ministry_Project_Id",
  'Line_Ministry_SubProject_Id',
  'Line_Ministry_Sub_Project_Name_And_Description',
  'Sub_Project_Financial_Value_In_Afn',
  'CDC_CCDC_Gozar_Name',
  'CDC_CCDC_Gozar_ID',
  'Name_of_Contractor_Facilitating_Partner',
  'Type_Of_Site_Visit',
  'Type_Of_Visit',
  'If_not_a_first_Site_Visit_state_Original_Site_Visit_ID')

socialData = read.xlsx("input/raw_data/May_CCAP_Social_May_CLEANED.xlsx", sheet="CCAP_Social_May_dataset")

#for employee data
direc <- "input/emp_data/Complete Recruitment table.xlsx"
empData <- read_excel(direc, sheet = "Rield Researchers RT")
callCenter <- read_excel(direc, sheet = "Call Center Agents RT")
#to paste together the name and the lastname
fieldRs <- empData %>% 
  unite("fullName", 'Employee Name':'Employees Last Name', sep=" ") %>% 
  select(`Employee unique ID`, fullName) 

callCenter <- callCenter %>% 
  unite("fullName", 'Employee Name':'Employees Last Name', sep=" ") %>% 
  select(`Employee unique ID`, fullName, Gender) 


direc <- "input/emp_data/Complete Recruitment table.xlsx"
terminatedEmp <- read_excel(direc, sheet = "Terminated Team")

############# Functions for checking data columns #############
#to display columns that does not exist
checkColumns(stdColumns, socialData)
#columns that exist
columnExist(stdColumns, socialData)

############# Fixing inconsistencies #############

############# adding new columns with null values #############
socialData = socialData %>%
  add_column(Line_Ministry_Sub_Project_Name_And_Description = NA, .after="Line_Ministry_SubProject_Id")
socialData = socialData %>%
  add_column(If_not_a_first_Site_Visit_state_Original_Site_Visit_ID = NA, .after="Type_Of_Visit")

# #to print the index of newly added columns 
# for(i in 1:length(stdColumns)){
#   cat(stdColumns[i], grep(stdColumns[i], names(socialData)), "\n")
# }

##for creating log 
raw_data <- socialData
############# to fill null values #############
#for Line Ministry Project ID / Name / Description
link <- ""
sampleData <- read_sheet(link, sheet = "Sample Sheet")
sampleData$`Line Ministry sub-project ID` <- as.character(sampleData$`Line Ministry sub-project ID`)
sampleData$`Line Ministry Project ID` <- as.character(sampleData$`Line Ministry Project ID`)
#changing data type from null to string
socialData$Line_Ministry_Sub_Project_Name_And_Description = as.character(socialData$Line_Ministry_Sub_Project_Name_And_Description)

#Extracting data from sample
for (i in 1:nrow(socialData)){
  id <- toString(socialData[i, "Line_Ministry_Project_Id"])
  siteVisitId <- toString(socialData[i, "Site_Visit_Id"])
  
  print(paste(i, "- ", sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry sub-project ID"]))
  # if(i == 62){
  #   next
  # } else {
  #   socialData[i,"Line_Ministry_Name"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry"]
  #   socialData[i,"Line_Ministry_SubProject_Id"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry sub-project ID"]
  #   socialData[i,"Line_Ministry_Sub_Project_Name_And_Description"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"Line Ministry sub-project name and description"]
  #   socialData[i,"Type_Of_Visit"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"TPMA Site Visit Type"]
  #   socialData[i,"Type_Of_Site_Visit"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"If appropriate, type of site visit"]
  #   # socialData[i,"Name_of_Contractor_Facilitating_Partner"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"If appropriate, name of contractor"]
  # }
}

#for Line_Ministry_Name
for (i in 1:nrow(socialData)){
  id = toString(socialData[i, "Line_Ministry_Project_Id"])
  siteVisitId = toString(socialData[i, "Site_Visit_Id"])
  
  found <- sampleData %>% 
    filter(`Line Ministry Project ID` %in% id & `Temporary PMT Code` %in% siteVisitId) %>% 
    select(`Line Ministry sub-project ID`, `Line Ministry sub-project name and description`, `TPMA Site Visit Type`, `If appropriate, type of site visit`,
           `Line Ministry Project ID`)

  if(nrow(found) > 0){
    socialData[i,"Line_Ministry_SubProject_Id"] <- found$`Line Ministry sub-project ID`
    socialData[i,"Line_Ministry_Sub_Project_Name_And_Description"] <- found$`Line Ministry sub-project name and description`
    socialData[i,"Type_Of_Visit"] <- found$`TPMA Site Visit Type`
    socialData[i,"Type_Of_Site_Visit"] <- found$`If appropriate, type of site visit`

  }
}

#completing Surveyor's ID from the employee data 
#manually fixing Surveyor names
socialData <- socialData %>% 
  mutate(Surveyor_Name = case_when(
    Surveyor_Name == "" ~ "",
    TRUE ~ Surveyor_Name
    ))

#to compare surveyor names and fetch the Surveyor_Id
missingEmp <- data.frame()
for (i in 1:nrow(socialData)) {
  surN <- socialData$Surveyor_Name[i]
  
  if(surN %in% fieldRs$fullName){
    # socialData$Surveyor_Id[i] <- empN$`ATR ID #`[empN$fullName %in% surN]
  } else if (surN %in% callCenter$fullName){
    
  } else if (surN %in% terminatedEmp$`Full Name`) {
    # socialData$Surveyor_Id[i] <- terminatedEmp$`ATR ID NO`[terminatedEmp$Name %in% surN]
  } else {
    missingEmp <- rbind(missingEmp, socialData[i, c("Surveyor_Name", "Surveyor_Id")])
  }
}
missingEmp <- unique(missingEmp)
############# For Data Cleanign Guidelines #############
##unifying the inconsistencies in province, district and CDC/village using GeoApp
geoApp = read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "District")
standardP = unique(geoApp[,"Province"])
standardDis = unique(geoApp[,"District"])

#### for Provinces ####
##changing data type from null to string
diffSpelling = checkData(unique(socialData["Province"]), standardP, F)
#manually fixing inconsistent province name
socialData <- socialData %>% 
  mutate(Province = case_when(
    Province == "Sari Pul" ~ "Sar-I-Pul",
    Province == "Paktiya" ~ "Paktia", 
    Province == "Panjsher" ~ "Panjshir",
    TRUE ~ Province
  ))
#### For districts #### 
diffSpelling = checkData(unique(socialData["District"]), standardDis, F)
#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  row <- unique(socialData[socialData$District %in% diffSpelling[i,1], c("Province", "District")])
  print(row)
}
#manually fixing spellings
socialData <- socialData %>% 
  mutate(District = case_when(
    District == "Qarghayi" ~ "Qarghayee",
    District == "Baghlani Jadid" ~ "Baghlan-E-Jadeed",
    District == "Khaki Jabbar" ~ "Khak-E-Jabar",
    District == "Nadir Shah Kot" ~ "Nadirshah Kot",
    District == "Siya Gird" ~ "Syahgirdi Ghorband",
    District == "Zinda Jan" ~ "Zendajan",
    District == "Kuz Kunar" ~ "Kuzkunar",
    District == "Narang" ~ "Narang Wa Badil",
    District == "Sari Pul" ~ "Sar-E-Pul",
    District == "Khwaja Umari" ~ "Khwaja Omari",
    District == "Karukh" ~ "Karrukh",
    District == "Panjwayi" ~ "Panjwayee",
    #confirmed based on cdc
    District == "Chamkanay" ~ "Samkani",
    District == "Shekh Ali" ~ "Shaykh Ali",
    District == "Dashti Qala" ~ "Dasht-E-Qala",
    District == "Nawa-I- Barak Zayi" ~ "Nawa-E-Barikzayi",
    District == "Sayid Karam" ~ "Sayyid Karam",
    District == "Surkh Rod" ~ "Surkh Rud",
    District == "Bahrami Shahid (Jaghatu)" ~ "Jaghatu",
    District == "Asadabad" ~ "Asad Abad",
    District == "Dara-I-Pech" ~ "Dara-E-Pech",
    District == "Dara-I-Nur" ~ "Darah-E-Noor",
    District == "Mihtarlam" ~ "Mehterlam",
    District == "Ismail khill & Mandozai" ~ "Manduzay (Esmayel Khel)",
    District == "Mazari Sharif" ~ "Mazar-E-Sharif",
    District == "Khost(Matun)" ~ "Khost",
    District == "Fayzabad" ~ "Faiz Abad",
    District == "Chawkay" ~ "Sawkai",
    District == "Musayi" ~ "Musahi",
    District == "Hisa-i-Awali Bihsud" ~ "Hissa-E-Awali Bihsud",
    District == "Puli Khumri" ~ "Pul-I-Khumri",
    District == "Chah Ab" ~ "Chahab",
    District == "Ishkashim" ~ "Eshkashim",
    District == "Jalal Abad" ~ "Jalalabad",
    District == "kama" ~ "Kama",
    District == "Herat city" ~ "Herat",
    TRUE ~ District
  ))

#### for cdc_gozar_name #### 
geoAppVillage = read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "Village_CDC")
#subsetting villages using the Districts that are present in the dataset
villages <- geoAppVillage %>%
  filter(District %in% socialData$District) %>% 
  select(Village) %>% 
  rename(CDC_CCDC_Gozar_Name = Village)
#to find the inconsistent gozar names
diffSpelling = checkData(unique(socialData["CDC_CCDC_Gozar_Name"]), villages,F)

diffSpelling <- socialData %>%
  filter(CDC_CCDC_Gozar_Name %in% diffSpelling[[1]] & !(District %in% c("Herat", "Kandahar", "Mazar-E-Sharif", "Jalalabad"))) %>%
  select(Province, District, CDC_CCDC_Gozar_Name) %>%
  unique()

#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  print(diffSpelling[i,])
}
#Fixing inconsistent Gozar names 
socialData <-  socialData %>% 
  mutate(CDC_CCDC_Gozar_Name = case_when(
    CDC_CCDC_Gozar_Name == "Doabi Village CDC" ~ "Doabi",
    CDC_CCDC_Gozar_Name == "Robat Payan CDC" ~ "Robat Payan",
    CDC_CCDC_Gozar_Name == "Dalan to" ~ "Dalan To",
    CDC_CCDC_Gozar_Name == "Mahal bala pusht joy" ~ "Mahal Bala Pusht Joy",
    CDC_CCDC_Gozar_Name == "Abdul Jalil Khan" ~ "Abdul Jalil",
    CDC_CCDC_Gozar_Name == "Koz salampoor" ~ "Koz Salampoor",
    CDC_CCDC_Gozar_Name == "Khawaja Akber" ~ "Khawaja  Akber",
    CDC_CCDC_Gozar_Name == "Gholam Nabi" ~ "Ghollam Nabi",
    CDC_CCDC_Gozar_Name == "Ghollam nabi" ~ "Ghollam Nabi",
    CDC_CCDC_Gozar_Name == "Zia ul Haq Mina" ~ "Ziaul Haq Mina",
    CDC_CCDC_Gozar_Name == "Shamir Payeen" ~ "Shah Mir Payan",
    CDC_CCDC_Gozar_Name == "Bazdid khail" ~ "Bazdid Khail",
    CDC_CCDC_Gozar_Name == "Haidar khail+Zeyarat" ~ "Haidar Khail+Zeyarat",
    CDC_CCDC_Gozar_Name == "Qul-e Hasan" ~ "Qul-E Hasan",
    CDC_CCDC_Gozar_Name == "Qala e Awdak" ~ "Qala E Awdak",
    CDC_CCDC_Gozar_Name == "Mohtaseb ha" ~ "Mohtaseb Ha",
    CDC_CCDC_Gozar_Name == "Kajer khail , Azim khail" ~ "Kajer Khail , Azim Khail",
    CDC_CCDC_Gozar_Name == "Bazeed khil" ~ "Bazeed Khil",
    CDC_CCDC_Gozar_Name == "yar gul" ~ "Yar Gul",
    CDC_CCDC_Gozar_Name == "Qala-e- Qazi" ~ "Qala-E- Qazi",
    CDC_CCDC_Gozar_Name == "Quti SAzan" ~ "Quti Sazan",
    CDC_CCDC_Gozar_Name == "Zaman khail" ~ "Zaman Khail",
    CDC_CCDC_Gozar_Name == "Honey Sofla dawran khel" ~ "Honey Sofla Dawran Khel",
    CDC_CCDC_Gozar_Name == "Khan kali" ~ "Khan Kali",
    CDC_CCDC_Gozar_Name == "Qala-e-Shikh" ~ "Qala-E-Shikh",
    CDC_CCDC_Gozar_Name == "Qala shakar and sarilar" ~ "Qala Shakar And Sarilar",
    CDC_CCDC_Gozar_Name == "Qala khanger" ~ "Qala Khanger",
    CDC_CCDC_Gozar_Name == "Badam gul" ~ "Badam Gul",
    CDC_CCDC_Gozar_Name == "balak zar" ~ "Balak Zar",
    CDC_CCDC_Gozar_Name == "Panjshiri ha" ~ "Panjshiri Ha",
    CDC_CCDC_Gozar_Name == "Par shahr" ~ "Par Shahr",
    CDC_CCDC_Gozar_Name == "Qala-e Bagher" ~ "Qala-E Bagher",
    CDC_CCDC_Gozar_Name == "Toshi wati kali" ~ "Toshi Wati Kali",
    CDC_CCDC_Gozar_Name == "Qala-e-Malika+Deh Laghmani" ~ "Qala-E-Malika+Deh Laghmani",
    CDC_CCDC_Gozar_Name == "Qala-e-Malik Ha" ~ "Qala-E-Malik Ha",
    CDC_CCDC_Gozar_Name == "Bonta kali" ~ "Bonta Kali",
    CDC_CCDC_Gozar_Name == "Bahram khil Baz Mir" ~ "Bahram Khil Baz Mir",
    CDC_CCDC_Gozar_Name == "Qule neamate payan" ~ "Qule Namate Payan",
    CDC_CCDC_Gozar_Name == "Qule namate payan" ~ "Qule Namate Payan",
    CDC_CCDC_Gozar_Name == "Qalai nazer" ~ "Qalai Nazer",
    CDC_CCDC_Gozar_Name == "Esa khill" ~ "Esa Khill",
    CDC_CCDC_Gozar_Name == "Kar Abdra" ~ "Karabdra",
    CDC_CCDC_Gozar_Name == "KanKo" ~ "Kanko",
    CDC_CCDC_Gozar_Name == "Azar keeyoo" ~ "Azar Keeyoo",
    CDC_CCDC_Gozar_Name == "Malik Khil" ~ "Malik Khill",
    CDC_CCDC_Gozar_Name == "QALA HASAR" ~ "Qala Hasar",
    CDC_CCDC_Gozar_Name == "Astanaqul and Arbab Jalil" ~ "Astanaqul Wa Arbab Jalil",
    CDC_CCDC_Gozar_Name == "Astanaqul wa Arbab jalil" ~ "Astanaqul Wa Arbab Jalil",
    CDC_CCDC_Gozar_Name == "Moma-e-Almito" ~ "Moma-E-Almito",
    CDC_CCDC_Gozar_Name == "Bagh -e-Asyeab" ~ "Bagh -E-Asyeab",
    CDC_CCDC_Gozar_Name == "Yaya khil" ~ "Yaya Khil",
    CDC_CCDC_Gozar_Name == "Sar-e Lar" ~ "Sar-E Lar",
    CDC_CCDC_Gozar_Name == "Godan hosainkhil darqad" ~ "Godan Hosainkhil Darqad",
    CDC_CCDC_Gozar_Name == "Ghar ghara" ~ "Ghar Ghara",
    CDC_CCDC_Gozar_Name == "Shad khan Payan" ~ "Shad Khan Payan",
    CDC_CCDC_Gozar_Name == "Qala-e- Ezatullah & Ainullah" ~ "Qala-E- Ezatullah & Ainullah",
    CDC_CCDC_Gozar_Name == "Qala -e-Atoo" ~ "Qala -E-Atoo",
    CDC_CCDC_Gozar_Name == "Qala Khundar and Hakim" ~ "Qala Khundar Wa Hakim",
    CDC_CCDC_Gozar_Name == "Eleventh Street" ~ "Sarak Yazda",
    CDC_CCDC_Gozar_Name == "Miyadad Village" ~ "Miyadad Kali",
    TRUE ~ CDC_CCDC_Gozar_Name
  ))
#for village_name and column
socialData$`Village.(CDC.Name)` = socialData$CDC_CCDC_Gozar_Name

#### changing the datatype of the financial value column ####
##changing to integer adds null values
# socialData$Sub_Project_Financial_Value_In_Afn = as.integer(socialData$Sub_Project_Financial_Value_In_Afn)

##### to verify date formats ####
#all the date columns are correct
View(socialData[grep("date|time|start|end|period", names(socialData), ignore.case = T, value = T)])

conv_date <- function(x, fmt){format.Date(convertToDateTime(x), fmt)}
socialData <- socialData %>% 
  mutate_at(c("SubmissionDate", "Starttime", "Endtime", "Date_And_Time"), ~conv_date(., "%d-%m-%Y %I:%M:%S %p")) %>% 
  mutate(Reporting_Period = conv_date(Reporting_Period, "%d-%m-%Y"))

##### to compare data with Sample Sheet ####
socialData <- socialData %>% 
  rename(Type_Of_Visit = Type_Of_Site_Visit,
         Type_Of_Site_Visit = Type_Of_Visit)
socialColumns = c("Site_Visit_Id",
                 "Line_Ministry_Project_Id",
                 "Line_Ministry_SubProject_Id",
                 "Line_Ministry_Name",
                 "Line_Ministry_Sub_Project_Name_And_Description",
                 "Type_Of_Visit",
                 "Type_Of_Site_Visit",
                 "Province",
                 "District",
                 "CDC_CCDC_Gozar_Name")
sampleColumns = c("Temporary PMT Code", 
                  "Line Ministry Project ID",
                  "Line Ministry sub-project ID",
                  "Line Ministry", 
                  "Line Ministry sub-project name and description",
                  "TPMA Site Visit Type",
                  "If appropriate, type of site visit",
                  "Province Name [Auto-Filled]",
                  "District Name [Auto-Filled]",
                  "CDC Name [auto-filled]")
inconRows <- checkColumnsInTabs(unique(socialData[socialColumns]), sampleData[sampleColumns])
# to extract only the column names that have problem
cols <- inconRows$Inconsistent_Column_Name %>%
  str_split(pattern = " - ") %>%
  unlist() %>% 
  append(c("Site_Visit_Id", "Line_Ministry_SubProject_Id"), .) %>%
  append("Inconsistent_Column_Name") %>% 
  unique()
#extracting the data for those cols
inconData <- inconRows[cols]
write.xlsx(inconData, "output/inconsistent_data/CCAP_May_Social_InconsistentData.xlsx")

#######to ensure data consistency for each tab ####
#*** there are no other tabs in this dataset
#### to compare the TPMA codes with the social data ####
#to compare the TPMA codes with the infra Data
infraData <-  read_excel("output/cleaned_data/May_CCAP_Infrastructure_May-CLEANED.xlsx", sheet="CCAP_main_data")
##all site visit IDs of social is in infra
checkData(unique(socialData["Site_Visit_Id"]), infraData["Site_Visit_Id"], F)

##### Checking Duplicates ##### 
#to ensure data consistency for each column
#for surveyor name
checkDuplicates(socialData, c("Surveyor_Name", "Surveyor_Id", "Surveyor_Gender"), F)

#for id
checkDuplicates(socialData, c("Site_Visit_Id", "Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id", "Type_Of_Site_Visit", "Type_Of_Visit"), F)

#for minitry project ID
checkDuplicates(socialData, c("Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id"), F)

checkDuplicates(socialData, c("Line_Ministry_Project_Id","Province", "District", "CDC_CCDC_Gozar_Name", "CDC_CCDC_Gozar_ID", "Line_Ministry_Name"), F)

#for subproject ID
##the vector below contains some columns that are not in the dataset
vec = c("Line_Ministry_SubProject_Id", "Line_Ministry_Sub_Project_Name_And_Description", 
        "Sub_Project_Financial_Value_In_Afn", 
        "Name_of_Contractor_Facilitating_Partner")
checkDuplicates(socialData, vec, show=f)

# #for contractor facilitating partner
checkDuplicates(socialData, c("Name_of_Contractor_Facilitating_Partner", "Contractor_License_number_Facilitating_Partner_Registration_Number"), show=F)

##### Creating Log ####
col_vec <- c("Surveyor_Name", "Province", "District", "CDC_CCDC_Gozar_Name", "Village.(CDC.Name)",
             "Line_Ministry_Sub_Project_Name_And_Description", "SubmissionDate", "Starttime", "Endtime", "Date_And_Time",
             "Reporting_Period")
log <- create_log(raw_data, socialData, col_vec, "KEY")

##### Exporting Datasets ##### 
#main data 
write_xlsx(socialData, "output/cleaned_data/May_CCAP_Social_May_CLEANED.xlsx")
#Additional useful data 
listOfAdditionalData = list("columns_With_Null"=numOfNull(socialData), "CCAP_Social_May_dataset_log" = log)
write.xlsx(listOfAdditionalData, file = "output/Cleaning_log_for_May_social.xlsx")


