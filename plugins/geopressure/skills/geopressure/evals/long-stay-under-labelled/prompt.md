---
tags: [geopressure]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, WebFetch]
---

I'm checking the labels of a Whinchat that wintered 120 days in Guinea. For that stationary period, pressurepath_check() gives error_sd = 0.75 hPa (I used sd = 1), so it looks fine, but n_outlier is 7: six isolated points are 4 to 7 hPa off, and in mid-February the residual jumps by 1.5 hPa within an hour and stays there for four weeks. There are no discards in that period. twilight_check() also flags 9 twilights outside_ci in that stay, and none is discarded. Is this period good enough, or should I change something?
