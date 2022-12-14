* CRAPPR Stata version

gl initial_mean 	25
gl sd_factor 		3
gl initial_sd 		= $initial_mean / $sd_factor
gl initial_dynamic 	= $initial_mean / $sd_factor / 200
gl initial_beta 	= $initial_mean / 6

di "initial_mean"		char(9) as result %3.1f $initial_mean 		_n ///
   "sd_factor"			char(9) as result %3.1f $sd_factor 			_n ///
   "initial_sd" 		char(9) as result %3.2f $initial_sd 		_n ///	
   "initial_dynamic" 	char(9) as result %4.3f $initial_dynamic 	_n ///
   "initial_beta" 		char(9) as result %3.2f $initial_beta 


cap program drop create_player
program def create_player
	syntax name(name=player id="player name")
	di "`player'"
	
	frame
	local currentframe = r(currentframe)
	
	cap frame create players
	cwf players
	
	if _N == 0 {
		gen name = ""
		gen double mean 	= .
		gen double sd 		= .
		gen double CRAPPR 	= .
		gen int    games    = 0
		local current_mean = $initial_mean
	}
	else {
		frame players: sum mean [fw=games]
		if r(sum) == 0 frame players: sum mean
		frame players: local current_mean = r(mean)
	}

	set obs `=_N+1'
	replace name 	= "`player'"    in L
	//replace mean 	= $initial_mean in L
	replace mean 	= `current_mean' in L
	replace sd 		= $initial_sd   in L
	replace CRAPPR 	= mean - 3 * sd in L
	
	cap frame drop `player'
	frame create `player' int game double(mean sd)
	frame post `player' (0) ($initial_mean) ($initial_sd)
	
	cwf `currentframe'
	
end


cap program drop CRAPPR_predict
program define CRAPPR_predict
	syntax namelist(name=player min=4 max=4), [noPost]
	args player1 player2 player3 player4

	quietly {
		
	frame
	local currentframe = r(currentframe)
	
	if "`player2'" < "`player1'" {
		local sort "`player1'"
		local player1 "`player2'"
		local player2 "`sort'"
	}
	
	if "`player4'" < "`player3'" {
		local sort "`player3'"
		local player3 "`player4'"
		local player4 "`sort'"
	}
	
	noi di as text "Game: " as result "`player1'/`player2' vs. `player3'/`player4'"
	cwf players
	tempfile players
	save 	`players'
	
	cap frame drop calc_predict
	frame create calc_predict
	cwf calc_predict
	
	set obs 4
	gen name = ""
	replace name = "`player1'" in 1
	replace name = "`player2'" in 2
	replace name = "`player3'" in 3
	replace name = "`player4'" in 4

	gen order = _n
	
	merge 1:1 name using `players', keep(match) assert(match using) nogen
	
	sort order
	
	
	local skill_diff = `=mean[1]' + `=mean[2]' - `=mean[3]' - `=mean[4]'
	noi di as text"Game skill estimate difference: " as result %4.2f `skill_diff'
	
	#d ;
	global prediction = normal(
		`skill_diff'
		/
		sqrt(
			4*(25/6)^2
			+`=sd[1]'^2
			+`=sd[2]'^2
			+`=sd[3]'^2
			+`=sd[4]'^2
		)
	)
	; #d cr
	
	noi di as text "Predicted outcome: " as result %4.1f 100 * $prediction "% chance of winning"
	
	if "`post'" != "nopost" {
		cap frame create predictions str100 matchup float skill_diff float prediction
		frame post predictions ("`player1'/`player2' vs. `player3'/`player4'") (`skill_diff') (100 * $prediction)
	}
	
	cwf players
	
	cap frame drop calc_predict
	}
	
	cwf `currentframe'

end


cap program drop game
program def game
	syntax namelist(name=row min=1 max=1 local)
	quietly {
	di "`row'"

	CRAPPR_predict `=winner1[`row']' `=winner2[`row']' `=loser1[`row']' `=loser2[`row']' , nopost
	cap confirm var pre_match_prediction
	if _rc == 111 gen pre_match_prediction = .
	replace pre_match_prediction = $prediction in `row'
	
	cap frame drop calc_game
	frame put * in `row', into(calc_game)
	frame calc_game {
		foreach player in winner1 winner2 loser1 loser2 {
			cap confirm frame `=`player''
			if _rc != 0 create_player `=`player''
			
			frlink m:1 `player', frame(players name) gen(`player'_link)	
			frget pre_`player'_mean = mean, from(`player'_link)
			frget pre_`player'_sd = sd, from(`player'_link)
			frget pre_`player'_games = games, from(`player'_link)
		}
		
		local pre_match_min_player_games = min(pre_winner1_games, pre_winner2_games, pre_loser1_games, pre_loser2_games)
		
		gen pre_winner_mean_sum = pre_winner1_mean + pre_winner2_mean
		gen pre_loser_mean_sum  = pre_loser1_mean + pre_loser2_mean

		gen pre_winner_sum_sq_sd = sqrt(pre_winner1_sd^2 + pre_winner2_sd^2)
		gen pre_loser_sum_sq_sd  = sqrt(pre_loser1_sd^2 + pre_loser2_sd^2)

		gen game_C = sqrt(pre_winner_sum_sq_sd + pre_loser_sum_sq_sd + 4*${initial_beta}^2)
		gen game_skill_diff = pre_winner_mean_sum - pre_loser_mean_sum
		gen game_skill_diff_C = game_skill_diff / game_C
		gen game_V_denom = normal(game_skill_diff_C)
		gen game_V = normalden(game_skill_diff_C) / game_V_denom
		gen game_W = game_V * (game_V + game_skill_diff_C)

		foreach player in winner1 winner2 loser1 loser2 {

			local direction 1
			if ustrleft("`player'", 4) == "lose" local direction -1
			
			gen `player'_mean_multiplier = (pre_`player'_sd^2 + ${initial_dynamic}^2) / game_C
			gen `player'_sd_multiplier = (pre_`player'_sd^2 + ${initial_dynamic}^2) / game_C^2
			gen `player'_mean_delta = `direction' * `player'_mean_multiplier * game_V

			gen post_`player'_mean = pre_`player'_mean + `player'_mean_delta
			gen post_`player'_sd = sqrt(pre_`player'_sd^2 + ${initial_dynamic}^2)*(1 - game_W * `player'_sd_multiplier)
			
			frame post `=`player'' (game) (post_`player'_mean) (post_`player'_sd)
			
		}
	}
	cap frame drop calc_game
	
	rebuild_players
	
	cap confirm var pre_match_min_player_games
	if _rc == 111 gen pre_match_min_player_games = .
	replace pre_match_min_player_games = `pre_match_min_player_games' in `row'
	
	keep game date winner1 winner2 loser1 loser2 pre_match_prediction pre_match_min_player_games
	
	}
	
end


cap program drop rebuild_players
program def rebuild_players
	frame
	local currentframe = r(currentframe)
	
	cwf players
	
	forval i = 1/`=_N' {
		di name[`i']
		frame `=name[`i']': local new_mean = mean[_N]
		frame `=name[`i']': local new_sd = sd[_N]
		frame `=name[`i']': local games = _N - 1
		replace mean = `new_mean' in `i'
		replace sd = `new_sd' in `i'
		replace games = `games' in `i'
	}
	
	replace CRAPPR = mean - 3 * sd
	
	cwf `currentframe'
end


cap program drop add_game
program def add_game
	args w1 w2 l1 l2
	
	assert "`l2'" != ""
	noi di "Winners: `w1' `w2'"
	noi di "Losers:  `l1' `l2'"
	
	cwf games
	
	set obs `=_N+1'
	
	replace game = game[_N-1] + 1 in L
	replace winner1 = "`w1'" in L
	replace winner2 = "`w2'" in L
	replace loser1  = "`l1'" in L
	replace loser2  = "`l2'" in L
	
	game `=_N'
	
	cwf players
	gsort -CRAPPR
end


cap program drop join_ratings_to_games
program define join_ratings_to_games

	frame games: drop if game == 0

	foreach name in $current_players {
		cwf `name'
		tempfile player
		save `player'
		cwf games
		merge 1:1 game using `player', nogen keep(match master)
		
		replace mean = mean[_n-1] if mi(mean)
		replace sd   = sd[_n-1]   if mi(sd)

		gen `name' = mean - 3 * sd

		rename mean `name'_mean
		rename sd `name'_sd
	}

	foreach player in $current_regulars {
		di "`player'"
		label var `player' "`player'"
	}

	label var Sherry_J "Sherry J"
	label var David_S "David S"
end


cap program drop join_player_attributes
program define join_player_attributes
	cwf players
	preserve
		import delimited "data\player attributes.csv", varn(1) clear
		tempfile player_attributes
		save 	`player_attributes'
	restore
	merge 1:1 name using `player_attributes', assert(match) nogen
end

cap program drop rebuild_leaderboard_macros
program define rebuild_leaderboard_macros
	cwf players

	gsort -CRAPPR

	global all_players      `""'
	global current_players  `""'
	global current_regulars `""'
	
	forval obs = 1/`=_N' {
		di name[`obs']
		
		global all_players      `"${all_players} `=name[`obs']'"' 
		if `=current_player[`obs']' == 1 global current_players  `"${current_players} `=name[`obs']'"' 
		if `=current_regular[`obs']' == 1 global current_regulars `"${current_regulars} `=name[`obs']'"'
		
	}
end


cap program drop matchup
program define matchup
	syntax namelist(name=players min=4), [OFFhand KEEPresults noDISPlay]
	
	local i = 1
	foreach player of local players {
		local p`i' "`player'"
		local ++i
	}
	
	cwf players
	
	if "`keepresults'" == "" cap frame drop predictions
	
	_matchup_permutations `p1' `p2' `p3' `p4'
	
	if "`offhand'" == "offhand" {
		frame players: count if name == "`p1'_OH"
		if r(N) == 1 _matchup_permutations `p1'_OH `p2' `p3' `p4'
		
		frame players: count if name == "`p2'_OH"
		if r(N) == 1 _matchup_permutations `p1' `p2'_OH `p3' `p4'
		
		frame players: count if name == "`p3'_OH"
		if r(N) == 1 _matchup_permutations `p1' `p2' `p3'_OH `p4'
		
		frame players: count if name == "`p4'_OH"
		if r(N) == 1 _matchup_permutations `p1' `p2' `p3' `p4'_OH
	}
	
	if "`display'" != "nodisplay" _display_predictions
	
end


cap program drop _matchup_permutations
program define _matchup_permutations
	args p1 p2 p3 p4
		
	CRAPPR_predict `p1' `p2' `p3' `p4'
	CRAPPR_predict `p1' `p3' `p2' `p4'
	CRAPPR_predict `p1' `p4' `p2' `p3'
	
end

cap program drop _display_predictions
program define _display_predictions
	frame predictions {
		duplicates drop
		gen quality = -2 * abs(50 - prediction)
		gsort -quality
		format prediction quality %4.2f
		list matchup prediction quality, ab(10)
		drop quality
	}
end


cap program drop matchup_group
program define matchup_group
	syntax namelist(name=players min=4), [OFFhand KEEPresults noDISPlay]
	
	di `: word count `players''
	local i = 1
	foreach player of local players {
		local p`i' "`player'"
		local ++i
	}
	
	matchup `p1' `p2' `p3' `p4', `offhand' `keepresults' nodisplay

	if `: word count `players'' >= 5 {
		matchup `p5' `p2' `p3' `p4', `offhand' keep nodisplay
		matchup `p1' `p5' `p3' `p4', `offhand' keep nodisplay
		matchup `p1' `p2' `p5' `p4', `offhand' keep nodisplay
		matchup `p1' `p2' `p3' `p5', `offhand' keep nodisplay
	}
	
	if `: word count `players'' >= 6 {
		matchup_group `p1' `p2' `p3' `p4' `p6', `offhand' keep nodisplay
		matchup_group `p5' `p2' `p3' `p4' `p6', `offhand' keep nodisplay
		matchup_group `p1' `p5' `p3' `p4' `p6', `offhand' keep nodisplay
		matchup_group `p1' `p2' `p5' `p4' `p6', `offhand' keep nodisplay
		matchup_group `p1' `p2' `p3' `p5' `p6', `offhand' keep nodisplay
	}
	
	if "`display'" != "nodisplay" _display_predictions
	
end


cap program drop compile_predictions
program define compile_predictions
	cwf players
	cap frame drop pairwise
	frame put name if current_regular & games >= 10, into(pairwise)
	cwf pairwise
	drop if name == "Laury"
	rename name name1
	gen i = 1
	tempfile names
	save `names', replace
	rename name1 name2
	joinby i using `names'
	save `names', replace
	rename name1 name3
	rename name2 name4
	joinby i using `names'
	drop i
	drop if name1 == name2
	drop if name3 == name4
	drop if inlist(name1, name3, name4)
	drop if inlist(name2, name3, name4)
	drop if name1 > name2
	drop if name3 > name4
	drop if name1 > name3
	order name1 name2 name3 name4

	cwf pairwise
	cap frame drop predictions

	forval i = 1/`=_N' {
		if mod(`i', 100) == 0 {
			noi di %6.0fc `i' _n _c
		}
		else if mod(`i', 10) == 0 {
			noi di "." _c
		}
		quietly CRAPPR_predict `=name1[`i']' `=name2[`i']' `=name3[`i']' `=name4[`i']'
	}

	cwf predictions
	duplicates drop
	gen quality = 100 - 2 * abs(50 - prediction)
	gsort -quality
	format prediction quality %4.2f

end


cap program drop top_matchups
program define top_matchups
	
	confirm frame predictions
	if _rc != 0 compile_predictions
	
	cwf predictions
	
	cap drop top_matchup
	gen top_matchup = .
	foreach player in $current_regulars {
		local i = 1
		di "`player'"
		forval j = 1/`=_N' {
			if  regexm(`"`=matchup[`j']'"', "`player'") {
				if `i' < `=top_matchup[`j']' {
					replace top_matchup = `i' in `j'
				}
				local ++i
			}
		}
	}

	cap drop team1 team2
	gen team1 = regexs(1) if regexm(matchup, "(.+) vs")
	gen team2 = regexs(1) if regexm(matchup, "vs. (.+)")

	replace team1 = regexs(1) + " / " + regexs(2) if regexm(team1, "(.*)/(.*)")
	replace team2 = regexs(1) + " / " + regexs(2) if regexm(team2, "(.*)/(.*)")

	order prediction quality, last

	br team1 team2 prediction quality if top_matchup <= 5 & quality > 98
end


cap program drop export_web_data
program define export_web_data

	frame
	local currentframe = r(currentframe)
	
	cap noisily confirm frame leaderboard
	if _rc == 111 {
		noi di as error `"run "Graph - Leaderboard.do" before attempting to export web data"'
		exit
	}
	
	cwf leaderboard
	cap frame drop web_data
	frame put *, into(web_data)
	cwf web_data
	
	gen web_data = name + ": { mean: " + string(mean) + ", sd: " + string(sd) + ", change: " + string(change) + "},"
	keep web_data
	
	set obs `=_N+2'
	sort web_data
	replace web_data = `"let leaderboard_date = "12/1/2022""' in 1
	replace web_data = "let players = {" in 2
	
	set obs `=_N+1'
	replace web_data = "}" in L
	
	outfile using "../CRAPPR-dashboard/js/data.js", noquote replace

	cwf `currentframe'
	
end
