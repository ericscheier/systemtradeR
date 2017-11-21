url = 'http://www.football-data.co.uk/mmz4281/1516/E0.csv'
football_season = read.csv(url, stringsAsFactors = F)
head(football_season)

suppressWarnings(library(dplyr))
football_season = football_season %>%
  transmute(HomeTeam, AwayTeam, FTR,B365H, B365D, B365A)
head(football_season)

library(reshape2)

football_season_melt = melt(football_season, 
                            id.vars = c("HomeTeam", "AwayTeam", "FTR"), 
                            variable.name = "Bet_Value",
                            value.name = "Odd")
head(football_season_melt)

# For every match find the riskiest and safest bet with the correspondent odd value
football_season_reshaped = football_season_melt %>% 
  group_by(HomeTeam, AwayTeam, FTR) %>% 
  filter(length(unique(Odd)) == 3) %>% # Remove matches with equal odds
  summarize(
    Risky_Bet_Value = max(Odd),
    Risky_Bet_Result = gsub("B365", "", Bet_Value[Odd == Risky_Bet_Value]),
    Safe_Bet_Value = min(Odd),
    Safe_Bet_Result = gsub("B365", "", Bet_Value[Odd == Safe_Bet_Value])
  ) %>%
  ungroup()
head(data.frame(football_season_reshaped))

football_season_with_results = football_season_reshaped %>% 
  mutate(Winner = ifelse(FTR == Risky_Bet_Result, 'Risky', 
                         ifelse(FTR == Safe_Bet_Result , 'Safe', 'Both Loser')),
         Won_Money = ifelse(Winner == 'Both Loser', 0,
                            ifelse(Winner == 'Safe', Safe_Bet_Value, Risky_Bet_Value)))
head(data.frame(football_season_with_results))

library(ggplot2)
suppressWarnings(library(gridExtra))

# Aggregate by bet type
football_season_with_results_agg = football_season_with_results %>%
  filter(Winner != 'Both Loser') %>%
  group_by(Winner) %>%
  summarize(Count = n(), Won_Money = sum(Won_Money) - nrow(football_season_with_results)) %>%
  ungroup()
# Plot number of won bets
G1 = ggplot(football_season_with_results_agg, aes(x = Winner, y = Count, fill = Winner)) + 
  geom_bar(stat = "identity") + 
  geom_text(aes(label = Count), vjust = -.3) + 
  theme_minimal() + 
  xlab("") + 
  ylab("Won Bets\n") +
  scale_fill_manual(values = c("#1a476f", "#90353b", "#55752f")) +
  theme_minimal() + 
  theme(legend.position = "none")
# Plot number of won money
G2 = ggplot(football_season_with_results_agg, aes(x = Winner, y = Won_Money, fill = Winner)) + 
  geom_bar(stat = "identity") + 
  geom_text(aes(label = paste0(Won_Money, "GBP")), vjust = -.3) + 
  theme_minimal() + 
  xlab("\nApproach Used") + 
  scale_y_continuous("Won Money\n", label = function(x){ paste0(x, "GBP") }) +
  scale_fill_manual(values = c("#1a476f", "#90353b", "#55752f")) +
  theme_minimal() + 
  theme(legend.position = "none")
grid.arrange(G1, G2, ncol = 1)

all_seasons = lapply(2003:2015, function(year){
  # Create the url
  year_text = paste0(strsplit(as.character(year), "", fixed = TRUE)[[1]][3:4], collapse = "")
  next_year_text = paste0(strsplit(as.character(year + 1), "", fixed = TRUE)[[1]][3:4], collapse = "")
  url = paste0("http://www.football-data.co.uk/mmz4281/", year_text, next_year_text, "/E0.csv")
  # Get the .csv file
  tmp_season = read.csv(url, stringsAsFactors = F)
  # Reshape and run analysis
  tmp_season_reshaped = tmp_season %>%
    transmute(HomeTeam, AwayTeam, FTR,B365H, B365D, B365A) %>%
    melt(id.vars = c("HomeTeam", "AwayTeam", "FTR"), variable.name = "Bet_Value", value.name = "Odd") %>%
    group_by(HomeTeam, AwayTeam, FTR) %>% 
    filter(length(unique(Odd)) == 3) %>%
    summarize(
      Risky_Bet_Value = max(Odd),
      Risky_Bet_Result = gsub("B365", "", Bet_Value[Odd == Risky_Bet_Value]),
      Safe_Bet_Value = min(Odd),
      Safe_Bet_Result = gsub("B365", "", Bet_Value[Odd == Safe_Bet_Value])
    ) %>%
    ungroup() %>%
    mutate(Winner = ifelse(FTR == Risky_Bet_Result, 'Risky', 
                           ifelse(FTR == Safe_Bet_Result , 'Safe', 'Both Loser')),
           Won_Money = ifelse(Winner == 'Both Loser', 0,
                              ifelse(Winner == 'Safe', Safe_Bet_Value, Risky_Bet_Value))) 
  # Return the results
  tmp_season_reshaped %>%
    filter(Winner != 'Both Loser') %>%
    group_by(Winner) %>%
    summarize(Count = n(), Won_Money = sum(Won_Money) - nrow(tmp_season_reshaped)) %>%
    ungroup() %>% 
    mutate(Season = paste0(year_text, "-", next_year_text))
})
all_seasons = bind_rows(all_seasons)
all_seasons %>% melt(id.vars = c("Winner", "Season")) %>% dcast(Season ~ Winner + variable, value.var = "value")

# Plot number of won bets
G1 = ggplot(all_seasons, aes(x = Season, y = Count, col = Winner, fill = Winner, group = Winner)) + 
  geom_point() + 
  geom_smooth() + 
  geom_text(aes(label = Count), vjust = -.3) + 
  theme_minimal() + 
  xlab("") + 
  ylab("Won Bets\n") +
  scale_fill_manual(values = c("#1a476f", "#90353b")) +
  scale_color_manual(values = c("#1a476f", "#90353b")) +
  theme_minimal() + 
  theme(legend.position = "none")
# Plot number of won money
G2 = ggplot(all_seasons, aes(x = Season, y = Won_Money, col = Winner, fill = Winner, group = Winner)) + 
  geom_point() + 
  geom_smooth() + 
  geom_text(aes(label = paste0(round(Won_Money, 0), "GBP")), vjust = -.3) + 
  theme_minimal() + 
  xlab("") + 
  ylab("Won Money\n") +
  scale_fill_manual(values = c("#1a476f", "#90353b")) +
  scale_color_manual(values = c("#1a476f", "#90353b")) +
  theme_minimal() + 
  theme(legend.position = "none")

grid.arrange(G1, G2, ncol = 1)

