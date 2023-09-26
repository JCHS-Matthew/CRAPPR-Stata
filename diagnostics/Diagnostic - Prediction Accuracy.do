

syntax [anything(name=model)]

if "`model'" == "" local model "06sep2022 10"

local cutoffdate `: word 1 of `model''
local min_games  `: word 2 of `model''

noi di "`cutoffdate'"
noi di "`min_games'"

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

keep if date >= td(`cutoffdate')
keep if pre_match_min_player_games >= `min_games'

gen resid = 1 - pre_match_prediction
gen resid_sq = resid^2

sum win
local correct_prediction_pct = r(sum) / _N

sum resid_sq
local SSR = r(sum)

collapse (mean) win (sum) wins=win (count) N=win (sem) sem=win (mean) mean_pre_odds=pre_odds resid_sq, by(bin)

gen  est_diff = win - mean_pre_odds
reg  est_diff bin_05 [fw=N]

local reg_coef = _b[bin_05]
local reg_cons = _b[_cons]
local reg_R2   = e(r2_a)

preserve
	gen model = "`model'"
	tostring bin_05, replace force format("%4.3f")
	replace bin_05 = substr(bin_05, -3, 3)
	reshape wide win wins N sem mean_pre_odds resid_sq est_diff, i(model) j(bin_05) string

	foreach var in reg_R2 reg_cons reg_coef SSR correct_prediction_pct {
		gen `var' = ``var''
		order `var', after(model)
	}
	
	tempfile res
	save 	`res'
	cap frame diagnostic_results: append using `res'
restore

drop if N == 1

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
	ylabel(.4(.1)1, angle(0))
	
	text(.42 1 "`: word 3 of `model'' `: word 4 of `model''", place(left) size(small))

	note(
		"Notes: "
		"[1] Includes games since `cutoffdate'."
		"[2] Includes games where every player had played at least `min_games' previous games."
		"[3] Marker size weighted by number of games."
		, span size(vsmall)
	)
	legend(off) 
; #d cr;
graph export "Output/Diagnostic - bin weighted scatter - `model'.png", width(2000) replace


gen UB_sem = win + sem * 1.96
gen LB_sem = win - sem * 1.96

gen binomial_prob = binomialtail(N, wins, bin_05)
gen binomial_C = 0
sum N if N == wins
if r(N) > 0 {
	forval C = 1/`r(max)' {
		noi di "`C'"
		replace binomial_C = `C' if binomial_prob < 0.95
		replace binomial_prob = binomialtail(N, wins - `C', bin_05) if binomial_prob < 0.95
	}
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
	ylabel(.4(.1)1, angle(0))
	
	text(.42 1 "`: word 3 of `model'' `: word 4 of `model''", place(left) size(small))
	
	note(
		"Notes: "
		"[1] Includes games since `cutoffdate'."
		"[2] Includes games where every player had played at least `min_games' previous games."
		"[3] Chart shows 95% confidence intervals. For bins with zero variance, CIs reflects the highest discrete win total at which the binomial probability is >= 0.95."
		, span size(vsmall)
	)
	legend(off) 
; #d cr;
graph export "Output/Diagnostic - bin error bars - `model'.png", width(2000) replace
