// Graph - Leaderboard.do

syntax anything(name=previous_leaderboard_date)

cwf players
cap frame drop leaderboard
frame put *, into(leaderboard)
cwf leaderboard

gen hi = mean + 3*sd

gen preliminary = games < 2
//gsort preliminary -CRAPPR

drop if regexm(name, "_OH")
gsort -CRAPPR

gen active_player = strpos("$current_players", name) > 0
replace active_player = 0 if inlist(name, "David", "Sherry")

drop if !active_player

gen n = _n
forval i = 1/`=_N' {
	label define name_lables `i' `"`=subinstr("`=name[`i']'", "_", " ", .)'"', modify
}

sum n if name == "Zeeshan"
label define name_lables `r(mean)' "☠Zeeshan", modify

label values n name_lables

format CRAPPR %2.0f

drop if games <= 1

forval i = 1/`=_N' {
	noi di "`=name[`i']'"
	frame `=name[`i']' {
		list in `=max(-5, `=(_N * -1) + 1')'
	}
}

gen zero = 0
gen change = 0

cwf games
preserve
	di `previous_leaderboard_date'
	keep if date <= `previous_leaderboard_date'
	keep in L
	tempfile previous_leaderboard
	save `previous_leaderboard'
restore
preserve
	keep in L
	append using `previous_leaderboard'
	keep game $current_regulars
	rename * CRAPPR=
	rename CRAPPRgame game
	reshape long CRAPPR, i(game) j(name) string
	drop if mi(CRAPPR)
	gsort game -CRAPPR
	by game: egen rank = rank(CRAPPR), field
	reshape wide rank CRAPPR, i(game) j(name) string
	assert _N == 2
	set obs 3

	foreach player in $current_regulars {
		di "`player'"
		replace rank`player' = rank`player'[1] - rank`player'[2] in L
	}

	keep rank*
	rename rank* *change
	keep in L
	gen i = 1
	reshape long @change, i(i) j(name) string
	drop i
	list
	tempfile change
	save `change'
restore

cwf leaderboard

merge 1:1 name using `change', /* assert(match master) */ nogen update replace


capture {
	gen symbol = "▲ " + string(change) if change > 0
	replace symbol = "▼ " + string(abs(change)) if change < 0
	replace symbol = "−" if change == 0
}

frame games {
	sum date
	local current_leaderboard_date = r(max)
}

#d;
	twoway 
		(rcap CRAPPR hi n, horizontal color(gs7))
		(scatter n CRAPPR, msymbol(i) mlab(CRAPPR) mlabp(9) mlabt(size(vsmall)) mlabc(gs5) mlabf(%3.1f))

		(rcap CRAPPR hi n if active_player, horizontal color(red))
		(scatter n CRAPPR if active_player, msymbol(i) mlab(CRAPPR) mlabp(9) mlabt(size(vsmall)) mlabc(red) mlabf(%3.1f))
		
		(scatter n zero if change > 0 , mlabel(symbol) msize(vtiny) mlabcolor(green))
		(scatter n zero if change < 0 , mlabel(symbol) msize(vtiny) mlabcolor(red))
		(scatter n zero if change == 0, mlabel(symbol) msize(vtiny) mlabcolor(black))
		, 
		

		title("CRA Ping-Pong Rating", c(black) span) 
		subtitle("{it:Official CRAPPR score is lower bound of estimate range}", size(14pt) span) 		
		
		xtitle("CRAPPR Score") 
		xlabel(, grid) 
		xscale(r(0))
		xlabel(0(10)40)
		
		ytitle("") 
		ylabel(1/`=_N', val angle(0) grid) 
		yscale(reverse) 
		
		legend(off) 
		
		note(
/*
			"Notes: "
			"[1] Red ratings indicate current players. "
			"[2] Includes games played through Oct. 5, 2022."
*/
			"Note: Includes games played through `=string(`current_leaderboard_date', "%tdMon._dd,_CCYY")'."
			, span
		)
		
		plotregion(margin(l=0)) 
		graphregion(color(white) margin(0 0 0 0)) 
		xsize(6.5) 
		ysize(9)
;#d cr
graph export "output/Graph - Leaderboard.png", width(2400) replace
