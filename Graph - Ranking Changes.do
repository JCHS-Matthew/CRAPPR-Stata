* Graph - Ranking Changes.do
*
cwf games 
cap frame drop graph4
frame put *, into(graph4)
cwf graph4

drop *_mean
drop *_sd
drop winner* loser*

keep game $current_regulars

rename Ben-Niraj CRAPPR=
reshape long CRAPPR, i(game) j(name) string
drop if mi(CRAPPR)
gsort game -CRAPPR
by game: egen rank = rank(CRAPPR), field

reshape wide rank CRAPPR, i(game) j(name) string
rename rank* *

foreach player in $current_regulars {
	di "`player'"
	label var `player' "`player'"
}

label var Sherry_J "Sherry J"
label var David_S "David S"

gen foo = -1 * (_N - game)

line $current_regulars foo in -40/L, lwidth(3 ..) yscale(reverse) ylabel(1/14, angle(0)) title("CRAPPR Rankings", span) subtitle("Over 40 Most Recent Games", span) xtitle("Game") legend(col(1) pos(3) symxsize(4) rowgap(3) region(style(none) margin(0 0 0 0)) bmargin(1 0 .25 .25)) xsize(6.5) ysize(4.5) graphregion(color(white) margin(0 0 0 0)) 
//line $current_regulars foo in -40/L, scheme(CRA_embedded) lwidth(3 ..) yscale(r(.6 14.4) reverse) ylabel(1/14) title("CRAPPR Rankings") subtitle("Over 40 Most Recent Games") xtitle("Game") legend(col(1) pos(3) symxsize(4) rowgap(3) region(margin(0 0 0 0)) bmargin(1 0 .25 .25)) ysize(4.5) 


cwf graph4
cap frame drop graph4b
frame put *, into(graph4b)
cwf graph4b
gen ratingorder = ""
foreach player in $current_regulars {
	replace ratingorder = ratingorder + string(`player')
}
drop if ratingorder == ratingorder[_n-1]
drop foo
gen foo = -1 * (_N - _n)
line $current_regulars foo in -35/L, lwidth(3 ..) yscale(reverse) ylabel(1/15, angle(0)) xlabel(-30(10)0) title("CRAPPR Rankings", span) subtitle("Over 35 Most Recent Ranking Changes", span) xtitle("") legend(col(1) pos(3) symxsize(4) rowgap(3) region(style(none) margin(0 0 0 0)) bmargin(1 0 .25 .25)) xsize(6.5) ysize(4.45) graphregion(color(white) margin(0 0 0 0))
graph export "output/Graph - Ranking Changes.png", width(2400) replace