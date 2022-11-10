clear all


do "CRAPPR functions.do"

global all_players `" Ben Mark Gustavo Matt Andrew Lena Peter Jeffrey Sherry Steve Ricardo Neil Neil_intern Laury Jessica Isabel Mensur David Chloe Niraj James Arun Rowan David_S Andres Victor Zeeshan Jack Sherry_J Yumeng Karen Ben_OH Matt_OH Rowan_OH Andres_OH"'
global current_players  `"Ben Andres Matt Rowan Ricardo Sherry_J Neil Jeffrey David_S Arun Jack Zeeshan Victor Yumeng Laury Karen Niraj"'
global current_regulars `"Ben Andres Matt Rowan Ricardo Sherry_J Neil         David_S Arun Jack Zeeshan Victor Yumeng Laury Karen Niraj"'

cap frame drop players
frame create players
cwf players
foreach player in $all_players {
	create_player `player'
}

cap frame drop games
frame create games
cwf games
//import excel "CRAPPR_calc\CRAPPR Match Results.xlsm", sheet(Results) first case(l) clear
import delimited "data\CRAPPR Match Results.csv", varn(1) case(l) clear

gen 	daten = date(date, "MDY")
format 	daten %td
order 	daten, after(date)
drop 	date
rename 	daten date

foreach var in winner1 winner2 loser1 loser2 {
	replace `var' = subinstr(`var', " ", "", .)
	replace `var' = "Jeffrey" if `var' == "Jeff"
	replace `var' = "Neil_intern" if `var' == "Neil" & _n < 958
}

drop if mi(winner1, winner2, loser1, loser2)

drop in 958


/*
foreach var in winner1 winner2 loser1 loser2 {
	drop if strpos(`var', "_OH")
}
*/


gen game = _n
order game

forval game = 1/`=_N' {
	if mod(`game', 100) == 0 {
		noi di %5.0fc `game' _n _c
	}
	else if mod(`game', 10) == 0 {
		noi di "." _c
	}

	game `game'
	
	if `game' == `=_N' noi di "done"
}

cwf players
gsort -CRAPPR
format mean sd CRAPPR %4.2f
list name CRAPPR games if regexm(name, usubinstr("$current_players", " ", "|", .)) // strpos("$current_players", name)

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
