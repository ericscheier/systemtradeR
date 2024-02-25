# systemtradeR

A systematic trading engine in R, based on Robert Carver's Systematic Trading.

- Full implementation of canonical portfolio management framework per Carver
- Poloniex integration for historical data and account management (lending, margin, and exchange trading)
- Limit orders
- Shiny read-only dashboard
- Slack alerts
- Event-driven backtesting in quantstrat (takes a long time)
- Some parallelization

TODO
- Replace poloniex with coinbase and ccxt
- add telegram/signal/sms/email/whatsapp alerts
- speed up backtesting
- package for CRAN