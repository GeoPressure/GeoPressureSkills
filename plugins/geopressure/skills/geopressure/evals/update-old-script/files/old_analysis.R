# Analysis of my Great Reed Warbler tag, written in 2022
library(GeoPressureR)

pam <- pam_read(
  pathname = "data/0_PAM/18LX",
  crop_start = "2017-06-20",
  crop_end = "2018-05-02"
)
pam <- pam_classify(pam)
trainset_write(pam, pathname = "data/1_pre_processed/")
pam <- trainset_read(pam, pathname = "data/1_pre_processed/")
pam <- pam_sta(pam)

raster_list <- geopressure_map(
  pam$pressure,
  extent = c(50, -16, 0, 23),
  scale = 4,
  max_sample = 250,
  margin = 30
)
prob_map_list <- geopressure_prob_map(raster_list, s = 1, thr = 0.9)

twl <- find_twilights(pam$light)

bird <- flight_bird("Acrocephalus arundinaceus")
grl <- graph_create(prob_map_list, thr_prob_percentile = 0.99, thr_gs = 150)
grl <- graph_download_wind(grl)
shortest_path <- graph_shortestpath(grl)
