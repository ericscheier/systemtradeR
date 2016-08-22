subsystem.returns=readRDS(paste0(getwd(),"/data/clean/subsystem_returns.RDS"))

equity.data <- subsystem.returns[1:500]
stocks <- names(equity.data)

portf.dn <- portfolio.spec(stocks)
# Add constraint such that the portfolio weights sum to 0*
portf.dn <- add.constraint(portf.dn, type="weight_sum",
                           min_sum=-0.01, max_sum=0.01)
# Add box constraint such that no asset can have a weight of greater than
# 20% or less than -20%
portf.dn <- add.constraint(portf.dn, type="box", min=-0.2, max=0.2)
# Add constraint such that we have at most 20 positions
portf.dn <- add.constraint(portf.dn, type="position_limit", max_pos=5)
# Add constraint such that the portfolio beta is between -0.25 and 0.25
# betas <- t(CAPM.beta(equity.data, market, Rf))
# portf.dn <- add.constraint(portf.dn, type="factor_exposure", B=betas,
#                            lower=-0.25, upper=0.25)

# Add objective to maximize portfolio return with a target of 0.0015
portf.dn.StdDev <- add.objective(portf.dn, type="return", name="mean",
                                 target=0.0015)
# Add objective to minimize portfolio StdDev with a target of 0.02
portf.dn.StdDev <- add.objective(portf.dn.StdDev, type="risk", name="StdDev",
                                 target=0.02)
# Generate random portfolios
rp <- random_portfolios(portf.dn, 1000, "sample")

# Run the optimization
opt.dn <- optimize.portfolio(equity.data, portf.dn.StdDev,
                                         optimize_method="DEoptim", search_size = 2000, trace = TRUE, traceDE = 5)
# Run the optimization w/ rebalancing
opt.dn <- optimize.portfolio.rebalancing(equity.data, portf.dn.StdDev,
                             optimize_method="random", rp=rp,
                             rebalance_on="hours")

chart.Weights(opt.dn, main="Instrument Weights")
plot(opt.dn, main="Dollar Neutral Portfolio", risk.col="StdDev", neighbors=10)
