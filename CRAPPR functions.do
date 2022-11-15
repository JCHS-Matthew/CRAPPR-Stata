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
	args player1 player2 player3 player4
	
	quietly {
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
	local prediction = normal(
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
	
	noi di as text "Predicted outcome: " as result %4.1f 100 * `prediction' "% chance of winning"
	
	
	cap frame create predictions str100 matchup float skill_diff float prediction
	
	frame post predictions ("`player1'/`player2' vs. `player3'/`player4'") (`skill_diff') (100 * `prediction')
	
	cwf players
	
	cap frame drop calc_predict
	}

end


cap program drop game
program def game
	syntax namelist(name=row min=1 max=1 local)
	quietly {
	di "`row'"

	cap frame drop calc_game
	frame put * in `row', into(calc_game)
	frame calc_game {
		foreach player in winner1 winner2 loser1 loser2 {
			cap confirm frame `=`player''
			if _rc != 0 create_player `=`player''
			
			frlink m:1 `player', frame(players name) gen(`player'_link)	
			frget pre_`player'_mean = mean, from(`player'_link)
			frget pre_`player'_sd = sd, from(`player'_link)
		}
		
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
	keep game date winner1 winner2 loser1 loser2
	
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
