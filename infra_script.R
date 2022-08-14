rm(list=ls())
#all cleaned and log generated!
############# install necessary packages #############
#install.packages("summarytools")
if(!require("tidyverse")) install.packages("tidyverse")
if(!require("readxl")) install.packages("readxl")
if(!require("writexl")) install.packages("writexl")
if(!require("dplyr")) install.packages("dplyr")
if(!require("xlsx")) install.packages("xlsx")
if(!require("openxlsx")) install.packages("openxlsx")
# Summarytools documentation: https://cran.r-project.org/web/packages/summarytools/vignettes/Introduction.html

############# load libraries #############
library(readxl)
library(writexl)
library(tidyverse)
library(xlsx)
library(openxlsx)
library(googlesheets4)

############# Loading Datasets #############
source("functions/functions.R")

stdColumns <- c(
  "Surveyor_Name",
  "Surveyor_Id",
  "Surveyor_Gender",
  "Site_Visit_Id",
  "Province",
  "District",
  "Village_Cdc_Name",
  "Line_Ministry_Name",
  "Line_Ministry_Project_Id",
  'Line_Ministry_SubProject_Id',
  'Line_Ministry_sub_project_name',
  'Line_Ministry_Sub_Project_Name_And_Description',
  'Sub_Project_Financial_Value_In_Afn',
  'CDC_CCDC_Gozar_Name',
  'CDC_CCDC_Gozar_ID',
  'Name_of_Contractor_Facilitating_Partner',
  'Type_Of_Site_Visit',
  'Type_Of_Visit',
  'If_not_a_first_Site_Visit_state_Original_Site_Visit_ID',
  'Subproject_status_based_on_MIS_database'
)
infraData <-  read_excel("input/raw_data/May_CCAP_Infrastructure_May-CLEANED.xlsx", sheet="CCAP_main_data")

#for employee data
direc <- "input/emp_data/Phone Numbers of SMEs.xlsx"
empData <- read_excel(direc, sheet = "July payment tracker_DVE-SME")
#to paste together the name and the lastname
empN <- empData %>% 
  unite("fullName",'First Name':'Last Name', sep=" ")

direc <- "input/emp_data/Terminated contracts_ART TPMA.xls"
terminatedEmp <- read_excel(direc)

############# Functions for checking data columns #############
#to display columns that does not exist
checkColumns(stdColumns, infraData)
#columns that exist
columnExist(stdColumns, infraData)

############# Fixing inconsistencies #############
infraData <- infraData %>% 
  rename(Surveyor_Name = tpma_monitor_name,
         Site_Visit_Id = tpma_project_id ,
         Province = province...3,
         District = district...4,
         Line_Ministry_Name = project,
         Line_Ministry_SubProject_Id = ministry_subproject_id,
         Line_Ministry_sub_project_name = ministry_sub_project_name,
         Name_of_Contractor_Facilitating_Partner = fp_name,
         CDC_CCDC_Gozar_Name = cdcccdcgozar_name...5,
         Subproject_status_based_on_MIS_database = subproject_status_in_the_mis_database_) %>% 
  select(-province...26, -district...27, -cdcccdcgozar_name...28)

############# adding new columns with null values #############
#will use the dataset of the employees to fetch the IDs
infraData = infraData %>%
  add_column(Surveyor_Id = NA, .after="Surveyor_Name")
#all suveyors are male in infra data
infraData = infraData %>%
  add_column(Surveyor_Gender = "Male", .after="Surveyor_Id")
infraData = infraData %>%
  add_column(Village_Cdc_Name = NA, .after="District")
infraData = infraData %>%
  add_column(Line_Ministry_Project_Id = NA, .after="Line_Ministry_Name")
infraData = infraData %>%
  add_column(Line_Ministry_Sub_Project_Name_And_Description = NA, .after="Line_Ministry_sub_project_name")
infraData = infraData %>%
  add_column(Sub_Project_Financial_Value_In_Afn = NA, .after="Line_Ministry_Sub_Project_Name_And_Description")
infraData = infraData %>%
  add_column(CDC_CCDC_Gozar_ID = NA, .after="CDC_CCDC_Gozar_Name")
infraData = infraData %>%
  add_column(Type_Of_Site_Visit = NA, .after="Name_of_Contractor_Facilitating_Partner")
infraData = infraData %>%
  add_column(Type_Of_Visit = NA, .after="Type_Of_Site_Visit")
infraData = infraData %>%
  add_column(If_not_a_first_Site_Visit_state_Original_Site_Visit_ID = NA, .after="Type_Of_Visit")

#to print the index of newly added columns 
# for(i in 1:length(stdColumns)){
#   cat(stdColumns[i], grep(stdColumns[i], names(infraData)), "\n")
# }


##for creating log 
raw_data <- infraData
############# to fill null values #############
#for Line Ministry Project ID / Name / Description
link <- ""
sampleData <- read_sheet(link, sheet = "Sample Sheet")
sampleData$`Line Ministry sub-project ID` <- as.character(sampleData$`Line Ministry sub-project ID`)
sampleData$`Line Ministry Project ID` <- as.character(sampleData$`Line Ministry Project ID`)

#changing data type from null to string
infraData$Surveyor_Id = as.character(infraData$Surveyor_Id)
infraData$Line_Ministry_Project_Id = as.character(infraData$Line_Ministry_Project_Id)
infraData$Line_Ministry_Sub_Project_Name_And_Description = as.character(infraData$Line_Ministry_Sub_Project_Name_And_Description)
infraData$Sub_Project_Financial_Value_In_Afn = as.character(infraData$Sub_Project_Financial_Value_In_Afn)
infraData$Type_Of_Visit = as.character(infraData$Type_Of_Visit)
infraData$Type_Of_Site_Visit = as.character(infraData$Type_Of_Site_Visit)
infraData$Name_of_Contractor_Facilitating_Partner = as.character(infraData$Name_of_Contractor_Facilitating_Partner)
#To extract Line_Ministry_Project_Id from Line_Ministry_SubProject_Id
for (i in 1:nrow(infraData)){
  #fetching Line_Ministry_Subproject_Id
  subProjectId <- infraData$Line_Ministry_SubProject_Id[i]
  #splitting each character
  subId <- strsplit(subProjectId, "")[[1]]
  
  #to count the number of dashes
  count <- 0;
  id <- ""
  for(j in 1:length(subId)){
    if(subId[j] == "-"){
      count<-count+1
    }
    #only take the characters before the third dash
    if(count < 3){
      id <- paste(id,subId[j], sep = "")
    }
  }
  infraData[i, "Line_Ministry_Project_Id"] <- id
}

#Extracting data from sample
for (i in 1:nrow(infraData)){
  id <- toString(infraData[i, "Line_Ministry_Project_Id"])
  siteVisitId <- toString(infraData[i, "Site_Visit_Id"])
  
  # print(paste(i, "- ", sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry sub-project ID"]))
  if(i == 62){
    next
  } else {
    infraData[i,"Line_Ministry_Name"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry"]
    infraData[i,"Line_Ministry_SubProject_Id"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry sub-project ID"]
    infraData[i,"Line_Ministry_Sub_Project_Name_And_Description"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"Line Ministry sub-project name and description"]
    infraData[i,"Type_Of_Visit"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"TPMA Site Visit Type"]
    infraData[i,"Type_Of_Site_Visit"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"If appropriate, type of site visit"]
    # infraData[i,"Name_of_Contractor_Facilitating_Partner"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"If appropriate, name of contractor"]
  }
}

#completing Surveyor's ID from the employee data 
infraData <- infraData %>% 
  mutate(Surveyor_Name = case_when(
    Surveyor_Name == "" ~ "",
    TRUE ~ Surveyor_Name
  ),
  Surveyor_Id = case_when(
    Surveyor_Name == "" ~ "",
    TRUE ~ Surveyor_Id
  ))

#to compare surveyor names and fetch the Surveyor_Id
missingEmp <- data.frame()
for (i in 1:nrow(infraData)) {
  surN <- infraData$Surveyor_Name[i]
  
  if(surN %in% empN$fullName){
    infraData$Surveyor_Id[i] <- empN$`ATR ID #`[empN$fullName %in% surN]
  } else if (surN %in% terminatedEmp$Name) {
    infraData$Surveyor_Id[i] <- terminatedEmp$`ATR ID NO`[terminatedEmp$Name %in% surN]
  } else {
    missingEmp <- rbind(missingEmp, infraData[i, c("Surveyor_Name", "Surveyor_Id")])
  }
}
missingEmp <- unique(missingEmp)
# ####LOG for test ##
# emp_log <- data.frame()
# for(i in 1:nrow(missingEmp)){
#   emp_log = rbind(emp_log, unique(infraData[infraData$Surveyor_Name == missingEmp[i,1], c("Site_Visit_Id", "Surveyor_Name")]))
# }
# write.xlsx(missingEmp, "output/forEmpLog.xlsx")

############# For Data Cleanign Guidelines #############
##unifying the inconsistencies in province, district and CDC/village using GeoApp
geoApp <- read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "District")
standardP <- unique(geoApp[,"Province"])
standardDis <- unique(geoApp[,"District"])
##### for Provinces ##### 
diffSpelling <- checkData(unique(infraData["Province"]), standardP, F)
infraData <- infraData %>% 
  mutate(Province = case_when(
    Province == "Sari Pul" ~ "Sar-I-Pul",
    Province == "Paktiya" ~ "Paktia", 
    Province == "Panjsher" ~ "Panjshir",
    TRUE ~ Province
  ))

##### For districts ##### 
diffSpelling <- checkData(unique(infraData["District"]), standardDis, F)
#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  row <- unique(infraData[infraData$District %in% diffSpelling[i,1], c("Province", "District")])
  print(row)
}
#manually fixing spellings
infraData <- infraData %>% 
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
    District == "Dara-e-Noor" ~ "Darah-E-Noor",
    District == "Mihtarlam" ~ "Mehterlam",
    District == "Ismail khill & Mandozai" ~ "Manduzay (Esmayel Khel)",
    District == "Mazar-e-Sharif" ~ "Mazar-E-Sharif",
    District == "Khost (Matun)" ~ "Khost",
    District == "Fayzabad" ~ "Faiz Abad",
    District == "Chawkay" ~ "Sawkai",
    District == "Musayi" ~ "Musahi",
    District == "Hesa-e-Awale Behsod" ~ "Hissa-E-Awali Bihsud",
    District == "Puli Khumri" ~ "Pul-I-Khumri",
    District == "Chah Ab" ~ "Chahab",
    District == "Ishkashim" ~ "Eshkashim",
    TRUE ~ District
  ))


##### for cdc_gozar_name ##### 
geoAppVillage = read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "Village_CDC")
#subsetting villages using the Districts that are present in the dataset
villages <- geoAppVillage %>%
  filter(District %in% infraData$District) %>% 
  select(Village) %>% 
  rename(CDC_CCDC_Gozar_Name = Village)

#to find the inconsistent gozar names
diffSpelling <- checkData(unique(infraData["CDC_CCDC_Gozar_Name"]), villages, F)
# ####LOG for test ##
# cdc_log <- data.frame()
# for(i in 1:nrow(diffSpelling)){
#   cdc_log = rbind(cdc_log, unique(infraData[infraData$CDC_CCDC_Gozar_Name == diffSpelling[i,1], c("fulcrum_id", "CDC_CCDC_Gozar_Name")]))
# }
# write.xlsx(cdc_log, "output/forDistrictLog.xlsx")
diffSpelling <- infraData %>%
  filter(CDC_CCDC_Gozar_Name %in% diffSpelling[[1]] & !(District %in% c("Herat", "Kandahar", "Mazar-E-Sharif", "Jalalabad"))) %>%
  select(Province, District, CDC_CCDC_Gozar_Name) %>%
  unique()


#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  print(diffSpelling[i,])
}

#Fixing inconsistent Gozar names 
infraData <-  infraData %>% 
  mutate(CDC_CCDC_Gozar_Name = case_when(
    CDC_CCDC_Gozar_Name == "Doabi Village CDC" ~ "Doabi",
    CDC_CCDC_Gozar_Name == "Robat Payan CDC" ~ "Robat Payan",
    CDC_CCDC_Gozar_Name == "Dalan to" ~ "Dalan To",
    CDC_CCDC_Gozar_Name == "Mahal bala pusht joy" ~ "Mahal Bala Pusht Joy",
    CDC_CCDC_Gozar_Name == "Abdul Jalil Khan" ~ "Abdul Jalil",
    CDC_CCDC_Gozar_Name == "Koz salampoor" ~ "Koz Salampoor",
    CDC_CCDC_Gozar_Name == "Khawaja Akber" ~ "Khawaja  Akber",
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
    CDC_CCDC_Gozar_Name == "Astanaqul wa Arbab jalil" ~ "Astanaqul Wa Arbab Jalil",
    CDC_CCDC_Gozar_Name == "Moma-e-Almito" ~ "Moma-E-Almito",
    CDC_CCDC_Gozar_Name == "Bagh -e-Asyeab" ~ "Bagh -E-Asyeab",
    CDC_CCDC_Gozar_Name == "Yahya khil" ~ "Yaya Khil",
    CDC_CCDC_Gozar_Name == "Sar-e Lar" ~ "Sar-E Lar",
    CDC_CCDC_Gozar_Name == "Godan hosainkhil darqad" ~ "Godan Hosainkhil Darqad",
    CDC_CCDC_Gozar_Name == "Ghar ghara" ~ "Ghar Ghara",
    CDC_CCDC_Gozar_Name == "Shad khan Payan" ~ "Shad Khan Payan",
    CDC_CCDC_Gozar_Name == "Qala-e- Ezatullah & Ainullah" ~ "Qala-E- Ezatullah & Ainullah",
    CDC_CCDC_Gozar_Name == "Qala -e-Atoo" ~ "Qala -E-Atoo",
    #based on sample
    CDC_CCDC_Gozar_Name == "Ziaul Haq Mina" ~ "Zia ul Haq Mina",
    CDC_CCDC_Gozar_Name == "Khairya" ~ "Khairia",
    CDC_CCDC_Gozar_Name == "Zaid bin Sabit" ~ "Zaid Bin Sabite",
    CDC_CCDC_Gozar_Name == "Sarband Ali" ~ "Sarbend Ali",
    CDC_CCDC_Gozar_Name == "Spin Ghar" ~ "Speen Ghar",
    CDC_CCDC_Gozar_Name == "Inkeshaf" ~ "Inkishaf",
    TRUE ~ CDC_CCDC_Gozar_Name
  ))

##### for village_name and column ##### 
#changing data type from null to string
infraData$Village_Cdc_Name <- infraData$CDC_CCDC_Gozar_Name
infraData$CDC_CCDC_Gozar_ID = infraData$Line_Ministry_Project_Id
#changing the datatype of the financial value column
infraData$Sub_Project_Financial_Value_In_Afn = as.integer(infraData$Sub_Project_Financial_Value_In_Afn)


##### Fixing Dates ##### ####
# #to verify date formats
View(infraData[grep("date|time|start|end|period|create", names(infraData), ignore.case = T, value = T)])

infraData <- infraData %>% 
  mutate_at(c("created_at","updated_at", "system_created_at", "system_updated_at"), ~format.Date(., "%d-%m-%Y %I:%M:%S %p")) %>% 
  mutate_at(c("subproject_planned_completion_date" ,"subproject_actual_completion_date" , "subproject_actual_start_date" ,
              "subproject_planned_start_date", "verification_date"), ~format.Date(., "%d-%m-%Y"))

##### to compare data with Sample Sheet ####
infraColumns = c("Site_Visit_Id",
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
inconRows = checkColumnsInTabs(unique(infraData[infraColumns]), sampleData[sampleColumns])
# to extract only the column names that have problem
cols <- inconRows$Inconsistent_Column_Name %>%
  str_split(pattern = " - ") %>%
  unlist() %>% 
  append(c("Site_Visit_Id", "Line_Ministry_SubProject_Id"), .) %>%
  append("Inconsistent_Column_Name") %>% 
  unique()
#extracting the data for those cols
inconData <- inconRows[cols]
write.xlsx(inconData, "output/inconsistent_data/CCAP_May_Infra_InconsistentData.xlsx")

#######to ensure data consistency for each tab #####
##### For tab2 of the dataset ##### 
tab2 = read.xlsx("input/raw_data/May_CCAP_Infrastructure_May-CLEANED.xlsx", sheet = "Repeatable_element")
columnExist(stdColumns, tab2)
#fixing inconsistent names
tab2 <- tab2 %>% 
  rename(Site_Visit_Id = tpma_project_id,
         Line_Ministry_Name = ministry,
         Province = province,
         District = district,
         CDC_CCDC_Gozar_Name = cdcccdcgozar_name, 
         Name_of_Contractor_Facilitating_Partner = fp_name,
         Line_Ministry_SubProject_Id = ministry_subproject_id,
         Line_Ministry_sub_project_name = ministry_sub_project_name
         )
tab2_raw <- tab2
#to remove redundant rows from tab2 and log them
#* there are no redundant rows
siteVisitIds = checkData(unique(tab2["Site_Visit_Id"]), infraData["Site_Visit_Id"],F)

#to update the values based on fixed values from main tab
for(i in 1:nrow(tab2)){
  id <- tab2$Site_Visit_Id[i]
  
  tab2$Line_Ministry_SubProject_Id[i] <- infraData$Line_Ministry_SubProject_Id[infraData$Site_Visit_Id %in% id]
  tab2$Province[i] <- infraData$Province[infraData$Site_Visit_Id %in% id]
  tab2$District[i] <- infraData$District[infraData$Site_Visit_Id %in% id]
  tab2$CDC_CCDC_Gozar_Name[i] <- infraData$CDC_CCDC_Gozar_Name[infraData$Site_Visit_Id %in% id]
  tab2$Line_Ministry_sub_project_name[i] <- infraData$Line_Ministry_sub_project_name[infraData$Site_Visit_Id %in% id]
  tab2$Name_of_Contractor_Facilitating_Partner[i] <- infraData$Name_of_Contractor_Facilitating_Partner[infraData$Site_Visit_Id %in% id]
  tab2$Line_Ministry_Name[i] <- infraData$Line_Ministry_Name[infraData$Site_Visit_Id %in% id]
}
#to fix dates
tab2 <- tab2 %>% 
  mutate_at(c("created_at","updated_at"), ~format.Date(., "%d-%m-%Y %I:%M:%S %p"))

columnNames = c("Site_Visit_Id", "Province", "District", "CDC_CCDC_Gozar_Name", "Name_of_Contractor_Facilitating_Partner", 
                "Line_Ministry_Name", "Line_Ministry_SubProject_Id", "Line_Ministry_sub_project_name")
inconRows <- checkColumnsInTabs(unique(tab2[columnNames]), infraData[columnNames])
##### Creating Log ####
col_vec <- c("Site_Visit_Id", "Province", "District", "CDC_CCDC_Gozar_Name", "Name_of_Contractor_Facilitating_Partner", 
             "Line_Ministry_Name", "Line_Ministry_SubProject_Id", "Line_Ministry_sub_project_name", "created_at", "updated_at")
Repeatable_element_log <- create_log(tab2_raw, tab2, col_vec, "fulcrum_record_id")

##### Checking Duplicates ##### 
#to compare the TPMA codes with the social data
##leave it when both data are cleaned and finalized

#for surveyor name
checkDuplicates(infraData, c("Surveyor_Name", "Surveyor_Id", "Surveyor_Gender"), F)

#for id
checkDuplicates(infraData, c("Site_Visit_Id", "Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id", "Type_Of_Site_Visit", "Type_Of_Visit"), F)

#for minitry project ID
checkDuplicates(infraData, c("Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id"), F)

checkDuplicates(infraData, c("Line_Ministry_Project_Id","Province", "District", "Village_Cdc_Name", "CDC_CCDC_Gozar_Name", "CDC_CCDC_Gozar_ID", "Line_Ministry_Name"), T)

#for subproject ID
#** "Type_Of_Implementing_Partner" doesnt exist in this dataset
vec = c("Line_Ministry_SubProject_Id", "Line_Ministry_Sub_Project_Name_And_Description", "Sub_Project_Financial_Value_In_Afn", "Name_of_Contractor_Facilitating_Partner")
checkDuplicates(infraData, vec, show<-F)

#for contractor facilitating partner
checkDuplicates(infraData, c("Name_of_Contractor_Facilitating_Partner", "Contractor_License_number_Facilitating_Partner_Registration_Number"), show<-F)

##### Creating Log ####
col_vec <- c("Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id", "Line_Ministry_Name", "Line_Ministry_Sub_Project_Name_And_Description", "Type_Of_Visit", "Type_Of_Site_Visit", "Surveyor_Name", "Province", "District", "CDC_CCDC_Gozar_Name", "Village_Cdc_Name", "CDC_CCDC_Gozar_ID",
             "created_at", "updated_at","system_created_at", "system_updated_at", "subproject_planned_completion_date",
             "subproject_actual_completion_date", "subproject_actual_start_date", "subproject_planned_start_date", "verification_date")
log <- create_log(raw_data, infraData, col_vec, "fulcrum_id")


##### Exporting Datasets ##### 
#main data
listOfDatasets = list("CCAP_main_data"=infraData, "Repeatable_element"=tab2)
write.xlsx(listOfDatasets, file = "output/cleaned_data/May_CCAP_Infrastructure_May-CLEANED.xlsx")

#Log
listOfDatasets = list("CCAP_main_data_log"=log, "Repeatable_element_log"=Repeatable_element_log)
# write.xlsx(listOfDatasets, file = "output/cleaning_log_for_May_infra.xlsx")
