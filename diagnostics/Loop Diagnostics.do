
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

//loop_diagnostic 200 6

foreach dyn of numlist 5 10(10)100 150 200 300 {
	foreach b of numlist 2/8 {
		loop_diagnostic `dyn' `b'
	}
}


exit

cwf diagnostic_results

duplicates drop

local model_regex "^(\d{2}[a-z]{3}\d{4} \d{2,3}) (\d{1,3}) (\d)$"

gen model_group = ustrregexs(1) if ustrregexm(model, "`model_regex'")
gen dynamic     = ustrregexs(2) if ustrregexm(model, "`model_regex'")
gen beta        = ustrregexs(3) if ustrregexm(model, "`model_regex'")

destring dynamic, replace
destring beta, replace
	
order model model_group dynamic beta

cap frame drop analysis
frame put *, into(analysis)
cwf analysis

keep model_group dynamic beta correct_prediction_pct SSR reg_coef reg_cons reg_R2

reshape wide correct_prediction_pct SSR reg_coef reg_cons reg_R2, i(model_group dynamic) j(beta)
order model_group dynamic correct_prediction_pct* SSR* reg_coef* reg_cons* reg_R2*
