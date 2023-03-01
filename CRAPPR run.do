clear all


do "CRAPPR functions.do"

cap frame drop players
frame create players
cwf players

import delimited "data\player attributes.csv", varn(1) clear
levelsof name, local(all_players)
clear
foreach player in `all_players' {
	create_player `player'
}

cap frame drop games
frame create games
cwf games
import delimited "data\CRAPPR Match Results.csv", varn(1) case(l) clear

gen 	daten = date(date, "MDY")
format 	daten %td
order 	daten, after(date)
drop 	date
rename 	daten date

foreach var in winner1 winner2 loser1 loser2 {
	//drop if strpos(`var', "_OH")  // uncomment to exclude off-hand games
	replace `var' = "Neil_intern" if `var' == "Neil" & _n < 958
	drop if `var' == "Jordan"
}


gen game = _n
order game

analyze_games

join_player_attributes
rebuild_leaderboard_macros
join_ratings_to_games

cwf players

format mean sd CRAPPR %4.2f
list name CRAPPR games if current_regular

exit

do "Graph - Ratings Over Recent Games.do" 40 
do "Graph - Leaderboard.do" td(03nov2022)
do "Graph - Ranking Changes.do" 40

cap putdocx clear
putdocx begin
putdocx paragraph 
putdocx image "output/Graph - Leaderboard.png"
putdocx image "output/Graph - Ranking Changes.png"
putdocx image "output/Graph - Ratings Over Recent Games.png"
putdocx save  "output/CRAPPR - Weekly Ranking.docx", replace

exit

export_web_data

! cd "..\CRAPPR-dashboard" & git add "js/data.js" & git commit -m "update ranking data" & git push

exit

top_matchups
