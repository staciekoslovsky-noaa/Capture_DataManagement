# Import food habits data into DB
# S. Koslovsky, February 2026

library(RPostgreSQL)
library(tidyverse)

# Connect to PostgreSQL (for getting information for processing data)
con <- RPostgreSQL::dbConnect(PostgreSQL(),
                              dbname = Sys.getenv("pep_db"),
                              host = Sys.getenv("pep_ip"),
                              user = Sys.getenv("pep_user"),
                              password = Sys.getenv("user_pw"))

next_id <- RPostgreSQL:: dbGetQuery(con, "SELECT max(id) FROM capture.tbl_sample_results_food_prey")
lku_bone <- RPostgreSQL:: dbGetQuery(con, "SELECT * FROM capture.lku_prey_bone")

RPostgreSQL::dbDisconnect(con)
rm(con)

# Read CSV file
data <- read.csv("C:\\Users\\Stacie.Hardy\\Work\\SMK\\Projects\\Capture\\Data\\CaptureSampleResults\\PEP 2022-2024 hard parts_20260205.csv", header = TRUE) %>%
  select(-Species, -VialType, -SpeciesName, -ConfCode, -ConfDef, -Edited) %>%
  rename(speno = SampleLabel,
         prey_species_lku = SpeciesCode,
         part_code = PartCode,
         bone = PartName,
         bone_side_lku = PartSide,
         part_count = PartCount,
         bone_condition_lku = PartGrade,
         bone_measure_mm = Measure,
         identified_by = IDInitials,
         date_identified = IDDate,
         prey_comments = Comments) %>%
  mutate(part_code = ifelse(bone == 'Whole/partial remains', 9999, part_code)) %>%
  mutate(bone_side_lku = ifelse(bone_side_lku == "", NA, bone_side_lku)) %>%
  mutate(bone_condition_lku = ifelse(bone_condition_lku == "Good", "G",
                                     ifelse(bone_condition_lku == "Fair", "F",
                                            ifelse(bone_condition_lku == "Poor", "P", NA)))) %>%
  mutate(prey_comments = ifelse(prey_comments == "", NA, prey_comments)) %>%
  mutate(date_identified = ifelse(date_identified == "", '2/4/2026', date_identified)) %>%
  mutate(date_identified = as.Date(date_identified, format = "%m/%d/%Y")) %>% 
  group_by(speno, prey_species_lku) %>%
  mutate(food_prey_id = cur_group_id() + next_id$max) %>%
  ungroup()

data_num_oto <- data %>%
  filter(bone == "Otolith") %>%
  select(speno, prey_species_lku, bone_side_lku) %>%
  group_by(speno, prey_species_lku) %>%
  count(bone_side_lku) %>%
  pivot_wider(names_from = bone_side_lku, values_from = n) %>%
  replace_na(list(L = 0, R = 0, U = 0)) %>%
  rename(num_oto_left = L,
         num_oto_right = R,
         num_oto_unk = UNK) %>%
  ungroup()

data_num_beak <- data %>%
  filter(bone == "Beak") %>%
  select(speno, prey_species_lku, bone_side_lku) %>%
  group_by(speno, prey_species_lku) %>%
  count(bone_side_lku) %>%
  pivot_wider(names_from = bone_side_lku, values_from = n) %>%
  rename(num_beak_upper = UP,
         num_beak_lower = LO) %>%
  ungroup()

data_num_condition <- data %>%
  filter(bone == "Otolith" | bone == "Beak") %>%
  select(speno, prey_species_lku, bone_condition_lku) %>%
  group_by(speno, prey_species_lku) %>%
  count(bone_condition_lku) %>%
  pivot_wider(names_from = bone_condition_lku, values_from = n) %>%
  rename(num_good = G,
         num_fair = F,
         num_poor = P) %>%
  ungroup() %>%
  replace_na(list(num_good = 0, num_fair = 0, num_poor = 0))
  
# Process data for import
# Might have to handle comments differently in the future if not unique to each food_prey_id
prey_comments <- data %>%
  select(food_prey_id, prey_comments) %>%
  filter(!is.na(prey_comments)) %>%
  unique()

import_prey <- data %>%
  select(food_prey_id, speno, date_identified, prey_species_lku, identified_by) %>%
  rename(id = food_prey_id) %>%
  unique() %>%
  left_join(data_num_oto, by = c("speno", "prey_species_lku")) %>%
  left_join(data_num_beak, by = c("speno", "prey_species_lku")) %>%
  left_join(data_num_condition, by = c("speno", "prey_species_lku")) %>%
  replace_na(list(num_oto_left = 0, num_oto_right = 0, num_oto_unk = 0,
                  num_beak_upper = 0, num_beak_lower = 0,
                  num_good = -99, num_fair = -99, num_poor = -99)) %>%
  mutate(prey_age = 'Unknown') %>%
  left_join(prey_comments, join_by("id" == "food_prey_id")) %>%
  select(id, speno, date_identified, num_oto_left, num_oto_right, num_oto_unk, 
         num_good, num_fair, num_poor, prey_comments,
         prey_age, prey_species_lku, identified_by, num_beak_upper, num_beak_lower)

import_bone <- data %>%
  left_join(lku_bone, by = "part_code") %>%
  select(food_prey_id, bone_lku, bone_side_lku, bone_condition_lku) %>%
  group_by(food_prey_id, bone_lku, bone_side_lku, bone_condition_lku) %>%
  count() %>%
  rename(bone_count = n)

import_measure <- data %>%
  left_join(lku_bone, by = "part_code") %>%
  select(food_prey_id, bone_measure_mm, bone_condition_lku, bone_lku, bone_side_lku) %>%
  filter(!is.na(bone_measure_mm))
  
# Connect to PostgreSQL (for getting information for processing data)
con <- RPostgreSQL::dbConnect(PostgreSQL(),
                              dbname = Sys.getenv("pep_db"),
                              host = Sys.getenv("pep_ip"),
                              user = Sys.getenv("pep_user"),
                              password = Sys.getenv("user_pw"))

RPostgreSQL::dbWriteTable(con, c("capture", "tbl_sample_results_food_prey"), import_prey, append = TRUE, row.names = FALSE)
RPostgreSQL::dbWriteTable(con, c("capture", "tbl_sample_results_food_bones"), import_bone, append = TRUE, row.names = FALSE)
RPostgreSQL::dbWriteTable(con, c("capture", "tbl_sample_results_food_measure"), import_measure, append = TRUE, row.names = FALSE)

RPostgreSQL::dbDisconnect(con)
rm(con, data_num_beak, data_num_condition, data_num_oto, lku_bone, next_id, prey_comments)