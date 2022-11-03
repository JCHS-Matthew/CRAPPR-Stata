
*
cap frame create graph2
cwf graph2
clear
set obs 1
gen n = 1
foreach name in $all_players {
	cwf `name'
	cap gen n = _n
	tempfile player
	save `player'
	drop n
	cwf graph2
	merge 1:1 n using `player', nogen

	gen `name' = mean - 3 * sd

	rename mean `name'_mean
	rename sd `name'_sd
	
}

drop if game == 0
line 	$all_players game in 1/25, title(CRAPPR Rating, span) subtitle(" ") legend(col(1) pos(3)) yscale(r(0)) ylabel(0(5)30, angle(0)) xtitle("Game") xlabel(0(5)30, grid) graphregion(color(white)) 
line 	$current_regulars game in 1/25, title(CRAPPR Rating, span) subtitle(" ") legend(col(1) pos(3)) yscale(r(0)) ylabel(0(5)30, angle(0)) xtitle("Game") xlabel(0(5)30, grid) graphregion(color(white)) 



cap frame create graph3
cwf graph3
clear
set obs 1
gen n = 0
foreach name in $all_players {
	cwf `name'
	cap gen n = _N - _n
	replace n = . if game == 0
	tempfile player
	save `player'
	drop n
	cwf graph3
	merge 1:1 n using `player', nogen

	gen `name' = mean - 3 * sd

	rename mean `name'_mean
	rename sd `name'_sd
	
}

replace n = -1 * n
line 	$current_regulars  n in 1/20, title(CRAPPR Rating, span) subtitle("Over Each Player’s 20 Most Recent Games", span) legend(col(1) pos(3)) yscale(r(0)) ylabel(0(5)30, angle(0)) xtitle("Game") xlabel(-20(5)0, grid) graphregion(color(white)) 





/*
cwf David_S
gen byte win = mean > mean[_n-1]
replace win = -1 if win == 0
gen n = _n

twoway (spike win n in -10/L if game > 0, lwidth(.15in)) (spike win n in -10/L if game > 0 & win == -1, lwidth(.15in)), xsize(2.2) ysize(1) legend(off) ytitle("") ylabel(none) yscale(lstyle(none)) xtitle("") xlabel(none) xscale(lstyle(none)) graphregion(color(white) margin(0 .05in 0 0)) title("David S", position(9) width(.7in)  margin(0 0 0 0) bmargin(0 0 0 0) size(12pt) color(black))
twoway (spike win n in -10/L if game > 0, lwidth(.15in)) (spike win n in -10/L if game > 0 & win == -1, lwidth(.15in)), xsize(2.2) ysize(1) legend(off) ytitle("") ylabel(none) yscale(lstyle(none)) xtitle("") xlabel(none) xscale(lstyle(none)) graphregion(color(white) margin(0 .05in 0 0)) title("David S", position(9) width(.7in)  margin(0 0 0 0) bmargin(0 0 0 0) size(12pt) color(black))

exit
*/


