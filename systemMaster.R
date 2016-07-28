#!/usr/bin/Rscript
source("systemConfig.R")

if(system.config$live){slackr_bot(systemUpdate())}
if(!system.config$live){systemUpdate()}