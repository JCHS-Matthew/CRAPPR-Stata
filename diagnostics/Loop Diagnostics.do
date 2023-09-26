
do "../CRAPPR functions.do"

cap program drop loop_diagnostic
program define   loop_diagnostic

	args dynamic beta
	noi di "`dynamic'"
	noi di "`beta'"
	
	foreach startdate in "06sep2022" "25jul2019" {
		
		noi di "`startdate'"

		gl initial_mean 	25
		gl sd_factor 		3
		gl initial_sd 		= $initial_mean / $sd_factor
		gl initial_dynamic 	= $initial_mean / $sd_factor / `dynamic'
		gl initial_beta 	= $initial_mean / `beta'

		cwf default 
		
		* create player frames
		cap frame drop players
		frame create players
		cwf players

		import delimited "../../CRAPPR-match-results/player attributes.csv", varn(1) clear
		levelsof name, local(all_players)
		clear
		foreach player in `all_players' {
			create_player `player'
		}

		* import and prep game results data
		cap frame drop games
		frame create games
		cwf games
		import delimited "../../CRAPPR-match-results/CRAPPR Match Results.csv", varn(1) case(l) clear

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

		keep if date >= td(`startdate')

		* run CRAPPR
		gen game = _n
		
		order game

		analyze_games

		forval min_games =10(90)100 { 
			do "Diagnostic - Prediction Accuracy.do" `startdate' `min_games' `dynamic' `beta'
		}
	}
end

cap frame create diagnostic_results

loop_diagnostic 50  6
loop_diagnostic 100 6
loop_diagnostic 200 6
loop_diagnostic 50  3
loop_diagnostic 100 3
loop_diagnostic 200 3
loop_diagnostic 50  4
loop_diagnostic 100 4
loop_diagnostic 200 4
