library(RPostgreSQL)

# Connect to PostgreSQL
con <- RPostgreSQL::dbConnect(PostgreSQL(),
                              dbname = Sys.getenv("pep_db"),
                              host = Sys.getenv("pep_ip"),
                              user = Sys.getenv("pep_user"),
                              password = Sys.getenv("user_pw"))

# Get data from DB for ribbon and spotted seals
summ_prey_by_species <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM capture.summ_prey_by_species WHERE SPENO LIKE \'PL%\' OR SPENO LIKE \'HF%\'")

# Pulls food habits: prey data
prey <- RPostgreSQL::dbGetQuery(con, "SELECT id as food_prey_id, speno, series_num, date_identified, identified_by, prey_species
                                num_oto_left, num_oto_right, num_oto_unk, num_beak_lower, num_beak_upper, 
                                num_good, num_fair, num_poor, prey_age, prey_comments
                                FROM capture.tbl_sample_results_food_prey 
                                LEFT JOIN capture.lku_prey_species USING (prey_species_lku)
                                WHERE SPENO LIKE \'PL%\' OR SPENO LIKE \'HF%\'")

# Pulls food habits: bone presence data
bones <- RPostgreSQL::dbGetQuery(con, "SELECT food_prey_id, p.speno, bone, bone_side, bone_condition, bone_count FROM capture.tbl_sample_results_food_bones b 
                                 INNER JOIN capture.tbl_sample_results_food_prey p ON p.id = b.food_prey_id
                                 LEFT JOIN capture.lku_prey_bone USING (bone_lku)
                                 LEFT JOIN capture.lku_prey_bone_side USING (bone_side_lku)
                                 LEFT JOIN capture.lku_prey_bone_condition USING (bone_condition_lku)
                                 WHERE SPENO LIKE \'PL%\' OR SPENO LIKE \'HF%\'")

# Pulls food habits: measurements data
measure <- RPostgreSQL::dbGetQuery(con, "SELECT food_prey_id, p.speno, bone_measure_mm, bone, bone_condition, bone_side
                                  FROM capture.tbl_sample_results_food_measure m 
                                  INNER JOIN capture.tbl_sample_results_food_prey p ON p.id = m.food_prey_id
                                  LEFT JOIN capture.lku_prey_bone USING (bone_lku)
                                  LEFT JOIN capture.lku_prey_bone_side USING (bone_side_lku)
                                  LEFT JOIN capture.lku_prey_bone_condition USING (bone_condition_lku)
                                  WHERE SPENO LIKE \'PL%\' OR SPENO LIKE \'HF%\'")

# PUlls capture data for all ribbon and spotted seals
speno <- RPostgreSQL::dbGetQuery(con, "SELECT speno, capture_type, common_name, capture_lat, capture_long, capture_dt, sex, age_class, std_length_cm, final_mass_kg
                                FROM capture.tbl_event e
                                LEFT JOIN capture.lku_capture_type USING (capture_type_lku)
                                LEFT JOIN capture.lku_species USING (species_lku)
                                LEFT JOIN capture.lku_sex USING (sex_lku)
                                LEFT JOIN capture.lku_age_class USING (age_class_lku)
                                LEFT JOIN capture.tbl_morph m ON e.id = m.event_id
                                WHERE species_lku = \'Pl\' OR species_lku = \'Hf\'")

RPostgreSQL::dbDisconnect(con)
rm(con)