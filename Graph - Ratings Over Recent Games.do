// Graph - Ratings Over Time.do

syntax [anything(name=games_shown)]

if "`games_shown'" == "" local games_shown 40

cwf games

#d ;
line 
	$current_regulars game in -`games_shown'/L
	, 
	$CRAPPR_chart_options
	
	lwidth(*1.7 ..)
	
	title("CRAPPR Rating Trends", span) 
	subtitle("`games_shown' Most Recent Games", span) 
	 
	yscale(r(0)) 
	ylabel(0(5)25, angle(0)) 
	
	xtitle("") 
	xlabel(none) 
	
	legend(col(1) pos(2) bmargin(r=0 /* t=-2.5 */) symxsize(8) /* rowgap(2.9) */) 
	
	graphregion(color(white) margin(1 1 1 1)) 
	plotregion(margin(0 0 0 0))
	
	xsize(6.5) 
	ysize(9) 
;
#d cr;

graph export "output/Graph - Ratings Over Recent Games.png", width(2400) replace
