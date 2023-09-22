
cwf games
cap frame drop diagnostic
frame put *, into(diagnostic)
cwf diagnostic

gen pre_odds = pre_match_prediction
gen 	win = 0
replace win = 1 if pre_odds >= .5
replace pre_odds = 1 - pre_odds if pre_odds < .5

gen bin_05 = mod(pre_odds, 0.05)
replace bin_05 = pre_odds - bin_05
replace bin_05 = bin_05 + 0.025

keep if date >= td(06sep2022)
keep if pre_match_min_player_games >= 10

collapse (mean) win (sum) wins=win (count) N=win (sem) sem=win (mean) mean_pre_odds=pre_odds, by(bin)


#d ;
twoway
	(scatter win mean_pre_odds [fw=N]) 
	(scatteri .5 .5 1 1, connect(line) msize(vsmall))
	, 
	title("CRAPPR Prediction Accuracy Diagnostics", span)
	
	xtitle("Predicted Win Share" "(Binned to 0.05)")
	xtick(.5(.05)1) 
	xlabel(.5(.1)1)
	
	ytitle("Actual Win Share")
	ytick(.4(.1)1)
	ylabel(.4(.1)1)
	ylabel(.4(.1)1, angle(0))
	
	note(
		"Notes: "
		"[1] Includes games since Sept. 6, 2022."
		"[2] Includes games where every player had played at least 10 previous games."
		"[3] Marker size weighted by number of games."
		, span size(vsmall)
	)
	legend(off) 
; #d cr;


gen UB_sem = win + sem * 1.96
gen LB_sem = win - sem * 1.96

gen binomial_prob = binomialtail(N, wins, bin_05)
gen binomial_C = 0
sum N if N == wins
forval C = 1/`r(max)' {
	noi di "`C'"
	replace binomial_C = `C' if binomial_prob < 0.95
	replace binomial_prob = binomialtail(N, wins - `C', bin_05) if binomial_prob < 0.95
}
gen binomial_LB = (N - binomial_C) / N

gen 	UB = min(UB_sem, 1)
gen 	LB = LB_sem
replace LB = binomial_LB if wins == N


#d ;
twoway
	(scatter win mean_pre_odds)
	(rcap UB LB mean_pre_odds)
	(scatteri .5 .5 1 1, connect(line) msize(vsmall))
	,
	title("CRAPPR Prediction Accuracy Diagnostics", span)
	
	xtitle("Predicted Win Share" "(Binned to 0.05)")
	xtick(.5(.05)1) 
	xlabel(.5(.1)1)
	
	ytitle("Actual Win Share")
	ytick(.4(.1)1)
	ylabel(.4(.1)1)
	ylabel(.4(.1)1, angle(0))
	
	note(
		"Notes: "
		"[1] Includes games since Sept. 6, 2022."
		"[2] Includes games where every player had played at least 10 previous games."
		"[3] Chart shows 95% confidence intervals. For bins with zero variance, CIs reflects the highest discrete win total at which the binomial probability is >= 0.95."
		, span size(vsmall)
	)
	legend(off) 
; #d cr;
